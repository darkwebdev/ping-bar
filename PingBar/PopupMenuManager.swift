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
    
    func showPopupMenu(with pingData: [Int], currentPing: Int, at location: NSPoint, in view: NSView) {
        let menu = createPopupMenu(with: pingData, currentPing: currentPing)
        showMenu(menu, at: location, in: view)
    }
    
    private func createPopupMenu(with pingData: [Int], currentPing: Int) -> NSMenu {
        let menu = NSMenu()
        
        // Current ping status
        let currentPingItem = NSMenuItem()
        if currentPing == 0 {
            currentPingItem.title = "Current: No Response"
        } else {
            currentPingItem.title = "Current: \(currentPing)ms"
        }
        currentPingItem.isEnabled = false
        menu.addItem(currentPingItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Statistics
        if !pingData.isEmpty {
            let validPings = pingData.filter { $0 > 0 }
            if !validPings.isEmpty {
                let avgPing = validPings.reduce(0, +) / validPings.count
                let minPing = validPings.min() ?? 0
                let maxPing = validPings.max() ?? 0
                
                let avgItem = NSMenuItem(title: "Average: \(avgPing)ms", action: nil, keyEquivalent: "")
                avgItem.isEnabled = false
                menu.addItem(avgItem)
                
                let minItem = NSMenuItem(title: "Min: \(minPing)ms", action: nil, keyEquivalent: "")
                minItem.isEnabled = false
                menu.addItem(minItem)
                
                let maxItem = NSMenuItem(title: "Max: \(maxPing)ms", action: nil, keyEquivalent: "")
                maxItem.isEnabled = false
                menu.addItem(maxItem)
                
                menu.addItem(NSMenuItem.separator())
            }
        }
        
        // Actions
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
        // Show menu at the status bar button location
        // Since we're passing the button directly, we can use it directly
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
