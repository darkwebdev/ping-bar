import Foundation

protocol PingManagerDelegate: AnyObject {
    func pingManager(_ manager: PingManager, didReceivePingResult result: Int)
    func pingManager(_ manager: PingManager, didFailWithError error: String)
}

class PingManager: NSObject {
    weak var delegate: PingManagerDelegate?

    // Timer & pinger
    private var timer: DispatchSourceTimer?
    private var currentPinger: PingProviding?

    // Factory for creating pingers (injectable for tests)
    var pingerFactory: ((String) throws -> PingProviding)?

    // Public settings
    var pingHost: String = "127.0.0.1"
    var pingInterval: Double = 2.0 {
        didSet {
            stateQueue.sync { baseInterval = pingInterval }
            if timer != nil { scheduleTimer() }
        }
    }

    // Backoff state
    private let stateQueue = DispatchQueue(label: "PingManager.stateQueue")
    private var failureCount: Int = 0
    private var baseInterval: Double = 2.0
    private var maxBackoffInterval: Double = 30.0
    private var pauseUntil: Date?
    private var pauseNotificationSent = false
    private let cooldownFailureThreshold = 5
    private let cooldownDuration: TimeInterval = 120

    private var isTimerRunning: Bool { return timer != nil }

    private static let logTimestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private func log(_ message: String) {
        let timestamp = PingManager.logTimestampFormatter.string(from: Date())
        print("[\(timestamp)] [PingManager] \(message)")
    }

    override init() {
        super.init()
        // default factory creates a SwiftyPing
        pingerFactory = { host in
            return try SwiftyPing(host: host, configuration: PingConfiguration(interval: 0.5, with: 2.0), queue: DispatchQueue.global())
        }
        baseInterval = pingInterval
    }

    // MARK: - Timer control
    func startPinging() {
        stopPinging()
        performPingCycle() // Fire immediately once, then rely on the timer cadence
        scheduleTimer()
    }

    // Compatibility method used elsewhere in the app
    func updateInterval(_ newInterval: Double) {
        let interval = max(0.5, newInterval)
        pingInterval = interval
        if timer != nil { scheduleTimer() }
    }

    private func scheduleTimer(initialDelay: Double? = nil) {
        if let t = timer { t.cancel(); timer = nil }
        let (interval, delay) = stateQueue.sync { () -> (Double, Double) in
            let base = calculateCurrentInterval()
            if let pauseUntil = pauseUntil {
                let secondsLeft = max(0, pauseUntil.timeIntervalSinceNow)
                return (base, max(base, secondsLeft))
            }
            return (base, initialDelay ?? base)
        }
        let queue = DispatchQueue(label: "PingManager.timer", qos: .utility)
        let dispatchTimer = DispatchSource.makeTimerSource(queue: queue)
        dispatchTimer.schedule(deadline: .now() + delay, repeating: interval)
        dispatchTimer.setEventHandler { [weak self] in self?.performPingCycle() }
        dispatchTimer.resume()
        timer = dispatchTimer
        log("scheduleTimer interval=\(interval)s delay=\(delay)s pauseUntil=\(String(describing: pauseUntil))")
    }

    func stopPinging() {
        if let t = timer { t.cancel(); timer = nil }
        if let pinger = currentPinger {
            DispatchQueue.global(qos: .utility).async { pinger.haltPinging(resetSequence: true) }
            currentPinger = nil
        }
        stateQueue.async { [weak self] in self?.failureCount = 0 }
    }

    // MARK: - Ping cycle
    private func performPingCycle() {
        let now = Date()
        if let pauseUntil = pauseUntil, pauseUntil > now {
            if !pauseNotificationSent {
                let secondsLeft = Int(pauseUntil.timeIntervalSince(now))
                log("Pausing pings for \(secondsLeft)s after repeated failures for host=\(pingHost)")
                pauseNotificationSent = true
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.delegate?.pingManager(self, didFailWithError: "Temporarily paused after repeated failures for \(self.pingHost). Will retry soon.")
                }
            }
            return
        }
        if pauseNotificationSent { pauseNotificationSent = false }
        pauseUntil = nil

        let host = pingHost
        guard !host.isEmpty else { return }

        log("performPingCycle for \(host) (failureCount=\(failureCount))")

        var pinger: PingProviding?
        do {
            // Reuse an existing pinger if available. This allows fake providers
            // used in tests to maintain internal state across multiple startPinging calls.
            if let existing = currentPinger {
                pinger = existing
            } else {
                if let factory = pingerFactory { pinger = try factory(host) }
                else { pinger = try SwiftyPing(host: host, configuration: PingConfiguration(interval: 0.5, with: 2.0), queue: DispatchQueue.global()) }
            }
        } catch {
            let friendly = userFriendlyErrorMessage(from: error)
            DispatchQueue.main.async { [weak self] in guard let self = self else { return }; self.delegate?.pingManager(self, didFailWithError: friendly) }
            recordFailure()
            log("failed to create pinger for \(host): \(error.localizedDescription)")
            return
        }

        currentPinger = pinger
        var responseReceived = false
        var errorReported = false

        pinger?.observer = { [weak self] response in
            guard let self = self else { return }
            responseReceived = true
            let roundedDuration = ceil(response.duration * 1000)
            let pingResult = Int(roundedDuration)
            self.recordSuccess()
            DispatchQueue.main.async { self.delegate?.pingManager(self, didReceivePingResult: pingResult) }
            self.log("received response from \(host): \(pingResult)ms")
        }

        pinger?.targetCount = 1

        do {
            try pinger?.startPinging()
            log("started pinger for \(host)")
        } catch {
            errorReported = true
            let friendly = userFriendlyErrorMessage(from: error)
            DispatchQueue.main.async { [weak self] in guard let self = self else { return }; self.delegate?.pingManager(self, didFailWithError: friendly) }
            recordFailure()
            log("startPinging() threw for \(host): \(error.localizedDescription)")
            return
        }

        // Timeout handling
        let timeoutSeconds: Double = 2.0
        DispatchQueue.global().asyncAfter(deadline: .now() + timeoutSeconds) { [weak self] in
            guard let self = self else { return }
            if !responseReceived && !errorReported {
                DispatchQueue.main.async { self.delegate?.pingManager(self, didFailWithError: "Timeout - no response from \(host)") }
                self.recordFailure()
                self.log("timeout waiting for response from \(host)")
            }
        }
    }

    // MARK: - Backoff helpers
    private func calculateCurrentInterval() -> Double {
        let failures = failureCount
        if failures <= 0 { return baseInterval }
        let exp = pow(2.0, Double(min(failures, 10)))
        let interval = min(maxBackoffInterval, baseInterval * exp)
        return interval
    }

    private func recordFailure() {
        stateQueue.async { [weak self] in
            guard let self = self else { return }
            self.failureCount += 1
            if self.failureCount >= self.cooldownFailureThreshold {
                // Activate pause/cooldown
                self.pauseUntil = Date().addingTimeInterval(self.cooldownDuration)
                if self.isTimerRunning { DispatchQueue.main.async { self.scheduleTimer() } }
            } else {
                if self.isTimerRunning { DispatchQueue.main.async { self.scheduleTimer() } }
            }
        }
    }

    private func recordSuccess() {
        stateQueue.async { [weak self] in
            guard let self = self else { return }
            self.failureCount = 0
            if self.isTimerRunning { DispatchQueue.main.async { self.scheduleTimer() } }
        }
    }

    // Function to convert cryptic error messages to user-friendly ones
    private func userFriendlyErrorMessage(from error: Error) -> String {
        let errorString = error.localizedDescription.lowercased()
        if errorString.contains("error 8") || errorString.contains("nodename nor servname provided") { return "Host '\(pingHost)' could not be resolved (invalid hostname)" }
        if errorString.contains("error 9") || errorString.contains("address family not supported") { return "Host '\(pingHost)' could not be resolved (DNS lookup failed)" }
        if errorString.contains("error -1003") || errorString.contains("server with the specified hostname could not be found") { return "Host '\(pingHost)' could not be found (DNS resolution failed)" }
        if errorString.contains("error -1001") || errorString.contains("request timed out") { return "Connection to '\(pingHost)' timed out" }
        if errorString.contains("error -1004") || errorString.contains("could not connect to the server") { return "Could not connect to host '\(pingHost)'" }
        if errorString.contains("network is unreachable") { return "Network is unreachable for host '\(pingHost)'" }
        if errorString.contains("host is down") { return "Host '\(pingHost)' is down or unreachable" }
        if errorString.contains("no route to host") { return "No route to host '\(pingHost)'" }
        if errorString.contains("connection refused") { return "Connection refused by host '\(pingHost)'" }
        if errorString.contains("addresslookuperror") { return "Host '\(pingHost)' could not be resolved (DNS lookup failed)" }
        if errorString.contains("hostnotfound") { return "Host '\(pingHost)' not found" }
        if errorString.contains("unknownhosterror") { return "Unknown host '\(pingHost)'" }
        if errorString.contains("operation could not be completed") { return "Failed to reach host '\(pingHost)' (network error)" }
        return "Error reaching '\(pingHost)': \(error.localizedDescription)"
    }
}
