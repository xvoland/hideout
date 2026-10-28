//
//  TrayPanelPreview.swift
//  Hideout
//
//  Created by Vitalii Tereshchuk (xVoLAnD), 2026
//  Copyright © 2019 Dwarves Foundation. All rights reserved.
//

import AppKit

/// An illustrative menu bar strip.
///
/// The icons are the app's existing menu-bar assets, not live system state.
/// Zones are rendered as columns so each caption sits under its own group:
/// hidden, optional always-hidden, then visible.
final class TrayPanelPreview: PanelCardView {

    private let bar = NSStackView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        cornerRadius = 12
        fillColor = NSColor.labelColor.withAlphaComponent(0.05)
        borderColor = NSColor.separatorColor.withAlphaComponent(0.42)
        toolTip = "In your Mac's menu bar, hold ⌘ and drag icons between sections to configure Hideout.".localized
        setAccessibilityRole(.group)
        setAccessibilityLabel("Menu bar preview".localized)

        bar.orientation = .horizontal
        bar.alignment = .top
        bar.spacing = 10
        bar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bar)

        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            bar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            bar.centerXAnchor.constraint(equalTo: centerXAnchor),
            bar.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 14),
            bar.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -14)
        ])

        refresh(alwaysHidden: false)
    }

    /// Rebuilds the strip for the current always-hidden setting.
    func refresh(alwaysHidden: Bool) {
        bar.removeAllSubViews()

        let hidden = zone(icons: ["ico_1", "ico_2", "ico_3"], caption: "Hidden".localized)
        let visible = zone(icons: ["ico_collapse", "ico_7"], caption: "Visible".localized)

        if alwaysHidden {
            let always = zone(icons: ["ico_4", "ico_5", "ico_6"], caption: "Always Hidden".localized)
            bar.addArrangedSubview(hidden)
            bar.addArrangedSubview(divider())
            bar.addArrangedSubview(always)
            bar.addArrangedSubview(divider())
            bar.addArrangedSubview(visible)
        } else {
            bar.addArrangedSubview(hidden)
            bar.addArrangedSubview(divider())
            bar.addArrangedSubview(visible)
        }
    }

    private func zone(icons: [String], caption: String) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 5
        row.translatesAutoresizingMaskIntoConstraints = false

        for name in icons {
            let isArrow = name == "ico_collapse"
            row.addArrangedSubview(icon(named: name,
                                        width: isArrow ? 8 : 16,
                                        height: isArrow ? 14 : 16))
        }

        let label = NSTextField(labelWithString: caption)
        label.alignment = .center
        label.font = .systemFont(ofSize: 10)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byTruncatingTail

        let zone = NSStackView(views: [row, label])
        zone.orientation = .vertical
        zone.alignment = .width
        zone.spacing = 5
        zone.translatesAutoresizingMaskIntoConstraints = false
        return zone
    }

    private func divider() -> NSView {
        let line = VerticalHairlineView()
        line.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            line.widthAnchor.constraint(equalToConstant: 1),
            line.heightAnchor.constraint(equalToConstant: 16)
        ])
        let holder = NSView()
        holder.translatesAutoresizingMaskIntoConstraints = false
        holder.addSubview(line)
        NSLayoutConstraint.activate([
            line.topAnchor.constraint(equalTo: holder.topAnchor),
            line.bottomAnchor.constraint(equalTo: holder.bottomAnchor),
            line.centerXAnchor.constraint(equalTo: holder.centerXAnchor),
            holder.widthAnchor.constraint(equalToConstant: 1),
            holder.heightAnchor.constraint(equalToConstant: 16)
        ])
        return holder
    }

    private func icon(named name: String, width: CGFloat = 16, height: CGFloat = 16) -> NSImageView {
        let view = NSImageView()
        view.identifier = NSUserInterfaceItemIdentifier(name)
        view.image = NSImage(named: NSImage.Name(name))
        view.imageScaling = .scaleProportionallyDown
        view.contentTintColor = .secondaryLabelColor
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: width),
            view.heightAnchor.constraint(equalToConstant: height)
        ])
        return view
    }
}
