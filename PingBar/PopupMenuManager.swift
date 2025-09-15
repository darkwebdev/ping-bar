import Cocoa

protocol PopupMenuDelegate: AnyObject {
    func showSettings()
    func clearHistory()
    func quitApp()
}

class PopupMenuManager: NSObject {
    weak var delegate: PopupMenuDelegate?
    
    init(delegate: PopupMenuDelegate) {
        self.delegate = delegate
        super.init()
    }
    
    func showPopupMenu(with pingData: [Int], currentPing: Int, errorMessage: String?, at location: NSPoint, in view: NSView) {
        let menu = createPopupMenu(with: pingData, currentPing: currentPing, errorMessage: errorMessage)
        showMenu(menu, at: location, in: view)
    }
    
    fileprivate func addStatusItems(_ currentPing: Int, _ errorMessage: String?, _ menu: NSMenu, _ pingData: [Int]) {
        let currentPingItem = NSMenuItem()
        if currentPing == 0 {
            currentPingItem.title = errorMessage ?? "Latest ping failed"
        } else {
            currentPingItem.title = "Latest ping: \(currentPing)ms"
        }
        currentPingItem.isEnabled = false
        menu.addItem(currentPingItem)
        
        if !pingData.isEmpty {
            let validPings = pingData.filter { $0 > 0 }
            if !validPings.isEmpty {
                let avgPing = validPings.reduce(0, +) / validPings.count
                let minPing = validPings.min() ?? 0
                let maxPing = validPings.max() ?? 0
                
                let statItem = NSMenuItem(title: "Min-Avg-Max: \(minPing)ms-\(avgPing)ms-\(maxPing)ms", action: nil, keyEquivalent: "")
                statItem.isEnabled = false
                menu.addItem(statItem)
            }
        }

        menu.addItem(NSMenuItem.separator())
    }
    
    private func createPopupMenu(with pingData: [Int], currentPing: Int, errorMessage: String?) -> NSMenu {
        let menu = NSMenu()
        
        addStatusItems(currentPing, errorMessage, menu, pingData)
        
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        let clearItem = NSMenuItem(title: "Clear History", action: #selector(clearHistory), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)
        
        return menu
    }
    
    private func showMenu(_ menu: NSMenu, at location: NSPoint, in view: NSView) {
        if let button = view as? NSButton {
            // Position menu below the status bar button
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: 0), in: button)
        } else {
            // Fallback: try to find button in superview
            if let button = view.superview as? NSButton {
                menu.popUp(positioning: nil, at: NSPoint(x: 0, y: 0), in: button)
            }
        }
    }
    
    @objc private func showSettings() {
        delegate?.showSettings()
    }
    
    @objc private func clearHistory() {
        delegate?.clearHistory()
    }
    
    @objc private func quitApp() {
        delegate?.quitApp()
    }
}
