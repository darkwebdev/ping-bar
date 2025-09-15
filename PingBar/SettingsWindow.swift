import Cocoa

class SettingsWindow: NSObject {
    weak var appDelegate: AppDelegate?
    var window: NSWindow?
    
    // Temporary settings storage
    private var tempPingHost: String = ""
    private var tempPingInterval: Double = 2.0
    private var tempMaxHistory: Int = 50
    
    // UI elements
    private var hostField: NSTextField!
    private var intervalField: NSTextField!
    private var historyField: NSTextField!
    
    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        super.init()
    }
    
    func show() {
        if window == nil {
            createWindow()
        }
        // Load current settings into temporary storage
        loadCurrentSettings()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func loadCurrentSettings() {
        guard let appDelegate = appDelegate else { return }
        tempPingHost = appDelegate.pingHost
        tempPingInterval = appDelegate.pingInterval
        tempMaxHistory = appDelegate.maxHistory
        
        // Update UI fields
        hostField?.stringValue = tempPingHost
        intervalField?.doubleValue = tempPingInterval
        historyField?.integerValue = tempMaxHistory
    }
    
    private func createWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 200),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window?.title = "PingBar Settings"
        window?.center()
        window?.isReleasedWhenClosed = false
        
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 350, height: 200))
        window?.contentView = contentView
        
        setupUI(in: contentView)
    }
    
    private func setupUI(in contentView: NSView) {
        guard let appDelegate = appDelegate else { return }
        
        // Host field
        let hostLabel = NSTextField(labelWithString: "Ping host:")
        hostLabel.frame = NSRect(x: 20, y: 140, width: 80, height: 20)
        contentView.addSubview(hostLabel)
        
        hostField = NSTextField(frame: NSRect(x: 110, y: 140, width: 200, height: 20))
        hostField.stringValue = appDelegate.pingHost
        hostField.target = self
        hostField.action = #selector(hostChanged(_:))
        // Add delegate to capture text changes as they happen
        hostField.delegate = self
        contentView.addSubview(hostField)
        
        // Interval field
        let intervalLabel = NSTextField(labelWithString: "Interval (s):")
        intervalLabel.frame = NSRect(x: 20, y: 100, width: 80, height: 20)
        contentView.addSubview(intervalLabel)
        
        intervalField = NSTextField(frame: NSRect(x: 110, y: 100, width: 100, height: 20))
        intervalField.doubleValue = appDelegate.pingInterval
        intervalField.target = self
        intervalField.action = #selector(intervalChanged(_:))
        intervalField.delegate = self
        contentView.addSubview(intervalField)
        
        // History count field
        let historyLabel = NSTextField(labelWithString: "Max history:")
        historyLabel.frame = NSRect(x: 20, y: 60, width: 80, height: 20)
        contentView.addSubview(historyLabel)
        
        historyField = NSTextField(frame: NSRect(x: 110, y: 60, width: 100, height: 20))
        historyField.integerValue = appDelegate.maxHistory
        historyField.target = self
        historyField.action = #selector(historyChanged(_:))
        historyField.delegate = self
        contentView.addSubview(historyField)
        
        // Cancel button
        let cancelButton = NSButton(frame: NSRect(x: 170, y: 20, width: 80, height: 30))
        cancelButton.title = "Cancel"
        cancelButton.target = self
        cancelButton.action = #selector(cancelSettings)
        contentView.addSubview(cancelButton)
        
        // Save button
        let saveButton = NSButton(frame: NSRect(x: 260, y: 20, width: 80, height: 30))
        saveButton.title = "Save"
        saveButton.target = self
        saveButton.action = #selector(saveSettings)
        saveButton.keyEquivalent = "\r" // Make it the default button (Enter key)
        contentView.addSubview(saveButton)
    }
    
    @objc func hostChanged(_ sender: NSTextField) {
        tempPingHost = sender.stringValue
    }
    
    @objc func intervalChanged(_ sender: NSTextField) {
        tempPingInterval = max(0.5, sender.doubleValue)
    }
    
    @objc func historyChanged(_ sender: NSTextField) {
        tempMaxHistory = max(10, sender.integerValue)
    }
    
    @objc func saveSettings() {
        guard let appDelegate = appDelegate else {
            print("Error: No appDelegate reference")
            return
        }
        
        appDelegate.pingHost = tempPingHost
        appDelegate.pingInterval = tempPingInterval
        appDelegate.maxHistory = tempMaxHistory
        
        appDelegate.pingManager.updateHost(tempPingHost)
        appDelegate.pingManager.updateInterval(tempPingInterval)
        
        window?.close()
    }
    
    @objc func cancelSettings() {
        window?.close()
    }
}

extension SettingsWindow: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        if let textField = obj.object as? NSTextField {
            if textField == hostField {
                hostChanged(textField)
            } else if textField == intervalField {
                intervalChanged(textField)
            } else if textField == historyField {
                historyChanged(textField)
            }
        }
    }
    
    // Handle Enter key press in text fields
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            // Enter key was pressed - save settings
            saveSettings()
            return true
        }
        return false
    }
}
