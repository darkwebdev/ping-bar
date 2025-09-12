//
//  PingGraphView.swift
//  PingBar
//
//  Created by Manyanov, Timur on 12.09.25.
//
import Cocoa

class PingGraphView: NSView {
    var pingData: [Int] = []
    var currentPing: Int = 0
    weak var appDelegate: AppDelegate? // Keep reference for potential future use
    
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
        
        guard !pingData.isEmpty && graphRect.width > 0 else { return }
        
        let barWidth: CGFloat = 1.0
        let barCount = Int(graphRect.width / barWidth)
        let maxPing: CGFloat = 200 // Fixed maximum height at 200ms
        
        // Draw bars from most recent data
        let startIndex = max(0, pingData.count - barCount)
        let relevantData = Array(pingData[startIndex...])
        
        for (index, ping) in relevantData.enumerated() {
            let x = graphRect.minX + CGFloat(index) * barWidth
            // Cap the ping value at 200ms for height calculation
            let cappedPing = min(CGFloat(ping), maxPing)
            let barHeight = ping == 0 ? graphRect.height : (cappedPing / maxPing) * graphRect.height
            let y = graphRect.minY
            
            let barRect = NSRect(
                x: x,
                y: y,
                width: barWidth,
                height: barHeight
            )
            
            // Color based on ping value
            let barColor: NSColor
            if ping == 0 { // No response
                barColor = .systemRed
            } else if ping <= 100 {
                barColor = .systemGreen
            } else {
                barColor = .systemYellow
            }
            
            barColor.setFill()
            NSBezierPath(rect: barRect).fill()
        }
    }
}
