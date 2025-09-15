import Cocoa

protocol PingManagerDelegate: AnyObject {
    func pingManager(_ manager: PingManager, didReceivePingResult result: Int)
    func pingManager(_ manager: PingManager, didFailWithError error: String)
}

class PingManager: NSObject {
    weak var delegate: PingManagerDelegate?
    private var timer: Timer?
    private var currentPinger: SwiftyPing?
    
    // Settings
    var pingHost: String = "1.1.1.1"
    var pingInterval: Double = 2.0
    
    override init() {
        super.init()
    }
    
    // Function to convert cryptic error messages to user-friendly ones
    private func userFriendlyErrorMessage(from error: Error) -> String {
        let errorString = error.localizedDescription.lowercased()
        
        // Check for DNS/hostname resolution errors
        if errorString.contains("error 8") || errorString.contains("nodename nor servname provided") {
            return "Host '\(pingHost)' could not be resolved (invalid hostname)"
        }
        
        if errorString.contains("error 9") || errorString.contains("address family not supported") {
            return "Host '\(pingHost)' could not be resolved (DNS lookup failed)"
        }
        
        if errorString.contains("error -1003") || errorString.contains("server with the specified hostname could not be found") {
            return "Host '\(pingHost)' could not be found (DNS resolution failed)"
        }
        
        if errorString.contains("error -1001") || errorString.contains("request timed out") {
            return "Connection to '\(pingHost)' timed out"
        }
        
        if errorString.contains("error -1004") || errorString.contains("could not connect to the server") {
            return "Could not connect to host '\(pingHost)'"
        }
        
        if errorString.contains("network is unreachable") {
            return "Network is unreachable for host '\(pingHost)'"
        }
        
        if errorString.contains("host is down") {
            return "Host '\(pingHost)' is down or unreachable"
        }
        
        if errorString.contains("no route to host") {
            return "No route to host '\(pingHost)'"
        }
        
        if errorString.contains("connection refused") {
            return "Connection refused by host '\(pingHost)'"
        }
        
        // For SwiftyPing specific errors
        if errorString.contains("addresslookuperror") {
            return "Host '\(pingHost)' could not be resolved (DNS lookup failed)"
        }
        
        if errorString.contains("hostnotfound") {
            return "Host '\(pingHost)' not found"
        }
        
        if errorString.contains("unknownhosterror") {
            return "Unknown host '\(pingHost)'"
        }
        
        // If we can't identify the specific error, return a cleaner version
        if errorString.contains("operation could not be completed") {
            return "Failed to reach host '\(pingHost)' (network error)"
        }
        
        // Fallback to original error but make it cleaner
        return "Error reaching '\(pingHost)': \(error.localizedDescription)"
    }
    
    func startPinging() {
        stopPinging()
        timer = Timer.scheduledTimer(timeInterval: pingInterval, target: self, selector: #selector(performPing), userInfo: nil, repeats: true)
        
        performPing()
    }
    
    func stopPinging() {
        timer?.invalidate()
        timer = nil
        currentPinger = nil
    }
    
    func updateInterval(_ newInterval: Double) {
        pingInterval = max(0.5, newInterval)
        if timer != nil {
            startPinging() // Restart with new interval
        }
    }
    
    func updateHost(_ newHost: String) {
        pingHost = newHost
        // Restart pinging with the new host if currently pinging
        if timer != nil {
            startPinging()
        }
    }
    
    @objc private func performPing() {
        guard !pingHost.isEmpty else {
            print("Empty ping host")
            DispatchQueue.main.async {
                self.delegate?.pingManager(self, didFailWithError: "Empty ping host")
            }
            return
        }
        
        var errorReported = false
        
        do {
            currentPinger = try SwiftyPing(
                host: pingHost,
                configuration: PingConfiguration(interval: 0.5, with: 1),
                queue: DispatchQueue.global()
            )
        } catch {
            errorReported = true
            let friendlyError = userFriendlyErrorMessage(from: error)
            print("Failed to ping host '\(pingHost)': \(error)")
            DispatchQueue.main.async {
                self.delegate?.pingManager(self, didFailWithError: friendlyError)
            }
            return
        }
        
        var responseReceived = false
        
        currentPinger?.observer = { [weak self] (response) in
            guard let self = self else { return }
            responseReceived = true
            let roundedDuration = ceil(response.duration * 1000)
            let pingResult = Int(roundedDuration)
            print("Ping to \(self.pingHost): \(pingResult)ms")
            
            DispatchQueue.main.async {
                self.delegate?.pingManager(self, didReceivePingResult: pingResult)
            }
        }
        
        currentPinger?.targetCount = 1
        
        do {
            try currentPinger?.startPinging()
        } catch {
            errorReported = true
            let friendlyError = userFriendlyErrorMessage(from: error)
            print("Failed to start pinging to '\(pingHost)': \(error)")
            DispatchQueue.main.async {
                self.delegate?.pingManager(self, didFailWithError: friendlyError)
            }
            return
        }
        
        // Handle timeout after 2 seconds - only if no other error was reported
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if !responseReceived && !errorReported {
                print("Ping timeout - no response from \(self.pingHost)")
                self.delegate?.pingManager(self, didFailWithError: "Timeout - no response from \(self.pingHost)")
            }
        }
    }
}
