import Cocoa
import Foundation

class PopupMenuPingGraphView: NSView {
    private var hostData: HostData
    
    init(hostData: HostData) {
        self.hostData = hostData
        super.init(frame: NSRect(x: 0, y: 0, width: 60, height: 18))
        self.wantsLayer = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var intrinsicContentSize: NSSize {
        // Calculate width for bars without gaps, properly aligned with menu text
        let barWidth: CGFloat = 2.0
        let leftPadding: CGFloat = 4
        let maxHistory = HostMenuItemView.currentMaxHistory
        
        // Calculate width needed for bars without gaps - no right padding
        let barsWidth = CGFloat(maxHistory) * barWidth
        let totalWidth = leftPadding + barsWidth
        
        return NSSize(width: totalWidth, height: 18)
    }
    
    func updateHostData(_ newHostData: HostData) {
        self.hostData = newHostData
        DispatchQueue.main.async {
            self.needsDisplay = true
        }
    }
    
    func updateData() {
        DispatchQueue.main.async {
            self.needsDisplay = true
        }
    }
    
    // Add gradient color calculation method
    private func colorForPing(_ ping: Int) -> NSColor {
        if ping == 0 {
            // Unknown/failed ping — show neutral gray. Permanent offline is indicated by the red dot in the menu.
            return NSColor.systemGray
        } else if ping <= 20 {
            return NSColor.systemCyan // Good ping
        } else if ping >= 100 {
            return NSColor.systemYellow // Bad ping
        } else {
            // Interpolate between cyan and yellow for medium pings (21-99ms)
            let ratio = Double(ping - 20) / Double(100 - 20)
            return interpolateColor(from: NSColor.systemCyan, to: NSColor.systemYellow, ratio: ratio)
        }
    }
    
    // Add color interpolation method
    private func interpolateColor(from: NSColor, to: NSColor, ratio: Double) -> NSColor {
        let clampedRatio = max(0.0, min(1.0, ratio))
        
        // Convert colors to RGB space for interpolation
        guard let fromRGB = from.usingColorSpace(.deviceRGB),
              let toRGB = to.usingColorSpace(.deviceRGB) else {
            return ratio < 0.5 ? from : to
        }
        
        let red = fromRGB.redComponent + (toRGB.redComponent - fromRGB.redComponent) * clampedRatio
        let green = fromRGB.greenComponent + (toRGB.greenComponent - fromRGB.greenComponent) * clampedRatio
        let blue = fromRGB.blueComponent + (toRGB.blueComponent - fromRGB.blueComponent) * clampedRatio
        let alpha = fromRGB.alphaComponent + (toRGB.alphaComponent - fromRGB.alphaComponent) * clampedRatio
        
        return NSColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Clear background
        NSColor.clear.setFill()
        bounds.fill()
        
        let history = hostData.pingHistory
        guard !history.isEmpty else {
            drawNoDataIndicator()
            return
        }

        // Use the current max history setting instead of hardcoded maxDisplayPoints
        let maxDisplayPoints = HostMenuItemView.currentMaxHistory
        let displayHistory = Array(history.suffix(maxDisplayPoints))

        // Check if all pings are failed (all zeros)
        let hasSuccessfulPings = displayHistory.contains(where: { $0 > 0 })
        guard hasSuccessfulPings else {
            drawNoDataIndicator()
            return
        }

        let maxPing = displayHistory.filter { $0 > 0 }.max() ?? 100
        let adjustedMax = max(maxPing, 20) // Minimum scale of 20ms

        drawGraph(history: displayHistory, maxValue: adjustedMax)
        // Removed drawCurrentStatus() - no circle on right side
    }
    
    private func drawGraph(history: [Int], maxValue: Int) {
        guard !history.isEmpty else { return }
        
        // Use consistent padding to align with menu text - no right padding
        let leftPadding: CGFloat = 4
        let graphRect = NSRect(x: leftPadding, y: 2, width: bounds.width - leftPadding, height: bounds.height - 6)
        let barWidth: CGFloat = 2.0 // Fixed 2px width for all bars
        
        // Draw bars without gaps (as originally requested)
        for (index, ping) in history.enumerated() {
            let x = graphRect.minX + CGFloat(index) * barWidth

            // Only draw bars that fit within the graph area
            guard x + barWidth <= graphRect.maxX else { break }

            // Skip drawing entirely for failed pings (ping == 0)
            guard ping > 0 else { continue }

            // Calculate bar height based on ping value
            let normalizedHeight = Double(ping) / Double(maxValue)
            let barHeight = CGFloat(normalizedHeight) * graphRect.height
            let actualBarRect = NSRect(x: x, y: graphRect.minY, width: barWidth, height: barHeight)

            // Draw gradient bar from cyan (bottom) to ping-based color (top)
            drawGradientBar(in: actualBarRect, ping: ping)
        }
    }
    
    private func drawGradientBar(in rect: NSRect, ping: Int) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // Save the current graphics state
        context.saveGState()
        
        // Clip to the bar rectangle
        context.clip(to: rect)
        
        // Always start with cyan at the bottom
        let bottomColor = NSColor.systemCyan
        // End color based on ping value (for the full gradient effect)
        let topColor = colorForPing(ping)
        
        // Get CGColors directly (they are not optional)
        let bottomCGColor = bottomColor.cgColor
        let topCGColor = topColor.cgColor
        
        // Create color space and gradient
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let gradient = CGGradient(colorsSpace: colorSpace,
                                      colors: [bottomCGColor, topCGColor] as CFArray,
                                      locations: [0.0, 1.0]) else {
            // Fallback to solid color if gradient creation fails
            topColor.setFill()
            rect.fill()
            context.restoreGState()
            return
        }
        
        // Draw the gradient from bottom to top
        let startPoint = CGPoint(x: rect.midX, y: rect.minY)
        let endPoint = CGPoint(x: rect.midX, y: rect.maxY)
        
        context.drawLinearGradient(gradient,
                                 start: startPoint,
                                 end: endPoint,
                                 options: [])
        
        // Restore the graphics state
        context.restoreGState()
    }
    
    private func drawNoDataIndicator() {
        let message = "No response"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9),
            .foregroundColor: NSColor.tertiaryLabelColor
        ]

        let attributedString = NSAttributedString(string: message, attributes: attributes)
        let size = attributedString.size()
        let point = NSPoint(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2
        )

        attributedString.draw(at: point)
    }
}
