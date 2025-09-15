import Foundation

class SettingsManager {
    static let shared = SettingsManager()
    
    private let userDefaults = UserDefaults.standard
    
    // Keys for UserDefaults
    private enum Keys {
        static let pingInterval = "pingInterval"
        static let maxHistory = "maxHistory"
        static let hosts = "hosts"
    }
    
    private init() {}
    
    // MARK: - Ping Settings
    
    var pingInterval: Double {
        get {
            let value = userDefaults.double(forKey: Keys.pingInterval)
            return value > 0 ? value : 2.0 // Default to 2.0 if not set
        }
        set {
            userDefaults.set(newValue, forKey: Keys.pingInterval)
        }
    }
    
    var maxHistory: Int {
        get {
            let value = userDefaults.integer(forKey: Keys.maxHistory)
            return value > 0 ? value : 50 // Default to 50 if not set
        }
        set {
            userDefaults.set(newValue, forKey: Keys.maxHistory)
        }
    }
    
    // MARK: - Host Management
    
    var hosts: [String] {
        get {
            let savedHosts = userDefaults.stringArray(forKey: Keys.hosts) ?? []
            return savedHosts.isEmpty ? ["8.8.8.8", "1.1.1.1"] : savedHosts // Default hosts if none saved
        }
        set {
            userDefaults.set(newValue, forKey: Keys.hosts)
        }
    }
    
    func addHost(_ host: String) {
        var currentHosts = hosts
        if !currentHosts.contains(host) {
            currentHosts.append(host)
            hosts = currentHosts
        }
    }
    
    func removeHost(_ host: String) {
        var currentHosts = hosts
        currentHosts.removeAll { $0 == host }
        hosts = currentHosts
    }
    
    // MARK: - Save and Load
    
    func save() {
        userDefaults.synchronize()
    }
    
    func loadDefaults() {
        // This method can be used to set up initial defaults if needed
        if userDefaults.object(forKey: Keys.pingInterval) == nil {
            pingInterval = 2.0
        }
        if userDefaults.object(forKey: Keys.maxHistory) == nil {
            maxHistory = 50
        }
        if userDefaults.object(forKey: Keys.hosts) == nil {
            hosts = ["8.8.8.8", "1.1.1.1"]
        }
    }
}