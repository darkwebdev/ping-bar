import Cocoa
import Darwin

class HostMenuItemView: NSView {
    private let statusIndicator: NSView
    private let removeButton: NSButton
    private let hostLabel: NSTextField
    private let pingLabel: NSTextField
    let graphView: PopupMenuPingGraphView
    var host: HostData
    private var trackingArea: NSTrackingArea?
    weak var delegate: PopupMenuDelegate?
    weak var menuManager: PopupMenuManager?
    
    // Static property to track maximum hostname width across all instances
    static var maxHostnameWidth: CGFloat = 0
    static var currentMaxHistory: Int = 50 // Track current max history setting
    
    // Calculate dynamic graph width based on max history setting
    static func calculateGraphWidth(for maxHistory: Int) -> CGFloat {
        let barWidth: CGFloat = 2.0
        let leftPadding: CGFloat = 4.0
        let minWidth: CGFloat = 60 // Minimum width for small history values
        let maxWidth: CGFloat = 300 // Maximum width to prevent menu from becoming too wide
        
        // Calculate width needed for maxHistory bars with only left padding (no right padding)
        let calculatedWidth = leftPadding + (CGFloat(maxHistory) * barWidth)
        
        // Clamp between min and max values
        return max(minWidth, min(maxWidth, calculatedWidth))
    }
    
    init(host: HostData) {
        self.host = host
        self.statusIndicator = NSView()
        self.removeButton = NSButton()
        self.hostLabel = NSTextField()
        self.pingLabel = NSTextField()
        self.graphView = PopupMenuPingGraphView(hostData: host)
        
        // Set the hostname first so we can calculate proper width
        hostLabel.stringValue = host.host
        hostLabel.font = NSFont.menuFont(ofSize: 13)
        
        // Calculate the ACTUAL width needed for this specific hostname (not truncated)
        let actualHostnameWidth = host.host.size(withAttributes: [.font: NSFont.menuFont(ofSize: 13)]).width
        
        // Update the static maxHostnameWidth if this hostname is longer
        if actualHostnameWidth > HostMenuItemView.maxHostnameWidth {
            HostMenuItemView.maxHostnameWidth = actualHostnameWidth
        }
        
        // Calculate DYNAMIC width based on content and max history setting
        let graphWidth = HostMenuItemView.calculateGraphWidth(for: HostMenuItemView.currentMaxHistory)
        let rightMargin: CGFloat = 12
        let gapBetweenHostnameAndGraph: CGFloat = 30 // Increased gap to ensure no overlap
        let statusAreaWidth: CGFloat = 12 + 8 + 8 // 28 total (margin + indicator + spacing)
        
        // Use the maximum hostname width to ensure ALL hostnames fit without truncation
        let maxHostnameWidth = HostMenuItemView.maxHostnameWidth
        
        // Calculate total menu width dynamically - ensure it fits the longest hostname completely
        let totalMenuWidth = statusAreaWidth + maxHostnameWidth + gapBetweenHostnameAndGraph + graphWidth + rightMargin
        
        super.init(frame: NSRect(x: 0, y: 0, width: totalMenuWidth, height: 38))
        setupViews()
        updateContent()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var intrinsicContentSize: NSSize {
        // Calculate dynamic width based on current max hostname width and graph width
        let graphWidth = HostMenuItemView.calculateGraphWidth(for: HostMenuItemView.currentMaxHistory)
        let rightMargin: CGFloat = 12
        let gapBetweenHostnameAndGraph: CGFloat = 30 // Match the gap used in init
        let statusAreaWidth: CGFloat = 12 + 8 + 8 // 28 total
        
        let totalMenuWidth = statusAreaWidth + HostMenuItemView.maxHostnameWidth + gapBetweenHostnameAndGraph + graphWidth + rightMargin
        
        return NSSize(width: totalMenuWidth, height: 38)
    }
    
    private func setupViews() {
        // Status indicator (colored circle)
        statusIndicator.translatesAutoresizingMaskIntoConstraints = false
        statusIndicator.wantsLayer = true
        statusIndicator.layer?.cornerRadius = 4
        addSubview(statusIndicator)
        
        // Remove button (red cross) - initially hidden
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        removeButton.title = "✕"
        removeButton.font = NSFont.systemFont(ofSize: 10, weight: .bold)
        removeButton.bezelStyle = .circular
        removeButton.isBordered = false
        removeButton.wantsLayer = true
        removeButton.layer?.backgroundColor = NSColor.systemRed.cgColor
        removeButton.layer?.cornerRadius = 8
        removeButton.contentTintColor = .white
        removeButton.target = self
        removeButton.action = #selector(removeButtonClicked)
        removeButton.isHidden = true
        removeButton.alphaValue = 0.0
        addSubview(removeButton)
        
        // Host label
        hostLabel.translatesAutoresizingMaskIntoConstraints = false
        hostLabel.isEditable = false
        hostLabel.isBordered = false
        hostLabel.backgroundColor = .clear
        hostLabel.font = NSFont.menuFont(ofSize: 13)
        hostLabel.lineBreakMode = .byClipping // Prevent truncation - we'll size the menu to fit
        addSubview(hostLabel)
        
        // Ping label
        pingLabel.translatesAutoresizingMaskIntoConstraints = false
        pingLabel.isEditable = false
        pingLabel.isBordered = false
        pingLabel.backgroundColor = .clear
        pingLabel.font = NSFont.menuFont(ofSize: 9)
        pingLabel.textColor = NSColor.tertiaryLabelColor
        addSubview(pingLabel)
        
        // Mini graph
        graphView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(graphView)
        
        // Calculate dynamic layout values based on the MAXIMUM hostname width
        let statusAreaWidth: CGFloat = 12 + 8 + 8 // 28 total
        let gapBetweenHostnameAndGraph: CGFloat = 30 // Match the gap used in init method
        let graphWidth = HostMenuItemView.calculateGraphWidth(for: HostMenuItemView.currentMaxHistory)
        
        // Use the maximum hostname width to ensure no truncation
        let effectiveMaxWidth = HostMenuItemView.maxHostnameWidth
        
        // Calculate graph start position to ensure no overlap
        let graphStartPosition = statusAreaWidth + effectiveMaxWidth + gapBetweenHostnameAndGraph
        
        // Layout constraints - ensure hostname gets full width it needs
        NSLayoutConstraint.activate([
            // Status indicator
            statusIndicator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            statusIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),
            statusIndicator.widthAnchor.constraint(equalToConstant: 8),
            statusIndicator.heightAnchor.constraint(equalToConstant: 8),
            
            // Remove button (positioned over status indicator)
            removeButton.centerXAnchor.constraint(equalTo: statusIndicator.centerXAnchor),
            removeButton.centerYAnchor.constraint(equalTo: statusIndicator.centerYAnchor),
            removeButton.widthAnchor.constraint(equalToConstant: 16),
            removeButton.heightAnchor.constraint(equalToConstant: 16),
        
            // Host label - EXACT width to prevent truncation, using the maximum calculated width
            hostLabel.leadingAnchor.constraint(equalTo: statusIndicator.trailingAnchor, constant: 8),
            hostLabel.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            hostLabel.widthAnchor.constraint(equalToConstant: effectiveMaxWidth),
            
            // Ping label - positioned under host label, same width as host label
            pingLabel.leadingAnchor.constraint(equalTo: statusIndicator.trailingAnchor, constant: 8),
            pingLabel.topAnchor.constraint(equalTo: hostLabel.bottomAnchor, constant: 1),
            pingLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -3),
            pingLabel.widthAnchor.constraint(equalToConstant: effectiveMaxWidth),
            
            // Mini graph - positioned with guaranteed separation from hostname area
            graphView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: graphStartPosition),
            graphView.centerYAnchor.constraint(equalTo: centerYAnchor),
            graphView.widthAnchor.constraint(equalToConstant: graphWidth),
            graphView.heightAnchor.constraint(equalToConstant: 22),
            
            // Overall height
            heightAnchor.constraint(equalToConstant: 38)
        ])
        
        // Setup tracking area for mouse events
        setupTracking()
    }
    
    private func setupTracking() {
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeInKeyWindow]
        trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        
        setupTracking()
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        showRemoveButton()
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        hideRemoveButton()
    }
    
    private func showRemoveButton() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            removeButton.isHidden = false
            removeButton.animator().alphaValue = 1.0
            statusIndicator.animator().alphaValue = 0.3
        }
    }
    
    private func hideRemoveButton() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            removeButton.animator().alphaValue = 0.0
            statusIndicator.animator().alphaValue = 1.0
        } completionHandler: {
            self.removeButton.isHidden = true
        }
    }
    
    private func updateContent() {
        hostLabel.stringValue = host.host
        
        // Update status indicator color based on ping status
        let statusColor: NSColor
        // If we have a recent successful ping, show it immediately regardless of previous offline state
        if host.currentPing > 0 {
            if host.currentPing > 100 {
                statusColor = .systemYellow
            } else {
                statusColor = .systemGreen
            }
            pingLabel.stringValue = "\(host.currentPing)ms"
        } else if host.isOffline && host.hasHadSuccessfulPing {
            // Only show permanent offline (red) if we've previously seen a successful ping
            statusColor = .systemRed
            pingLabel.stringValue = "-"
        } else if host.currentPing == 0 {
             // Unknown, transient failures or no data yet
             statusColor = .systemGray
             pingLabel.stringValue = "-"
         } else if host.currentPing > 100 {
            statusColor = .systemYellow
            pingLabel.stringValue = "\(host.currentPing)ms"
         } else {
             statusColor = .systemGreen
            pingLabel.stringValue = "\(host.currentPing)ms"
         }
        
        statusIndicator.layer?.backgroundColor = statusColor.cgColor
        graphView.updateData()
    }
    
    func updateWithNewData(_ newHost: HostData) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.host = newHost
            self.graphView.updateHostData(newHost)
            self.updateContent()
            
            self.needsDisplay = true
            self.needsLayout = true
        }
    }
    
    @objc private func removeButtonClicked() {
        let hostToRemove = host.host
        delegate?.removeHost(hostToRemove)
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
    var currentMenu: NSMenu?
    weak var appDelegate: AppDelegate?
    
    init(delegate: PopupMenuDelegate, pingInterval: Double, maxHistory: Int, appDelegate: AppDelegate? = nil) {
        self.delegate = delegate
        self.pingInterval = pingInterval
        self.maxHistory = maxHistory
        self.appDelegate = appDelegate
        
        // Set the static currentMaxHistory so all views use the correct setting
        HostMenuItemView.currentMaxHistory = maxHistory
        
        super.init()
    }
    
    func showPopupMenu(with hosts: [HostData], at location: NSPoint, in view: NSView) {
        self.currentHosts = hosts
        let menu = createPopupMenu(with: hosts)
        menu.delegate = self
        self.currentMenu = menu
        showMenu(menu, at: location, in: view)
    }
    
    func menuDidClose(_ menu: NSMenu) {
        menuDidClose()
        appDelegate?.popupMenuDidClose()
    }
    
    func updateMenuContent(with hosts: [HostData]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.currentHosts = hosts
            
            for host in hosts {
                if let hostView = self.hostMenuViews[host.host] {
                    hostView.updateWithNewData(host)
                }
            }
        }
    }
    
    private func addStatusItems(for hosts: [HostData], to menu: NSMenu) {
        guard !hosts.isEmpty else {
            let noHostsItem = NSMenuItem(title: "No hosts configured", action: nil, keyEquivalent: "")
            noHostsItem.isEnabled = false
            menu.addItem(noHostsItem)
            menu.addItem(NSMenuItem.separator())
            return
        }
        
        // Reset the maximum hostname width
        HostMenuItemView.maxHostnameWidth = 0
        
        // Calculate maximum hostname width across all hosts
        for host in hosts {
            let hostnameSize = host.host.size(withAttributes: [
                .font: NSFont.menuFont(ofSize: 13)
            ])
            if hostnameSize.width > HostMenuItemView.maxHostnameWidth {
                HostMenuItemView.maxHostnameWidth = hostnameSize.width
            }
        }
        
        // Create views with the correct max width
        for host in hosts {
            let hostItem = NSMenuItem()
            let hostView = HostMenuItemView(host: host)
            hostView.delegate = self.delegate
            hostView.menuManager = self
            hostItem.view = hostView
            hostItem.isEnabled = false
            menu.addItem(hostItem)
            
            hostMenuViews[host.host] = hostView
        }
        
        menu.addItem(NSMenuItem.separator())
    }
    
    func menuDidClose() {
        hostMenuViews.removeAll()
        currentMenu = nil
    }
    
    private func createPopupMenu(with hosts: [HostData]) -> NSMenu {
        let menu = NSMenu()
        menu.appearance = NSApp.effectiveAppearance

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
        // Add Host item
        let addHostItem = NSMenuItem(title: "Add Host...", action: #selector(showAddHostDialog), keyEquivalent: "")
        addHostItem.target = self
        menu.addItem(addHostItem)
        
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
        
        // Network Settings item
        let dnsItem = NSMenuItem(title: "Network Settings...", action: #selector(openNetworkSettings), keyEquivalent: "")
        dnsItem.target = self
        menu.addItem(dnsItem)
        
        // Add Google DNS item
        let addDNSItem = NSMenuItem(title: "Add 8.8.8.8 to DNS list", action: #selector(addGoogleDNS), keyEquivalent: "")
        addDNSItem.target = self
        menu.addItem(addDNSItem)
        
        // Remove DNS item
        let removeDNSItem = NSMenuItem(title: "Remove DNS servers", action: #selector(removeGoogleDNS), keyEquivalent: "")
        removeDNSItem.target = self
        menu.addItem(removeDNSItem)
        
        menu.addItem(NSMenuItem.separator())
    }
    
    private func showMenu(_ menu: NSMenu, at location: NSPoint, in view: NSView) {
        menu.update()
        
        if let button = view as? NSButton {
            menu.popUp(positioning: menu.items.first, at: NSPoint(x: 0, y: button.bounds.height), in: button)
        } else {
            if let button = view.superview as? NSButton {
                menu.popUp(positioning: menu.items.first, at: NSPoint(x: 0, y: button.bounds.height), in: button)
            }
        }
    }
    
    @objc private func showAddHostDialog() {
        let alert = NSAlert()
        alert.messageText = "Add Host"
        alert.informativeText = "Enter hostname or IP address:"
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.placeholderString = "e.g., google.com"
        alert.accessoryView = textField
        textField.becomeFirstResponder()
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let hostName = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !hostName.isEmpty {
                delegate?.addHost(hostName)
            }
        }
    }
    
    @objc private func setInterval(_ sender: NSMenuItem) {
        guard let interval = sender.representedObject as? Double else { return }
        pingInterval = interval
        delegate?.updateInterval(interval)
    }
    
    @objc private func setMaxHistory(_ sender: NSMenuItem) {
        guard let history = sender.representedObject as? Int else { return }
        maxHistory = history
        
        // Update the static currentMaxHistory so all views use the new setting
        HostMenuItemView.currentMaxHistory = history
        
        delegate?.updateMaxHistory(history)
    }
    
    @objc private func clearHistory() {
        delegate?.clearHistory()
    }
    
    @objc private func quitApp() {
        delegate?.quitApp()
    }
    
    @objc private func openNetworkSettings() {
        // Open the Network pane in System Preferences
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Network.prefPane"))
    }
    
    @objc private func addGoogleDNS() {
        // First, get the Wi-Fi service name
        let getServiceScriptSource = """
        do shell script "networksetup -listallnetworkservices | grep -i 'Wi-Fi' | head -1"
        """
        let getServiceScript = NSAppleScript(source: getServiceScriptSource)
        var serviceError: NSDictionary?
        let serviceResult = getServiceScript?.executeAndReturnError(&serviceError)

        guard let serviceName = serviceResult?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines), !serviceName.isEmpty else {
            return
        }

        // Execute the command with privileges
        let setDNSScriptSource = "do shell script \"networksetup -setdnsservers \\\"\(serviceName)\\\" 8.8.8.8\" with administrator privileges"
        let setDNSScript = NSAppleScript(source: setDNSScriptSource)
        var setError: NSDictionary?
        let setResult = setDNSScript?.executeAndReturnError(&setError)
    }
    
    @objc private func removeGoogleDNS() {
        // First, get the Wi-Fi service name
        let getServiceScriptSource = """
        do shell script "networksetup -listallnetworkservices | grep -i 'Wi-Fi' | head -1"
        """
        let getServiceScript = NSAppleScript(source: getServiceScriptSource)
        var serviceError: NSDictionary?
        let serviceResult = getServiceScript?.executeAndReturnError(&serviceError)

        guard let serviceName = serviceResult?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines), !serviceName.isEmpty else {
            return
        }

        // Execute the command with privileges
        let setDNSScriptSource = "do shell script \"networksetup -setdnsservers \\\"\(serviceName)\\\" empty\" with administrator privileges"
        let setDNSScript = NSAppleScript(source: setDNSScriptSource)
        var setError: NSDictionary?
        let setResult = setDNSScript?.executeAndReturnError(&setError)
    }
    
    private func isUserAdmin() -> Bool {
        guard let adminGroup = getgrnam("admin") else { return false }
        let userName = NSUserName()
        guard let members = adminGroup.pointee.gr_mem else { return false }
        var i = 0
        while let member = members[i] {
            if String(cString: member) == userName {
                return true
            }
            i += 1
        }
        return false
    }
    
    private func showError(_ message: String) {
        showAlert(title: "Error", message: message, informativeText: nil)
    }
    
    private func showSuccess(_ message: String) {
        showAlert(title: "Success", message: message, informativeText: nil)
    }
    
    private func showInfo(_ message: String) {
        showAlert(title: "Info", message: message, informativeText: nil)
    }
    
    private func showAlert(title: String, message: String, informativeText: String?) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        
        if let informativeText = informativeText {
            alert.informativeText = informativeText
        }
        
        alert.runModal()
    }
}
