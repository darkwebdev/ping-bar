import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var graphView: PingGraphView!
    var multiHostPingManager: MultiHostPingManager!
    var currentPopupMenuManager: PopupMenuManager?
    
    // Settings properties - now loaded from SettingsManager
    var pingInterval: Double {
        get { SettingsManager.shared.pingInterval }
        set { SettingsManager.shared.pingInterval = newValue }
    }
    
    var maxHistory: Int {
        get { SettingsManager.shared.maxHistory }
        set { SettingsManager.shared.maxHistory = newValue }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("applicationDidFinishLaunching")
        
        // Load settings from persistent storage
        SettingsManager.shared.loadDefaults()
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        graphView = PingGraphView(frame: NSRect.zero)
        graphView.appDelegate = self
        
        statusItem.button?.addSubview(graphView)
        
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusBarButtonClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // Use Auto Layout to size the button based on the view's intrinsic content size
        graphView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            graphView.leadingAnchor.constraint(equalTo: statusItem.button!.leadingAnchor),
            graphView.trailingAnchor.constraint(equalTo: statusItem.button!.trailingAnchor),
            graphView.topAnchor.constraint(equalTo: statusItem.button!.topAnchor),
            graphView.bottomAnchor.constraint(equalTo: statusItem.button!.bottomAnchor)
        ])
        
        setupMultiHostPingManager()
    }
    
    func setupMultiHostPingManager() {
        multiHostPingManager = MultiHostPingManager()
        multiHostPingManager.delegate = self
        multiHostPingManager.pingInterval = pingInterval
        multiHostPingManager.maxHistory = maxHistory
        
        // Load hosts from settings instead of using hardcoded defaults
        let savedHosts = SettingsManager.shared.hosts
        for host in savedHosts {
            multiHostPingManager.addHost(host)
        }
    }
    
    @objc func clearPingHistory() {
        multiHostPingManager.clearHistory()
    }
    
    @objc func statusBarButtonClicked() {
        showPopupMenu()
    }
    
    func showPopupMenu() {
        let popupMenuManager = PopupMenuManager(
            delegate: self,
            pingInterval: pingInterval,
            maxHistory: maxHistory,
            appDelegate: self
        )
        
        // Keep reference to the active popup menu manager
        self.currentPopupMenuManager = popupMenuManager
        
        let hosts = multiHostPingManager.getAllHosts()
        
        if let button = statusItem.button {
            popupMenuManager.showPopupMenu(
                with: hosts,
                at: NSPoint(x: 0, y: 0),
                in: button
            )
        }
    }
    
    // Add method to handle menu closing
    func popupMenuDidClose() {
        currentPopupMenuManager?.menuDidClose()
        currentPopupMenuManager = nil
    }
}

// MARK: - PopupMenuDelegate
extension AppDelegate: PopupMenuDelegate {
    func addHost(_ host: String) {
        multiHostPingManager.addHost(host)
        SettingsManager.shared.addHost(host)
        SettingsManager.shared.save()
    }
    
    func removeHost(_ host: String) {
        multiHostPingManager.removeHost(host)
        SettingsManager.shared.removeHost(host)
        SettingsManager.shared.save()
    }
    
    func updateInterval(_ interval: Double) {
        pingInterval = interval
        multiHostPingManager.pingInterval = interval
        SettingsManager.shared.save()
    }
    
    func updateMaxHistory(_ maxHistory: Int) {
        self.maxHistory = maxHistory
        multiHostPingManager.maxHistory = maxHistory
        SettingsManager.shared.save()
    }
    
    func clearHistory() {
        clearPingHistory()
    }
    
    func quitApp() {
        NSApp.terminate(nil)
    }
}

// MARK: - MultiHostPingManagerDelegate
extension AppDelegate: MultiHostPingManagerDelegate {
    func multiHostPingManager(_ manager: MultiHostPingManager, didUpdateHosts hosts: [HostData]) {
        // Update the status bar graph view
        graphView.hostData = hosts
        graphView.needsDisplay = true
        
        // Update the popup menu if it's currently open
        if let popupMenuManager = currentPopupMenuManager {
            popupMenuManager.updateMenuContent(with: hosts)
        }
    }
    
    func multiHostPingManager(_ manager: MultiHostPingManager, didReceivePingResult result: Int, forHost host: String) {
        // Individual ping updates are handled in didUpdateHosts
        // This method can be left empty or used for logging if needed
    }
    
    func multiHostPingManager(_ manager: MultiHostPingManager, didFailWithError error: String, forHost host: String) {
        // Individual ping errors are handled in didUpdateHosts
        // This method can be left empty or used for logging if needed
        print("Ping failed for host \(host): \(error)")
    }
}
