import Cocoa

protocol PingManagerDelegate: AnyObject {
    func pingManager(_ manager: PingManager, didReceivePingResult result: Int)
    func pingManager(_ manager: PingManager, didTimeout: Void)
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
    
    func startPinging() {
        stopPinging()
        timer = Timer.scheduledTimer(timeInterval: pingInterval, target: self, selector: #selector(performPing), userInfo: nil, repeats: true)
        
        // Perform initial ping immediately
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
                self.delegate?.pingManager(self, didReceivePingResult: 0)
            }
            return 
        }
        
        print("Attempting to ping: \(pingHost)")
        
        do {
            currentPinger = try SwiftyPing(
                host: pingHost,
                configuration: PingConfiguration(interval: 0.5, with: 1),
                queue: DispatchQueue.global()
            )
        } catch {
            print("Failed to create pinger for host '\(pingHost)': \(error)")
            print("Sending error result (0) to delegate...")
            DispatchQueue.main.async {
                self.delegate?.pingManager(self, didReceivePingResult: 0)
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
            print("Failed to start pinging to '\(pingHost)': \(error)")
            DispatchQueue.main.async {
                self.delegate?.pingManager(self, didReceivePingResult: 0)
            }
            return
        }
        
        // Handle timeout after 2 seconds (reduced from 3 for faster feedback)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if !responseReceived {
                print("Ping timeout - no response from \(self.pingHost)")
                self.delegate?.pingManager(self, didTimeout: ())
            }
        }
    }
}
