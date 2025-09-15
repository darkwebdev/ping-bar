import Cocoa

// MARK: - Custom Menu Item View
class HostMenuItemView: NSView {
    private let statusIndicator: NSView
    private let hostLabel: NSTextField
    private let pingLabel: NSTextField
    private let miniGraphView: MiniPingGraphView
    private var host: HostData
    
    init(host: HostData) {
        self.host = host
        self.statusIndicator = NSView()
        self.hostLabel = NSTextField()
        self.pingLabel = NSTextField()
        self.miniGraphView = MiniPingGraphView(hostData: host)
        
        super.init(frame: NSRect(x: 0, y: 0, width: 280, height: 38))
        setupViews()
        updateContent()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var intrinsicContentSize: NSSize {
        return NSSize(width: 280, height: 38)
    }
    
    private func setupViews() {
        // Status indicator (colored circle)
        statusIndicator.translatesAutoresizingMaskIntoConstraints = false
        statusIndicator.wantsLayer = true
        statusIndicator.layer?.cornerRadius = 4
        addSubview(statusIndicator)
        
        // Host label
        hostLabel.translatesAutoresizingMaskIntoConstraints = false
        hostLabel.isEditable = false
        hostLabel.isBordered = false
        hostLabel.backgroundColor = .clear
        hostLabel.font = NSFont.menuFont(ofSize: 13)
        addSubview(hostLabel)
        
        // Ping label
        pingLabel.translatesAutoresizingMaskIntoConstraints = false
        pingLabel.isEditable = false
        pingLabel.isBordered = false
        pingLabel.backgroundColor = .clear
        pingLabel.font = NSFont.menuFont(ofSize: 9)
        pingLabel.textColor = .secondaryLabelColor
        addSubview(pingLabel)
        
        // Mini graph
        miniGraphView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(miniGraphView)
        
        // Layout constraints with proper spacing and sizing
        NSLayoutConstraint.activate([
            // Status indicator
            statusIndicator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            statusIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),
            statusIndicator.widthAnchor.constraint(equalToConstant: 8),
            statusIndicator.heightAnchor.constraint(equalToConstant: 8),
            
            // Host label
            hostLabel.leadingAnchor.constraint(equalTo: statusIndicator.trailingAnchor, constant: 8),
            hostLabel.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            hostLabel.widthAnchor.constraint(equalToConstant: 110),
            
            // Ping label - with proper bottom spacing
            pingLabel.leadingAnchor.constraint(equalTo: statusIndicator.trailingAnchor, constant: 8),
            pingLabel.topAnchor.constraint(equalTo: hostLabel.bottomAnchor, constant: 1),
            pingLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -3),
            pingLabel.widthAnchor.constraint(equalToConstant: 110),
            
            // Mini graph - right-aligned with proper spacing
            miniGraphView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            miniGraphView.centerYAnchor.constraint(equalTo: centerYAnchor),
            miniGraphView.widthAnchor.constraint(equalToConstant: 120),
            miniGraphView.heightAnchor.constraint(equalToConstant: 22),
            
            // Ensure minimum spacing between labels and graph
            miniGraphView.leadingAnchor.constraint(greaterThanOrEqualTo: hostLabel.trailingAnchor, constant: 12),
            
            // Overall height matches frame
            heightAnchor.constraint(equalToConstant: 38)
        ])
    }
    
    private func updateContent() {
        hostLabel.stringValue = host.host
        
        // Update status indicator color based on ping status
        let statusColor: NSColor
        if host.currentPing == 0 {
            statusColor = .systemRed // Red for failed ping
            pingLabel.stringValue = host.errorMessage ?? "Ping failed"
        } else if host.currentPing > 100 {
            statusColor = .systemYellow // Yellow for slow ping
            pingLabel.stringValue = "\(host.currentPing)ms"
        } else {
            statusColor = .systemGreen // Green for good ping
            pingLabel.stringValue = "\(host.currentPing)ms"
        }
        
        statusIndicator.layer?.backgroundColor = statusColor.cgColor
        miniGraphView.updateData()
    }
    
    func updateWithNewData(_ newHost: HostData) {
        // Ensure updates happen on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Update the view with new host data
            self.host = newHost
            self.miniGraphView.updateHostData(newHost)
            self.updateContent()
            
            // Force view refresh
            self.needsDisplay = true
            self.needsLayout = true
        }
    }
}

// MARK: - Mini Ping Graph View
class MiniPingGraphView: NSView {
    private var hostData: HostData
    
    init(hostData: HostData) {
        self.hostData = hostData
        super.init(frame: .zero)
        self.wantsLayer = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateData() {
        needsDisplay = true
    }
    
    func updateHostData(_ newHostData: HostData) {
        self.hostData = newHostData
        needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Clear background
        NSColor.clear.setFill()
        bounds.fill()
        
        guard !hostData.pingHistory.isEmpty else { return }
        
        // Reduced internal spacing - minimal inset for maximum graph area
        let graphRect = bounds.insetBy(dx: 1, dy: 1)
        let history = Array(hostData.pingHistory.suffix(20)) // Show last 20 data points
        
        guard history.count > 1 else { return }
        
        let pointWidth = graphRect.width / CGFloat(history.count - 1)
        let maxPing = history.filter { $0 > 0 }.max() ?? 100
        
        let path = NSBezierPath()
        var hasValidPoints = false
        
        for (index, ping) in history.enumerated() {
            let x = graphRect.minX + CGFloat(index) * pointWidth
            let y: CGFloat
            
            if ping > 0 {
                let normalizedHeight = CGFloat(ping) / CGFloat(maxPing)
                y = graphRect.minY + normalizedHeight * graphRect.height
            } else {
                y = graphRect.minY
            }
            
            if !hasValidPoints {
                path.move(to: NSPoint(x: x, y: y))
                hasValidPoints = true
            } else {
                path.line(to: NSPoint(x: x, y: y))
            }
        }
        
        if hasValidPoints {
            hostData.color.withAlphaComponent(0.8).setStroke()
            path.lineWidth = 1.0
            path.stroke()
        }
    }
}

protocol PopupMenuDelegate: AnyObject {
    func addHost(_ host: String)
    func removeHost(_ host: String)
    func updateInterval(_ interval: Double)
    func updateMaxHistory(_ maxHistory: Int)
    func clearHistory()
    func quitApp()
}

class PopupMenuManager: NSObject, NSMenuDelegate {
    weak var delegate: PopupMenuDelegate?
    private var pingInterval: Double = 2.0
    private var maxHistory: Int = 50
    private var currentHosts: [HostData] = []
    private var hostMenuViews: [String: HostMenuItemView] = [:]
    private var currentMenu: NSMenu?
    weak var appDelegate: AppDelegate?
    
    init(delegate: PopupMenuDelegate, pingInterval: Double, maxHistory: Int, appDelegate: AppDelegate? = nil) {
        self.delegate = delegate
        self.pingInterval = pingInterval
        self.maxHistory = maxHistory
        self.appDelegate = appDelegate
        super.init()
    }
    
    func showPopupMenu(with hosts: [HostData], at location: NSPoint, in view: NSView) {
        self.currentHosts = hosts
        let menu = createPopupMenu(with: hosts)
        menu.delegate = self
        self.currentMenu = menu
        showMenu(menu, at: location, in: view)
    }
    
    // MARK: - NSMenuDelegate
    func menuDidClose(_ menu: NSMenu) {
        // Clean up when menu closes
        menuDidClose()
        appDelegate?.popupMenuDidClose()
    }
    
    // Add method to update menu content in real time
    func updateMenuContent(with hosts: [HostData]) {
        // Ensure UI updates happen on the main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let menu = self.currentMenu else { return }
            
            self.currentHosts = hosts
            
            // Update existing host views
            for host in hosts {
                if let hostView = self.hostMenuViews[host.host] {
                    hostView.updateWithNewData(host)
                }
            }
        }
    }
    
    // Clear references when menu is dismissed
    func menuDidClose() {
        hostMenuViews.removeAll()
        currentMenu = nil
    }
    
    private func addStatusItems(for hosts: [HostData], to menu: NSMenu) {
        guard !hosts.isEmpty else {
            let noHostsItem = NSMenuItem(title: "No hosts configured", action: nil, keyEquivalent: "")
            noHostsItem.isEnabled = false
            menu.addItem(noHostsItem)
            menu.addItem(NSMenuItem.separator())
            return
        }
        
        // Add custom view for each host
        for host in hosts {
            let hostItem = NSMenuItem()
            let hostView = HostMenuItemView(host: host)
            hostItem.view = hostView
            hostItem.isEnabled = false
            menu.addItem(hostItem)
            
            // Keep a reference to the host view for real-time updates
            hostMenuViews[host.host] = hostView
        }
        
        menu.addItem(NSMenuItem.separator())
    }
    
    private func createPopupMenu(with hosts: [HostData]) -> NSMenu {
        let menu = NSMenu()
        
        addStatusItems(for: hosts, to: menu)
        addSettingsItems(to: menu)
        
        let clearItem = NSMenuItem(title: "Clear History", action: #selector(clearHistory), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)
        
        return menu
    }
    
    private func addSettingsItems(to menu: NSMenu) {
        // Host Management section
        let addHostItem = NSMenuItem(title: "Add Host...", action: #selector(showAddHostDialog), keyEquivalent: "")
        addHostItem.target = self
        menu.addItem(addHostItem)
        
        // Remove Host submenu
        let removeHostItem = NSMenuItem(title: "Remove Host", action: nil, keyEquivalent: "")
        let removeSubmenu = NSMenu()
        
        for host in currentHosts {
            let hostRemoveItem = NSMenuItem(title: host.host, action: #selector(removeHostAction(_:)), keyEquivalent: "")
            hostRemoveItem.target = self
            hostRemoveItem.representedObject = host.host
            removeSubmenu.addItem(hostRemoveItem)
        }
        
        if currentHosts.isEmpty {
            let noHostsItem = NSMenuItem(title: "No hosts to remove", action: nil, keyEquivalent: "")
            noHostsItem.isEnabled = false
            removeSubmenu.addItem(noHostsItem)
        }
        
        removeHostItem.submenu = removeSubmenu
        menu.addItem(removeHostItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Ping Interval submenu
        let intervalItem = NSMenuItem(title: "Ping Interval", action: nil, keyEquivalent: "")
        let intervalSubmenu = NSMenu()
        
        let intervalOptions = [0.5, 1.0, 2.0, 5.0, 10.0]
        for interval in intervalOptions {
            let item = NSMenuItem(title: "\(interval)s", action: #selector(setInterval(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = interval
            if abs(interval - pingInterval) < 0.1 {
                item.state = .on
            }
            intervalSubmenu.addItem(item)
        }
        
        intervalItem.submenu = intervalSubmenu
        menu.addItem(intervalItem)
        
        // Max History submenu
        let historyItem = NSMenuItem(title: "Max History", action: nil, keyEquivalent: "")
        let historySubmenu = NSMenu()
        
        let historyOptions = [10, 25, 50, 100, 200]
        for history in historyOptions {
            let item = NSMenuItem(title: "\(history) pings", action: #selector(setMaxHistory(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = history
            if history == maxHistory {
                item.state = .on
            }
            historySubmenu.addItem(item)
        }
        
        historyItem.submenu = historySubmenu
        menu.addItem(historyItem)
        
        menu.addItem(NSMenuItem.separator())
    }
    
    private func showMenu(_ menu: NSMenu, at location: NSPoint, in view: NSView) {
        // Force the menu to calculate its size properly
        menu.update()
        
        if let button = view as? NSButton {
            // Position menu below the status bar button with proper positioning
            menu.popUp(positioning: menu.items.first, at: NSPoint(x: 0, y: button.bounds.height), in: button)
        } else {
            // Fallback: try to find button in superview
            if let button = view.superview as? NSButton {
                menu.popUp(positioning: menu.items.first, at: NSPoint(x: 0, y: button.bounds.height), in: button)
            }
        }
    }
    
    @objc private func showAddHostDialog() {
        let alert = NSAlert()
        alert.messageText = "Add New Host"
        alert.informativeText = "Enter the hostname or IP address to monitor:"
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.placeholderString = "e.g., google.com or 192.168.1.1"
        alert.accessoryView = textField
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let hostName = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !hostName.isEmpty {
                delegate?.addHost(hostName)
            }
        }
    }
    
    @objc private func removeHostAction(_ sender: NSMenuItem) {
        guard let hostName = sender.representedObject as? String else { return }
        delegate?.removeHost(hostName)
    }
    
    @objc private func setInterval(_ sender: NSMenuItem) {
        guard let interval = sender.representedObject as? Double else { return }
        pingInterval = interval
        delegate?.updateInterval(interval)
    }
    
    @objc private func setMaxHistory(_ sender: NSMenuItem) {
        guard let history = sender.representedObject as? Int else { return }
        maxHistory = history
        delegate?.updateMaxHistory(history)
    }
    
    @objc private func clearHistory() {
        delegate?.clearHistory()
    }
    
    @objc private func quitApp() {
        delegate?.quitApp()
    }
}
