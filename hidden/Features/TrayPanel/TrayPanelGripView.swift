//
//  TrayPanelGripView.swift
//  Hideout
//
//  Created by Vitalii Tereshchuk (xVoLAnD), 2026
//  Copyright © 2019 Dwarves Foundation. All rights reserved.
//

import AppKit

/// The grip along the panel's bottom edge: dragging it changes the panel's
/// height, which the panel remembers for the next time it opens.
final class TrayPanelGripView: NSView {

    /// Called with the drag distance (positive = taller) and whether the drag
    /// ended and the height should be saved.
    var onDrag: ((CGFloat, Bool) -> Void)?

    private var dragStart: NSPoint?
    private var isHovered = false
    private var tracking: NSTrackingArea?

    override var acceptsFirstResponder: Bool { false }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeUpDown)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking = tracking {
            removeTrackingArea(tracking)
        }
        let area = NSTrackingArea(rect: bounds,
                                  options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
                                  owner: self,
                                  userInfo: nil)
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        dragStart = NSEvent.mouseLocation
        onDrag?(0, false)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart else { return }
        // AppKit's screen coordinates grow upwards, so dragging down (a
        // smaller y) makes the panel taller.
        onDrag?(start.y - NSEvent.mouseLocation.y, false)
    }

    override func mouseUp(with event: NSEvent) {
        guard dragStart != nil else { return }
        dragStart = nil
        onDrag?(0, true)
    }

    override func draw(_ dirtyRect: NSRect) {
        let width: CGFloat = 36
        let height: CGFloat = 4
        let rect = NSRect(x: (bounds.width - width) / 2,
                          y: (bounds.height - height) / 2,
                          width: width,
                          height: height)
        let alpha: CGFloat = (isHovered || dragStart != nil) ? 0.8 : 0.35
        NSColor.secondaryLabelColor.withAlphaComponent(alpha).setFill()
        NSBezierPath(roundedRect: rect, xRadius: height / 2, yRadius: height / 2).fill()
    }
}
