//
//  TrayPanelPreview.swift
//  Hideout
//
//  Created by Vitalii Tereshchuk (xVoLAnD), 2026
//  Copyright © 2019 Dwarves Foundation. All rights reserved.
//

import AppKit

/// The menu-bar illustration that used to live in the storyboard.
///
/// It is rebuilt in code because the panel replaces the Preferences window;
/// the icon strip and the section captions change when the always-hidden
/// section is toggled.
final class TrayPanelPreview: NSView {

    private let instruction = NSTextField(wrappingLabelWithString: "")
    private let strip = NSStackView()
    private let captions = NSStackView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        instruction.stringValue = "In your Mac's menu bar, hold ⌘ and drag icons between sections to configure Hideout.".localized
        instruction.alignment = .center
        instruction.font = .systemFont(ofSize: 11)
        instruction.textColor = .secondaryLabelColor
        instruction.maximumNumberOfLines = 0
        instruction.preferredMaxLayoutWidth = 288
        instruction.translatesAutoresizingMaskIntoConstraints = false

        strip.orientation = .horizontal
        strip.alignment = .centerY
        strip.spacing = 7
        strip.translatesAutoresizingMaskIntoConstraints = false

        captions.orientation = .horizontal
        captions.alignment = .centerY
        captions.distribution = .fillEqually
        captions.spacing = 4
        captions.translatesAutoresizingMaskIntoConstraints = false

        addSubview(instruction)
        addSubview(strip)
        addSubview(captions)

        NSLayoutConstraint.activate([
            instruction.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            instruction.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            instruction.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            strip.topAnchor.constraint(equalTo: instruction.bottomAnchor, constant: 8),
            strip.centerXAnchor.constraint(equalTo: centerXAnchor),

            captions.topAnchor.constraint(equalTo: strip.bottomAnchor, constant: 4),
            captions.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            captions.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            captions.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10)
        ])

        refresh(alwaysHidden: false)
    }

    /// Rebuilds the strip and the captions for the current setting.
    func refresh(alwaysHidden: Bool) {
        strip.removeAllSubViews()
        let names = alwaysHidden
            ? ["ico_1", "ico_2", "ico_3", "ico_4", "seprated_1", "ico_5", "ico_6", "seprated", "ico_collapse", "ico_7"]
            : ["ico_1", "ico_2", "ico_3", "seprated", "ico_collapse", "ico_4", "ico_5", "ico_6", "ico_7"]

        for name in names {
            switch name {
            case "seprated", "seprated_1":
                strip.addArrangedSubview(icon(named: name, width: 2, height: 16))
            case "ico_collapse":
                strip.addArrangedSubview(icon(named: name, width: 8, height: 14))
            default:
                strip.addArrangedSubview(icon(named: name))
            }
        }

        captions.removeAllSubViews()
        // Caption order mirrors the strip: hidden zone, optional always-hidden
        // zone, then the shown zone.
        let titles = alwaysHidden
            ? ["Hidden".localized, "⭐️ Always Hidden".localized, "Shown".localized]
            : ["Hidden".localized, "Shown".localized]
        for title in titles {
            let label = NSTextField(labelWithString: title)
            label.alignment = .center
            label.font = .systemFont(ofSize: 10)
            label.textColor = .secondaryLabelColor
            label.lineBreakMode = .byTruncatingTail
            captions.addArrangedSubview(label)
        }
    }

    private func icon(named name: String, width: CGFloat = 16, height: CGFloat = 16) -> NSImageView {
        let view = NSImageView()
        view.image = NSImage(named: NSImage.Name(name))
        view.imageScaling = .scaleProportionallyDown
        view.contentTintColor = .labelColor
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: width),
            view.heightAnchor.constraint(equalToConstant: height)
        ])
        return view
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.labelColor.withAlphaComponent(0.06).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 10, yRadius: 10).fill()
    }
}
