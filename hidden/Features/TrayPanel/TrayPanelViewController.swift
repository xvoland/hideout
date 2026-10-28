//
//  TrayPanelViewController.swift
//  Hideout
//
//  Created by Vitalii Tereshchuk (xVoLAnD), 2026
//  Copyright © 2019 Dwarves Foundation. All rights reserved.
//

import AppKit
import HotKey

/// The compact "control centre" shown in the tray panel.
///
/// It carries every setting the Preferences window used to hold, plus the
/// menu-bar illustration and the fork's attribution. The layout is built in
/// code (no storyboard scene) so it can live in a resizable popover.
final class TrayPanelViewController: NSViewController {

    // MARK: - Callbacks and sizing

    /// Asks the popover owner to close the panel (Escape, Quit, Updates…).
    var onRequestClose: (() -> Void)?
    /// Reports a new height; `commit` is true when the drag ended.
    var onResize: ((CGFloat, Bool) -> Void)?
    /// Turns the popover animation off while the grip is being dragged.
    var onSetAnimates: ((Bool) -> Void)?

    var heightLimit: CGFloat = 0

    private(set) var currentHeight: CGFloat = 680
    private let minimumPanelHeight: CGFloat = 460

    // MARK: - Views

    private let scrollView = NSScrollView()
    private let document = FlippedView()
    private let preview = TrayPanelPreview()
    private let statusLabel = NSTextField(labelWithString: "")

    /// Last section added to the document; used to stack the next one below.
    private weak var lastSection: NSView?

    private var loginSwitch: NSSwitch!
    private var showOnLaunchSwitch: NSSwitch!
    private var autoHideSwitch: NSSwitch!
    private var alwaysHiddenSwitch: NSSwitch!
    private var keepSystemSwitch: NSSwitch!
    private var fullMenuBarSwitch: NSSwitch!

    private var delayLabel: NSTextField!
    private var delayPopup: NSPopUpButton!
    private var engineNote: NSTextField!

    private var shortcutChip: ShortcutChipView!
    private var changeButton: NSButton!
    private var clearButton: NSButton!

    // MARK: - Shortcut recording

    private var isListening = false
    private var listeningMonitor: Any?
    private var escapeMonitor: Any?

    // MARK: - Inline help

    private var helpRow: NSStackView!
    private var helpRowHeight: NSLayoutConstraint?

    // MARK: - Life cycle

    override func loadView() {
        // The popover supplies its own material; a clear root lets that show
        // through instead of stacking a second vibrancy layer on top.
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildInterface()
        populateContent()
        refreshControls()

        NotificationCenter.default.addObserver(self, selector: #selector(refreshControls), name: .prefsChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refreshControls), name: .alwayHideToggle, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateStatus), name: .menuBarStateChanged, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        refreshControls()
    }

    // MARK: - Presentation

    func prepareForPresentation() {
        _ = view
        installEscapeMonitor()
        refreshControls()
        view.layoutSubtreeIfNeeded()
    }

    func setCurrentHeight(_ height: CGFloat) {
        currentHeight = height
    }

    func panelDidClose() {
        endShortcutRecording(restoreTitle: true)
        removeEscapeMonitor()
    }

    // MARK: - Layout

    private func buildInterface() {
        let header = makeHeader()
        let footer = makeFooter()

        let grip = TrayPanelGripView()
        grip.translatesAutoresizingMaskIntoConstraints = false
        grip.toolTip = "Drag to resize the panel".localized
        grip.setAccessibilityLabel("Resize the panel".localized)
        grip.onDrag = { [weak self] delta, commit in
            self?.gripChanged(delta: delta, commit: commit)
        }

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        document.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = document

        view.addSubview(header)
        view.addSubview(scrollView)
        view.addSubview(footer)
        view.addSubview(grip)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),

            footer.topAnchor.constraint(equalTo: scrollView.bottomAnchor),
            footer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            grip.topAnchor.constraint(equalTo: footer.bottomAnchor),
            grip.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            grip.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            grip.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            grip.heightAnchor.constraint(equalToConstant: 10),

            document.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            document.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            document.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            document.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor)
        ])
    }

    private func makeHeader() -> NSView {
        let logo = NSImageView()
        logo.identifier = NSUserInterfaceItemIdentifier("ic_logo")
        logo.image = NSImage(named: NSImage.Name("ic_logo"))
        logo.imageScaling = .scaleProportionallyUpOrDown
        logo.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            logo.widthAnchor.constraint(equalToConstant: 40),
            logo.heightAnchor.constraint(equalToConstant: 40)
        ])

        let title = NSTextField(labelWithString: Constant.appName)
        title.font = .systemFont(ofSize: 20, weight: .semibold)
        title.textColor = .labelColor

        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail

        let titles = NSStackView(views: [title, statusLabel])
        titles.orientation = .vertical
        titles.alignment = .leading
        titles.spacing = 1
        titles.translatesAutoresizingMaskIntoConstraints = false

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let row = NSStackView(views: [logo, titles, spacer])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 11
        row.translatesAutoresizingMaskIntoConstraints = false
        return row
    }

    private func makeFooter() -> NSView {
        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false

        let updates = NSButton(title: "Check for Updates…".localized,
                               target: self,
                               action: #selector(checkUpdatesPressed))
        updates.bezelStyle = .rounded
        updates.controlSize = .small

        let quit = NSButton(title: "Quit".localized, target: self, action: #selector(quitPressed))
        quit.bezelStyle = .rounded
        quit.controlSize = .small

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let row = NSStackView(views: [updates, spacer, quit])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(divider)
        container.addSubview(row)

        NSLayoutConstraint.activate([
            divider.topAnchor.constraint(equalTo: container.topAnchor),
            divider.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1),

            row.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 10),
            row.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            row.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            row.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8)
        ])

        return container
    }

    // MARK: - Content

    private func populateContent() {
        addSection("General".localized, views: [generalCard()])
        addSection("Hiding Behavior".localized,
                   views: [hidingCard(), engineNoteLabel()])
        addSection("Keyboard Shortcut".localized, views: [shortcutCard()])
        addSection("Menu Bar Preview".localized,
                   accessory: textButton("Show All Icons".localized,
                                         action: #selector(arrangePressed),
                                         tooltip: "Show All Icons for Arranging".localized),
                   views: [preview])
        addSection("About".localized, views: [aboutCard()])
        finishContentLayout()
    }

    private func addSection(_ title: String, accessory: NSView? = nil, views: [NSView]) {
        let stack = NSStackView(views: [sectionHeader(title, accessory: accessory)] + views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        // `.width` alignment does not reliably stretch every arranged view
        // (cards with content-driven width stayed narrow), so pin each child
        // to the section's width explicitly.
        for view in stack.arrangedSubviews {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        document.addSubview(stack)

        let top: NSLayoutConstraint
        if let lastSection = lastSection {
            top = stack.topAnchor.constraint(equalTo: lastSection.bottomAnchor, constant: 18)
        } else {
            top = stack.topAnchor.constraint(equalTo: document.topAnchor, constant: 2)
        }

        NSLayoutConstraint.activate([
            top,
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -20)
        ])
        lastSection = stack
    }

    /// Closes the document's height around the last section.
    private func finishContentLayout() {
        guard let lastSection = lastSection else { return }
        lastSection.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -16).isActive = true
    }

    private func generalCard() -> NSView {
        loginSwitch = toggle(action: #selector(loginChanged),
                             label: "Start Hideout when I log in".localized)
        showOnLaunchSwitch = toggle(action: #selector(showOnLaunchChanged),
                                    label: "Open the panel on launch".localized)

        let login = settingRow(title: "Start Hideout when I log in".localized,
                               control: loginSwitch)
        let launch = settingRow(title: "Open the panel on launch".localized,
                                control: showOnLaunchSwitch)

        return card([login, separator(), launch])
    }

    private func hidingCard() -> NSView {
        autoHideSwitch = toggle(action: #selector(autoHideChanged),
                                label: "Automatically hide icons".localized)
        autoHideSwitch.toolTip = "Hide menu bar icons automatically after a delay.".localized

        let autoHide = settingRow(
            title: "Automatically hide icons".localized,
            subtitle: "Hide selected menu bar icons after a period of inactivity.".localized,
            control: autoHideSwitch
        )

        delayLabel = NSTextField(labelWithString: "Hide after".localized)
        delayLabel.font = .systemFont(ofSize: 12)
        delayLabel.textColor = .secondaryLabelColor

        delayPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        delayPopup.addItems(withTitles: ["5 seconds".localized,
                                         "10 seconds".localized,
                                         "15 seconds".localized,
                                         "30 seconds".localized,
                                         "1 minute".localized])
        delayPopup.target = self
        delayPopup.action = #selector(delayChanged)
        delayPopup.controlSize = .small
        delayPopup.font = .systemFont(ofSize: 11)
        delayPopup.setAccessibilityLabel("Auto-hide delay".localized)

        let delaySpacer = NSView()
        delaySpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        delaySpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let delayRow = NSStackView(views: [delayLabel, delaySpacer, delayPopup])
        delayRow.orientation = .horizontal
        delayRow.alignment = .centerY
        delayRow.spacing = 8
        delayRow.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 9, right: 0)
        delayRow.translatesAutoresizingMaskIntoConstraints = false

        alwaysHiddenSwitch = toggle(action: #selector(alwaysHiddenChanged),
                                    label: "Always-hidden section".localized)
        alwaysHiddenSwitch.toolTip = "A second hidden zone whose icons stay hidden even when the bar is expanded.".localized

        let alwaysHidden = settingRow(
            title: "Always-hidden section".localized,
            subtitle: "Keep selected icons hidden from the regular menu bar.".localized,
            control: alwaysHiddenSwitch,
            accessory: helpButton()
        )

        helpRow = makeHelpRow()
        // A hidden row would still report its label's intrinsic height inside
        // the card's explicit layout, leaving an empty band; pin it to zero.
        helpRowHeight = helpRow.heightAnchor.constraint(equalToConstant: 0)
        helpRowHeight?.isActive = true

        keepSystemSwitch = toggle(action: #selector(keepSystemItemsChanged),
                                  label: "Keep system icons visible".localized)
        keepSystemSwitch.toolTip = "macOS system items stay visible when Hideout collapses the bar.".localized

        let keepSystem = settingRow(
            title: "Keep system icons visible".localized,
            subtitle: "Prevent macOS system menu bar items from being hidden.".localized,
            control: keepSystemSwitch
        )

        fullMenuBarSwitch = toggle(action: #selector(fullMenuBarChanged),
                                   label: "Use the full menu bar when expanding".localized)
        fullMenuBarSwitch.toolTip = "Activate Hideout like a regular app while the menu bar is expanded.".localized

        let fullMenuBar = settingRow(
            title: "Use the full menu bar when expanding".localized,
            subtitle: "Activate Hideout like a regular app while the menu bar is expanded.".localized,
            control: fullMenuBarSwitch
        )

        return card([autoHide, delayRow, separator(), alwaysHidden, helpRow,
                     separator(), keepSystem, separator(), fullMenuBar])
    }

    private func makeHelpRow() -> NSStackView {
        let label = NSTextField(wrappingLabelWithString: "Tutorial text".localized)
        label.font = .systemFont(ofSize: 11)
        label.textColor = .labelColor
        label.maximumNumberOfLines = 0
        label.preferredMaxLayoutWidth = 296

        let row = NSStackView(views: [label])
        row.orientation = .vertical
        row.alignment = .leading
        row.edgeInsets = NSEdgeInsets(top: 2, left: 0, bottom: 10, right: 0)
        row.translatesAutoresizingMaskIntoConstraints = false
        row.isHidden = true
        return row
    }

    private func engineNoteLabel() -> NSView {
        engineNote = NSTextField(wrappingLabelWithString: "")
        engineNote.font = .systemFont(ofSize: 10)
        engineNote.textColor = .tertiaryLabelColor
        engineNote.maximumNumberOfLines = 2
        engineNote.preferredMaxLayoutWidth = 320

        let row = NSStackView(views: [engineNote])
        row.orientation = .horizontal
        row.alignment = .top
        row.edgeInsets = NSEdgeInsets(top: -2, left: 12, bottom: 0, right: 12)
        row.translatesAutoresizingMaskIntoConstraints = false
        return row
    }

    private func shortcutCard() -> NSView {
        let title = NSTextField(labelWithString: "Toggle Hideout".localized)
        title.font = .systemFont(ofSize: 13)
        title.textColor = .labelColor

        shortcutChip = ShortcutChipView()
        shortcutChip.translatesAutoresizingMaskIntoConstraints = false
        shortcutChip.setAccessibilityRole(.staticText)

        changeButton = NSButton(title: "Set Shortcut".localized,
                                target: self,
                                action: #selector(shortcutButtonPressed))
        changeButton.bezelStyle = .rounded
        changeButton.controlSize = .small
        changeButton.toolTip = "Click the button, then press the keys.".localized

        let clearImage = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: nil) ?? NSImage()
        clearButton = NSButton(image: clearImage, target: self, action: #selector(clearShortcut))
        clearButton.isBordered = false
        clearButton.bezelStyle = .inline
        clearButton.imagePosition = .imageOnly
        clearButton.contentTintColor = .tertiaryLabelColor
        clearButton.toolTip = "Clear Shortcut".localized
        clearButton.setAccessibilityLabel("Clear Shortcut".localized)
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            clearButton.widthAnchor.constraint(equalToConstant: 18),
            clearButton.heightAnchor.constraint(equalToConstant: 18)
        ])

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let row = NSStackView(views: [title, spacer, shortcutChip, changeButton, clearButton])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 6
        row.edgeInsets = NSEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
        row.translatesAutoresizingMaskIntoConstraints = false

        return card([row])
    }

    private func aboutCard() -> NSView {
        let version = Bundle.main.releaseVersionNumber ?? "—"
        let build = Bundle.main.buildVersionNumber ?? "—"

        let versionLabel = NSTextField(labelWithString: "\("Version".localized) \(version) (\(build))")
        versionLabel.font = .systemFont(ofSize: 11)
        versionLabel.textColor = .secondaryLabelColor

        let links = NSStackView(views: [
            textButton("GitHub", action: #selector(openGitHub), tooltip: "https://github.com/xvoland/hidden"),
            textButton("Website".localized, action: #selector(openMaintainerSite), tooltip: "https://dotoca.net/hideout"),
            textButton("Contact".localized, action: #selector(openContact), tooltip: "adv@dotoca.net"),
            textButton("Upstream".localized, action: #selector(openUpstream), tooltip: "https://github.com/dwarvesf/hidden")
        ])
        links.orientation = .horizontal
        links.alignment = .centerY
        links.spacing = 14
        links.translatesAutoresizingMaskIntoConstraints = false

        let maintainer = HyperlinkTextField()
        maintainer.href = "https://dotoca.net/hideout"
        maintainer.stringValue = "© 2026, Vitalii Tereshchuk / xVoLAnD (https://dotoca.net)"
        maintainer.isEditable = false
        maintainer.isSelectable = false
        maintainer.isBordered = false
        maintainer.drawsBackground = false
        maintainer.font = .systemFont(ofSize: 10)
        maintainer.textColor = .secondaryLabelColor
        maintainer.lineBreakMode = .byTruncatingTail

        let copyright = NSTextField(labelWithString: "© 2019 Dwarves Foundation - MIT license")
        copyright.font = .systemFont(ofSize: 10)
        copyright.textColor = .tertiaryLabelColor

        let stack = NSStackView(views: [versionLabel, links, maintainer, copyright])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false

        return card([stack], insets: NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))
    }

    // MARK: - View helpers

    private func sectionHeader(_ title: String, accessory: NSView? = nil) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .secondaryLabelColor

        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false
        row.addArrangedSubview(label)

        if let accessory = accessory {
            let spacer = NSView()
            spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
            spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            row.addArrangedSubview(spacer)
            row.addArrangedSubview(accessory)
        }

        return row
    }

    /// Groups rows on a single card surface. Rows draw their own separators;
    /// each one is pinned to the card so its controls line up at the edges.
    private func card(_ rows: [NSView], insets: NSEdgeInsets = NSEdgeInsets(top: 2, left: 12, bottom: 2, right: 12)) -> NSView {
        let card = PanelCardView()
        var previous: NSView?

        for row in rows {
            row.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(row)

            let top = previous.map {
                row.topAnchor.constraint(equalTo: $0.bottomAnchor)
            } ?? row.topAnchor.constraint(equalTo: card.topAnchor, constant: insets.top)

            NSLayoutConstraint.activate([
                top,
                row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: insets.left),
                row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -insets.right)
            ])
            previous = row
        }

        previous?.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -insets.bottom).isActive = true
        return card
    }

    private func settingRow(title: String,
                            subtitle: String? = nil,
                            control: NSView? = nil,
                            accessory: NSView? = nil) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.maximumNumberOfLines = 3
        titleLabel.preferredMaxLayoutWidth = 232

        let texts = NSStackView()
        texts.orientation = .vertical
        texts.alignment = .leading
        texts.spacing = 2
        texts.translatesAutoresizingMaskIntoConstraints = false
        texts.addArrangedSubview(titleLabel)

        if let subtitle = subtitle {
            let subtitleLabel = NSTextField(wrappingLabelWithString: subtitle)
            subtitleLabel.font = .systemFont(ofSize: 11)
            subtitleLabel.textColor = .secondaryLabelColor
            subtitleLabel.maximumNumberOfLines = 3
            subtitleLabel.preferredMaxLayoutWidth = 240
            texts.addArrangedSubview(subtitleLabel)
        }

        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 6
        row.edgeInsets = NSEdgeInsets(top: 9, left: 0, bottom: 9, right: 0)
        row.translatesAutoresizingMaskIntoConstraints = false
        row.addArrangedSubview(texts)

        if let accessory = accessory {
            row.addArrangedSubview(accessory)
        }

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(spacer)

        if let control = control {
            row.addArrangedSubview(control)
        }

        return row
    }

    private func separator() -> NSView {
        let box = NSBox()
        box.boxType = .separator
        box.translatesAutoresizingMaskIntoConstraints = false
        box.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return box
    }

    private func toggle(action: Selector, label: String) -> NSSwitch {
        let toggle = NSSwitch()
        toggle.target = self
        toggle.action = action
        toggle.setAccessibilityLabel(label)
        toggle.translatesAutoresizingMaskIntoConstraints = false
        return toggle
    }

    private func textButton(_ title: String, action: Selector, tooltip: String? = nil) -> NSButton {
        let button = LinkButton(title: title, target: self, action: action)
        button.isBordered = false
        button.bezelStyle = .inline
        button.font = .systemFont(ofSize: 11)
        button.contentTintColor = .controlAccentColor
        button.toolTip = tooltip
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }

    private func helpButton() -> NSButton {
        let image = NSImage(systemSymbolName: "questionmark.circle", accessibilityDescription: nil) ?? NSImage()
        let button = NSButton(image: image, target: self, action: #selector(showAlwaysHiddenHelp(_:)))
        button.isBordered = false
        button.bezelStyle = .inline
        button.imagePosition = .imageOnly
        button.contentTintColor = .labelColor
        button.toolTip = "How the always hidden section works".localized
        button.setAccessibilityLabel("How the always hidden section works".localized)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 16),
            button.heightAnchor.constraint(equalToConstant: 16)
        ])
        return button
    }

    // MARK: - Refresh

    @objc private func refreshControls() {
        guard isViewLoaded else { return }

        loginSwitch.state = Preferences.isAutoStart ? .on : .off
        showOnLaunchSwitch.state = Preferences.isShowPreference ? .on : .off
        autoHideSwitch.state = Preferences.isAutoHide ? .on : .off
        alwaysHiddenSwitch.state = Preferences.alwaysHiddenSectionEnabled ? .on : .off
        keepSystemSwitch.state = Preferences.keepSystemItemsVisible ? .on : .off
        fullMenuBarSwitch.state = Preferences.useFullStatusBarOnExpandEnabled ? .on : .off

        delayPopup.selectItem(at: SelectedSecond.secondToPossition(seconds: Preferences.numberOfSecondForAutoHide))
        updateDelayAvailability()

        preview.refresh(alwaysHidden: Preferences.alwaysHiddenSectionEnabled)
        updateEngineNote()
        updateShortcut()
        updateStatus()
    }

    private func updateDelayAvailability() {
        let enabled = Preferences.isAutoHide
        delayPopup.isEnabled = enabled
        delayLabel.textColor = enabled ? .secondaryLabelColor : .tertiaryLabelColor
    }

    private func updateEngineNote() {
        if NativeVisibilityEngine.nativeVisibilityAvailable {
            engineNote.stringValue = "Hiding: native hiding (macOS 27 direct build).".localized
        } else {
            engineNote.stringValue = "Hiding unavailable: needs the direct (non-sandboxed) build on macOS 27.".localized
        }
    }

    @objc private func updateStatus() {
        guard isViewLoaded else { return }
        let controller = (NSApp.delegate as? AppDelegate)?.statusBarController
        statusLabel.stringValue = (controller?.isMenuBarCollapsed ?? false)
            ? "Menu bar hidden".localized
            : "Menu bar visible".localized
    }

    private func updateShortcut() {
        guard isViewLoaded, !isListening else { return }

        if let key = Preferences.globalKey, key.description.count > 1 {
            shortcutChip.title = key.description
            shortcutChip.recording = false
            let label = "Current shortcut".localized
            shortcutChip.setAccessibilityLabel("\(label): \(key.description)")
            clearButton.isEnabled = true
            clearButton.contentTintColor = .tertiaryLabelColor
        } else {
            shortcutChip.title = "Not set".localized
            shortcutChip.recording = false
            shortcutChip.setAccessibilityLabel("No shortcut set".localized)
            clearButton.isEnabled = false
            clearButton.contentTintColor = .quaternaryLabelColor
        }
    }

    // MARK: - Actions

    @objc private func loginChanged() {
        Preferences.isAutoStart = loginSwitch.state == .on
    }

    @objc private func showOnLaunchChanged() {
        Preferences.isShowPreference = showOnLaunchSwitch.state == .on
    }

    @objc private func autoHideChanged() {
        Preferences.isAutoHide = autoHideSwitch.state == .on
        updateDelayAvailability()
    }

    @objc private func alwaysHiddenChanged() {
        Preferences.alwaysHiddenSectionEnabled = alwaysHiddenSwitch.state == .on
        preview.refresh(alwaysHidden: Preferences.alwaysHiddenSectionEnabled)
    }

    @objc private func keepSystemItemsChanged() {
        Preferences.keepSystemItemsVisible = keepSystemSwitch.state == .on
    }

    @objc private func fullMenuBarChanged() {
        Preferences.useFullStatusBarOnExpandEnabled = fullMenuBarSwitch.state == .on
    }

    @objc private func delayChanged() {
        guard let seconds = SelectedSecond(rawValue: delayPopup.indexOfSelectedItem)?.toSeconds() else { return }
        Preferences.numberOfSecondForAutoHide = seconds
    }

    @objc private func arrangePressed() {
        NotificationCenter.default.post(name: .revealForArranging, object: nil)
    }

    @objc private func checkUpdatesPressed() {
        onRequestClose?()
        DispatchQueue.main.async {
            UpdateChecker.shared.checkNow()
        }
    }

    @objc private func quitPressed() {
        onRequestClose?()
        NSApp.terminate(nil)
    }

    @objc private func openGitHub() {
        open("https://github.com/xvoland/hidden")
    }

    @objc private func openMaintainerSite() {
        open("https://dotoca.net/hideout")
    }

    @objc private func openContact() {
        open("mailto:adv@dotoca.net")
    }

    @objc private func openUpstream() {
        open("https://github.com/dwarvesf/hidden")
    }

    private func open(_ string: String) {
        guard let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Shortcut recording

    @objc private func shortcutButtonPressed() {
        if isListening {
            endShortcutRecording(restoreTitle: true)
        } else {
            beginShortcutRecording()
        }
    }

    private func beginShortcutRecording() {
        guard listeningMonitor == nil else { return }

        isListening = true
        shortcutChip.recording = true
        shortcutChip.title = "Type a shortcut…".localized
        changeButton.title = "Cancel".localized
        clearButton.isEnabled = false

        listeningMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self = self else { return event }
            if event.type == .flagsChanged {
                self.updateModifierDisplay(event)
                return nil
            }
            if event.keyCode == 53 {
                self.endShortcutRecording(restoreTitle: true)
                return nil
            }
            self.capture(event)
            return nil
        }

        // The recorder owns Escape while listening; leaving the panel's own
        // Escape monitor installed could close the panel right after a cancel.
        removeEscapeMonitor()
        view.window?.makeFirstResponder(nil)
    }

    private func updateModifierDisplay(_ event: NSEvent) {
        let bind = GlobalKeybindPreferences(function: event.modifierFlags.contains(.function),
                                            control: event.modifierFlags.contains(.control),
                                            command: event.modifierFlags.contains(.command),
                                            shift: event.modifierFlags.contains(.shift),
                                            option: event.modifierFlags.contains(.option),
                                            capsLock: event.modifierFlags.contains(.capsLock),
                                            carbonFlags: 0,
                                            characters: nil,
                                            keyCode: UInt32(event.keyCode))
        shortcutChip.title = bind.description.isEmpty
            ? "Type a shortcut…".localized
            : bind.description
    }

    private func capture(_ event: NSEvent) {
        let bind = GlobalKeybindPreferences(function: event.modifierFlags.contains(.function),
                                            control: event.modifierFlags.contains(.control),
                                            command: event.modifierFlags.contains(.command),
                                            shift: event.modifierFlags.contains(.shift),
                                            option: event.modifierFlags.contains(.option),
                                            capsLock: event.modifierFlags.contains(.capsLock),
                                            carbonFlags: event.modifierFlags.carbonFlags,
                                            characters: event.charactersIgnoringModifiers,
                                            keyCode: UInt32(event.keyCode))
        Preferences.globalKey = bind

        let appDelegate = NSApp.delegate as? AppDelegate
        appDelegate?.hotKey = HotKey(keyCombo: KeyCombo(carbonKeyCode: UInt32(event.keyCode),
                                                       carbonModifiers: event.modifierFlags.carbonFlags))

        endShortcutRecording(restoreTitle: false)

        if bind.description.count <= 1 {
            clearShortcut()
        } else {
            shortcutChip.title = bind.description
            clearButton.isEnabled = true
        }
    }

    private func endShortcutRecording(restoreTitle: Bool) {
        if let monitor = listeningMonitor {
            NSEvent.removeMonitor(monitor)
            listeningMonitor = nil
        }
        isListening = false
        changeButton?.title = "Set Shortcut".localized
        shortcutChip?.recording = false
        if restoreTitle {
            updateShortcut()
        }
        installEscapeMonitor()
    }

    @objc private func clearShortcut() {
        Preferences.globalKey = nil
        (NSApp.delegate as? AppDelegate)?.hotKey = nil
        updateShortcut()
    }

    // MARK: - Help

    @objc private func showAlwaysHiddenHelp(_ sender: NSButton) {
        let show = helpRow.isHidden
        helpRow.isHidden = !show
        helpRowHeight?.isActive = !show
        sender.toolTip = (show
            ? "Hide the always hidden help"
            : "How the always hidden section works").localized
        view.layoutSubtreeIfNeeded()
    }

    // MARK: - Resize grip

    private var isResizing = false
    private var resizeStartHeight: CGFloat = 0

    private func gripChanged(delta: CGFloat, commit: Bool) {
        if commit {
            isResizing = false
            onSetAnimates?(true)
            onResize?(currentHeight, true)
            return
        }

        if !isResizing {
            isResizing = true
            resizeStartHeight = currentHeight
            onSetAnimates?(false)
        }

        let limit = heightLimit > 0 ? heightLimit : currentHeight
        let height = min(max(resizeStartHeight + delta, minimumPanelHeight), limit)
        guard height != currentHeight else { return }
        currentHeight = height
        onResize?(height, false)
    }

    // MARK: - Escape handling

    private func installEscapeMonitor() {
        guard escapeMonitor == nil else { return }
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            guard event.keyCode == 53, !self.isListening else { return event }
            self.onRequestClose?()
            return nil
        }
    }

    private func removeEscapeMonitor() {
        if let monitor = escapeMonitor {
            NSEvent.removeMonitor(monitor)
            escapeMonitor = nil
        }
    }
}

// MARK: - Flipped document

/// A scroll-view document that lays its content out from the top down.
private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}
