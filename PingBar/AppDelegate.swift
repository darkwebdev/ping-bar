import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var pingHistory: [Int] = []
    var graphView: PingGraphView!
    var settingsWindow: SettingsWindow?
    var pingManager: PingManager!
    
    // Settings properties
    var pingInterval: Double = 2.0
    var pingHost: String = "8.8.8.8"
    var maxHistory: Int = 50

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("applicationDidFinishLaunching")
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        graphView = PingGraphView(frame: NSRect.zero)
        graphView.appDelegate = self // Set the AppDelegate reference
        
        // Set the view as the status item's custom view
        statusItem.button?.addSubview(graphView)
        
        // Configure the status item button to handle clicks directly
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusBarButtonClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp]) // Handle both left and right clicks
        }
        
        // Use Auto Layout to size the button based on the view's intrinsic content size
        graphView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            graphView.leadingAnchor.constraint(equalTo: statusItem.button!.leadingAnchor),
            graphView.trailingAnchor.constraint(equalTo: statusItem.button!.trailingAnchor),
            graphView.topAnchor.constraint(equalTo: statusItem.button!.topAnchor),
            graphView.bottomAnchor.constraint(equalTo: statusItem.button!.bottomAnchor)
        ])
        
        setupPingManager()
    }
    
    func setupPingManager() {
        pingManager = PingManager()
        pingManager.delegate = self
        pingManager.pingHost = pingHost
        pingManager.pingInterval = pingInterval
        pingManager.startPinging()
    }
    
    func startPingTimer() {
        pingManager.updateInterval(pingInterval)
    }

    func addPingResult(_ result: Int) {
        pingHistory.append(result)
        if pingHistory.count > maxHistory {
            pingHistory.removeFirst()
        }
        
        // Update graph
        graphView.pingData = pingHistory
        graphView.currentPing = result
        graphView.needsDisplay = true
    }
    
    @objc func clearPingHistory() {
        pingHistory.removeAll()
        graphView.pingData = pingHistory  // Update the view's data with the cleared history
        graphView.currentPing = 0  // Reset current ping display
        graphView.needsDisplay = true
    }
    
    @objc func hostChanged(_ sender: NSTextField) {
        pingHost = sender.stringValue
        pingManager.updateHost(pingHost)
    }
    
    @objc func intervalChanged(_ sender: NSTextField) {
        pingInterval = max(0.5, sender.doubleValue)
        pingManager.updateInterval(pingInterval)
    }
    
    @objc func historyChanged(_ sender: NSTextField) {
        maxHistory = max(10, sender.integerValue)
    }

    @objc func statusBarButtonClicked() {
        print("Status bar button clicked")
        showPopupMenu()
    }
    
    func showPopupMenu() {
        // Create popup menu manager if it doesn't exist
        let popupMenuManager = PopupMenuManager(delegate: self)
        
        // Get the current ping data and status
        let currentPingData = pingHistory
        let currentPingValue = graphView.currentPing
        
        // Show the popup menu at the status bar button location
        if let button = statusItem.button {
            popupMenuManager.showPopupMenu(
                with: currentPingData,
                currentPing: currentPingValue,
                at: NSPoint(x: 0, y: 0),
                in: button
            )
        }
    }
}

// MARK: - PopupMenuDelegate
extension AppDelegate: PopupMenuDelegate {
    func showSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindow(appDelegate: self)
        }
        settingsWindow?.show()
    }
    
    func clearHistory() {
        clearPingHistory()
    }
    
    func quitApp() {
        NSApp.terminate(nil)
    }
}

// MARK: - PingManagerDelegate
extension AppDelegate: PingManagerDelegate {
    func pingManager(_ manager: PingManager, didReceivePingResult result: Int) {
        print("AppDelegate received ping result: \(result)")
        addPingResult(result)
    }
    
    func pingManager(_ manager: PingManager, didTimeout: Void) {
        print("AppDelegate received timeout")
        addPingResult(0) // 0 represents no response
    }
}
