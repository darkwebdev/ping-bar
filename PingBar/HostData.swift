import Cocoa

struct HostData {
    let host: String
    var pingHistory: [Int]
    var currentPing: Int
    var errorMessage: String?
    let color: NSColor
    
    init(host: String, color: NSColor) {
        self.host = host
        self.pingHistory = []
        self.currentPing = 0
        self.errorMessage = nil
        self.color = color
    }
}

class MultiHostPingManager {
    private var hosts: [String: HostData] = [:]
    private var pingManagers: [String: PingManager] = [:]
    weak var delegate: MultiHostPingManagerDelegate?
    
    // Predefined colors for hosts
    private let hostColors: [NSColor] = [
        .systemBlue,
        .systemGreen,
        .systemOrange,
        .systemPurple,
        .systemRed,
        .systemYellow,
        .systemPink,
        .systemTeal
    ]
    
    var pingInterval: Double = 2.0 {
        didSet {
            for manager in pingManagers.values {
                manager.updateInterval(pingInterval)
            }
        }
    }
    
    var maxHistory: Int = 50
    
    func addHost(_ host: String) {
        guard !hosts.keys.contains(host) else { return }
        
        let colorIndex = hosts.count % hostColors.count
        let hostData = HostData(host: host, color: hostColors[colorIndex])
        hosts[host] = hostData
        
        let pingManager = PingManager()
        pingManager.delegate = self
        pingManager.pingHost = host
        pingManager.pingInterval = pingInterval
        pingManagers[host] = pingManager
        
        pingManager.startPinging()
        
        delegate?.multiHostPingManager(self, didUpdateHosts: Array(hosts.values))
    }
    
    func removeHost(_ host: String) {
        hosts.removeValue(forKey: host)
        pingManagers[host]?.stopPinging()
        pingManagers.removeValue(forKey: host)
        
        delegate?.multiHostPingManager(self, didUpdateHosts: Array(hosts.values))
    }
    
    func getAllHosts() -> [HostData] {
        return Array(hosts.values)
    }
    
    func getHost(_ host: String) -> HostData? {
        return hosts[host]
    }
    
    func startPinging() {
        for manager in pingManagers.values {
            manager.startPinging()
        }
    }
    
    func stopPinging() {
        for manager in pingManagers.values {
            manager.stopPinging()
        }
    }
    
    func clearHistory() {
        for (host, var hostData) in hosts {
            hostData.pingHistory.removeAll()
            hostData.currentPing = 0
            hosts[host] = hostData
        }
        delegate?.multiHostPingManager(self, didUpdateHosts: Array(hosts.values))
    }
}

// MARK: - PingManagerDelegate
extension MultiHostPingManager: PingManagerDelegate {
    func pingManager(_ manager: PingManager, didReceivePingResult result: Int) {
        // Find which host this ping result belongs to
        for (hostName, pingManager) in pingManagers {
            if pingManager === manager {
                updateHostData(hostName: hostName, pingResult: result, errorMessage: nil)
                break
            }
        }
    }
    
    func pingManager(_ manager: PingManager, didFailWithError error: String) {
        // Find which host this error belongs to
        for (hostName, pingManager) in pingManagers {
            if pingManager === manager {
                updateHostData(hostName: hostName, pingResult: 0, errorMessage: error)
                break
            }
        }
    }
    
    private func updateHostData(hostName: String, pingResult: Int, errorMessage: String?) {
        guard var hostData = hosts[hostName] else { return }
        
        // Update current ping and error message
        hostData.currentPing = pingResult
        hostData.errorMessage = errorMessage
        
        // Add to history (limit to maxHistory)
        hostData.pingHistory.append(pingResult)
        if hostData.pingHistory.count > maxHistory {
            hostData.pingHistory.removeFirst()
        }
        
        // Update the host data
        hosts[hostName] = hostData
        
        // Notify delegate about the update (this triggers popup menu updates)
        delegate?.multiHostPingManager(self, didUpdateHosts: Array(hosts.values))
    }
}

// MARK: - MultiHostPingManagerDelegate Protocol
protocol MultiHostPingManagerDelegate: AnyObject {
    func multiHostPingManager(_ manager: MultiHostPingManager, didUpdateHosts hosts: [HostData])
    func multiHostPingManager(_ manager: MultiHostPingManager, didReceivePingResult result: Int, forHost host: String)
    func multiHostPingManager(_ manager: MultiHostPingManager, didFailWithError error: String, forHost host: String)
}
