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
    
    private func drawLineGraph(for host: HostData, in graphRect: NSRect, pointWidth: CGFloat) {
        guard host.pingHistory.count > 1 else { return }
        
        let path = NSBezierPath()
        var hasValidPoints = false
        
        for (index, ping) in host.pingHistory.enumerated() {
            let x = graphRect.minX + CGFloat(index) * pointWidth
            var y: CGFloat
            
            if ping > 0 {
                // Convert ping time to logarithmic scale for better visualization
                let logValue = Foundation.log10(Double(ping) + 1.0)
                let maxLogValue = Foundation.log10(201.0) // log10(200 + 1) for max scale
                let normalizedHeight = CGFloat(logValue / maxLogValue)
                y = graphRect.minY + normalizedHeight * graphRect.height
                
                if !hasValidPoints {
                    path.move(to: NSPoint(x: x, y: y))
                    hasValidPoints = true
                } else {
                    path.line(to: NSPoint(x: x, y: y))
                }
            } else {
                // For failed pings (0), draw at the bottom of the graph
                y = graphRect.minY
                
                if !hasValidPoints {
                    path.move(to: NSPoint(x: x, y: y))
                    hasValidPoints = true
                } else {
                    path.line(to: NSPoint(x: x, y: y))
                }
            }
        }
        
        if hasValidPoints {
            // Set the line color based on host color
            host.color.setStroke()
            path.lineWidth = 1.5
            path.stroke()
        }
    }
}
