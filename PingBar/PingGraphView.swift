//
//  PingGraphView.swift
//  PingBar
//
//  Created by Manyanov, Timur on 12.09.25.
//
import Cocoa

class PingGraphView: NSView {
    var hostData: [HostData] = []
    weak var appDelegate: AppDelegate?
    
    override var intrinsicContentSize: NSSize {
        let minGraphWidth: CGFloat = 60
        let margin: CGFloat = 4
        
        // Total width: left margin + graph + right margin
        let totalWidth = margin + minGraphWidth + margin
        
        // Height should be standard menu bar height
        let totalHeight: CGFloat = 22
        
        return NSSize(width: totalWidth, height: totalHeight)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Clear background
        NSColor.clear.setFill()
        bounds.fill()
        
        // Draw graph using full width
        let margin: CGFloat = 4
        let graphRect = NSRect(
            x: margin,
            y: 2,
            width: bounds.width - margin * 2,
            height: bounds.height - 4
        )
        
        guard !hostData.isEmpty && graphRect.width > 0 else { return }
        
        // Find the maximum number of data points across all hosts
        let maxDataPoints = hostData.map { $0.pingHistory.count }.max() ?? 0
        guard maxDataPoints > 0 else { return }
        
        let pointWidth: CGFloat = graphRect.width / CGFloat(max(1, maxDataPoints - 1))
        
        // Draw each host's line graph
        for host in hostData {
            drawLineGraph(for: host, in: graphRect, pointWidth: pointWidth)
        }
    }
    
    private func colorForPing(_ ping: Int) -> NSColor {
        // Define thresholds for ping quality
        let goodPingThreshold: Double = 20   // <= 20ms is excellent (cyan)
        let badPingThreshold: Double = 100   // >= 100ms is poor (yellow)
        
        if ping <= 0 {
            // Unknown/failed ping that's not necessarily offline — draw neutral gray.
            // The permanent offline state is shown by the offline indicator (red dot).
            return NSColor.systemGray
        }
        
        let pingValue = Double(ping)
        
        if pingValue <= goodPingThreshold {
            // Excellent ping - cyan
            return NSColor.systemCyan
        } else if pingValue >= badPingThreshold {
            // Poor ping - yellow
            return NSColor.systemYellow
        } else {
            // Interpolate between cyan and yellow
            let ratio = (pingValue - goodPingThreshold) / (badPingThreshold - goodPingThreshold)
            return interpolateColor(from: NSColor.systemCyan, to: NSColor.systemYellow, ratio: ratio)
        }
    }
    
    private func interpolateColor(from startColor: NSColor, to endColor: NSColor, ratio: Double) -> NSColor {
        let clampedRatio = max(0.0, min(1.0, ratio))
        
        // Convert colors to RGB components
        guard let startRGB = startColor.usingColorSpace(.deviceRGB),
              let endRGB = endColor.usingColorSpace(.deviceRGB) else {
            return startColor
        }
        
        let red = startRGB.redComponent + (endRGB.redComponent - startRGB.redComponent) * clampedRatio
        let green = startRGB.greenComponent + (endRGB.greenComponent - startRGB.greenComponent) * clampedRatio
        let blue = startRGB.blueComponent + (endRGB.blueComponent - startRGB.blueComponent) * clampedRatio
        let alpha = startRGB.alphaComponent + (endRGB.alphaComponent - startRGB.alphaComponent) * clampedRatio
        
        return NSColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    private func drawLineGraph(for host: HostData, in graphRect: NSRect, pointWidth: CGFloat) {
        guard host.pingHistory.count > 1 else { return }
        
        var previousPoint: NSPoint?
        
        for (index, ping) in host.pingHistory.enumerated() {
            let x = graphRect.minX + CGFloat(index) * pointWidth
            var y: CGFloat
            
            if ping > 0 {
                // Convert ping time to logarithmic scale for better visualization
                let logValue = Foundation.log10(Double(ping) + 1.0)
                let maxLogValue = Foundation.log10(201.0) // log10(200 + 1) for max scale
                let normalizedHeight = CGFloat(logValue / maxLogValue)
                y = graphRect.minY + normalizedHeight * graphRect.height
            } else {
                // For failed pings (0), draw at the bottom of the graph
                y = graphRect.minY
            }
            
            let currentPoint = NSPoint(x: x, y: y)
            
            if let prevPoint = previousPoint {
                // Draw line segment with color based on current ping value
                let path = NSBezierPath()
                path.move(to: prevPoint)
                path.line(to: currentPoint)
                
                // Set color based on ping value
                colorForPing(ping).setStroke()
                path.lineWidth = 1.5
                path.stroke()
            }
            
            previousPoint = currentPoint
        }
    }
}
