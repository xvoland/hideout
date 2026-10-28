//
//  TrayPanelChrome.swift
//  Hideout
//
//  Created by Vitalii Tereshchuk (xVoLAnD), 2026
//  Copyright © 2019 Dwarves Foundation. All rights reserved.
//

import AppKit

/// A rounded surface that groups related settings rows.
///
/// Cards use semantic colors with low alpha so they sit on the popover's
/// material in both Light and Dark Mode without a hardcoded background.
class PanelCardView: NSView {

    var cornerRadius: CGFloat = 12 {
        didSet { needsDisplay = true }
    }

    var fillColor: NSColor = NSColor.labelColor.withAlphaComponent(0.05) {
        didSet { needsDisplay = true }
    }

    /// `nil` draws no outline.
    var borderColor: NSColor? = NSColor.separatorColor.withAlphaComponent(0.38) {
        didSet { needsDisplay = true }
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        guard rect.width > 0, rect.height > 0 else { return }

        let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        fillColor.setFill()
        path.fill()

        if let borderColor = borderColor {
            borderColor.setStroke()
            path.lineWidth = 1
            path.stroke()
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

/// A vertical hairline used inside cards and between preview zones.
final class VerticalHairlineView: NSView {

    override func draw(_ dirtyRect: NSRect) {
        NSColor.separatorColor.setFill()
        let line = NSRect(x: bounds.midX, y: bounds.minY + 1, width: 1, height: max(0, bounds.height - 2))
        NSBezierPath(rect: line).fill()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

/// A compact key-cap showing the recorded global shortcut.
///
/// It is a plain view rather than a text field so the border, background and
/// recording state stay consistent with the panel's surfaces.
final class ShortcutChipView: NSView {

    private let label = NSTextField(labelWithString: "")
    private var isRecording = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1

        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 9),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -9),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(equalToConstant: 22),
            widthAnchor.constraint(greaterThanOrEqualToConstant: 54)
        ])

        applyColors()
    }

    var title: String {
        get { label.stringValue }
        set {
            label.stringValue = newValue
            invalidateIntrinsicContentSize()
        }
    }

    var recording: Bool {
        get { isRecording }
        set {
            isRecording = newValue
            applyColors()
        }
    }

    private func applyColors() {
        // Layer colors are CGColors, so resolve them in this view's appearance
        // instead of whatever appearance happens to be current.
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let background = isRecording
                ? NSColor.controlAccentColor.withAlphaComponent(0.14)
                : NSColor.labelColor.withAlphaComponent(0.06)
            let border = isRecording
                ? NSColor.controlAccentColor.withAlphaComponent(0.7)
                : NSColor.separatorColor

            layer?.backgroundColor = background.cgColor
            layer?.borderColor = border.cgColor
        }
        label.textColor = isRecording ? .controlAccentColor : .labelColor
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: label.intrinsicContentSize.width + 18, height: 22)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyColors()
    }
}

/// A borderless text button that behaves like a link, including the
/// pointing-hand cursor that AppKit does not add to plain buttons.
final class LinkButton: NSButton {

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }
}
