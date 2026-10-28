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

    private(set) var currentHeight: CGFloat = 600
    private let minimumPanelHeight: CGFloat = 380

    // MARK: - Views

    private let scrollView = NSScrollView()
    private let contentStack = NSStackView()
    private let preview = TrayPanelPreview()
    private let statusLabel = NSTextField(labelWithString: "")

    private var loginCheck: NSButton!
    private var showOnLaunchCheck: NSButton!
    private var fullStatusBarCheck: NSButton!
    private var alwaysHiddenCheck: NSButton!
    private var keepSystemItemsCheck: NSButton!
    private var autoHideCheck: NSButton!
    private var delayPopup: NSPopUpButton!
    private var engineNote: NSTextField!
    private var shortcutButton: NSButton!
    private var clearButton: NSButton!
    private var versionLabel: NSTextField!

    // MARK: - Shortcut recording

    private var isListening = false
    private var listeningMonitor: Any?
    private var escapeMonitor: Any?

    // MARK: - Inline help

    private var helpRow: NSStackView!

    // MARK: - Life cycle

    override func loadView() {
        let root = NSVisualEffectView()
        root.material = .popover
        root.blendingMode = .behindWindow
        root.state = .followsWindowActiveState
        view = root
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

    override func cancelOperation(_ sender: Any?) {
        onRequestClose?()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onRequestClose?()
        } else {
            super.keyDown(with: event)
        }
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
        grip.onDrag = { [weak self] delta, commit in
            self?.gripChanged(delta: delta, commit: commit)
        }

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        contentStack.orientation = .vertical
        contentStack.alignment = .width
        contentStack.spacing = 9
        contentStack.edgeInsets = NSEdgeInsets(top: 2, left: 14, bottom: 12, right: 14)
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        let document = FlippedView()
        document.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(contentStack)
        scrollView.documentView = document

        view.addSubview(header)
        view.addSubview(scrollView)
        view.addSubview(footer)
        view.addSubview(grip)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),

            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 8),
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

            contentStack.topAnchor.constraint(equalTo: document.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: document.bottomAnchor),

            document.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            document.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            document.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            document.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor)
        ])
    }

    private func makeHeader() -> NSView {
        let logo = NSImageView()
        logo.image = NSImage(named: NSImage.Name("ic_logo"))
        logo.imageScaling = .scaleProportionallyUpOrDown
        logo.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            logo.widthAnchor.constraint(equalToConstant: 30),
            logo.heightAnchor.constraint(equalToConstant: 30)
        ])

        let title = NSTextField(labelWithString: Constant.appName)
        title.font = .systemFont(ofSize: 15, weight: .semibold)

        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail

        let titles = NSStackView(views: [title, statusLabel])
        titles.orientation = .vertical
        titles.alignment = .leading
        titles.spacing = 1
        titles.translatesAutoresizingMaskIntoConstraints = false
        titles.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let row = NSStackView(views: [logo, titles])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 9
        row.translatesAutoresizingMaskIntoConstraints = false
        return row
    }

    private func makeFooter() -> NSView {
        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false

        let arrange = NSButton(title: "Show All Icons".localized,
                               target: self,
                               action: #selector(arrangePressed))
        arrange.bezelStyle = .rounded
        arrange.controlSize = .small
        arrange.toolTip = "Show All Icons for Arranging".localized

        let updates = NSButton(title: "Check for Updates…".localized,
                               target: self,
                               action: #selector(checkUpdatesPressed))
        updates.bezelStyle = .rounded
        updates.controlSize = .small

        let topRow = NSStackView(views: [arrange, updates])
        topRow.orientation = .horizontal
        topRow.alignment = .centerY
        topRow.spacing = 8
        topRow.distribution = .fillEqually
        topRow.translatesAutoresizingMaskIntoConstraints = false

        let github = NSButton(title: "GitHub", target: self, action: #selector(openGitHub))
        github.bezelStyle = .inline
        github.controlSize = .small

        let site = NSButton(title: "dotoca.net", target: self, action: #selector(openMaintainerSite))
        site.bezelStyle = .inline
        site.controlSize = .small

        let quit = NSButton(title: "Quit".localized, target: self, action: #selector(quitPressed))
        quit.bezelStyle = .rounded
        quit.controlSize = .small

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let bottomRow = NSStackView(views: [github, site, spacer, quit])
        bottomRow.orientation = .horizontal
        bottomRow.alignment = .centerY
        bottomRow.spacing = 8
        bottomRow.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(divider)
        container.addSubview(topRow)
        container.addSubview(bottomRow)

        NSLayoutConstraint.activate([
            divider.topAnchor.constraint(equalTo: container.topAnchor),
            divider.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1),

            topRow.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 10),
            topRow.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            topRow.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),

            bottomRow.topAnchor.constraint(equalTo: topRow.bottomAnchor, constant: 8),
            bottomRow.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            bottomRow.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            bottomRow.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10)
        ])

        return container
    }

    // MARK: - Content

    private func populateContent() {
        contentStack.addArrangedSubview(sectionTitle("Settings".localized))

        loginCheck = checkbox("Start Hideout when I log in".localized, action: #selector(loginChanged))
        contentStack.addArrangedSubview(loginCheck)

        showOnLaunchCheck = checkbox("Open the panel on launch".localized, action: #selector(showOnLaunchChanged))
        contentStack.addArrangedSubview(showOnLaunchCheck)

        fullStatusBarCheck = checkbox("Use the full MenuBar on expanding".localized, action: #selector(fullStatusBarChanged))
        contentStack.addArrangedSubview(fullStatusBarCheck)

        alwaysHiddenCheck = checkbox("Enable always hidden section".localized, action: #selector(alwaysHiddenChanged))
        contentStack.addArrangedSubview(row(alwaysHiddenCheck, helpButton()))

        // Inline instead of a nested popover: the panel itself is transient, so
        // a popover anchored inside it would be dismissed by the same click
        // that should open it.
        let helpLabel = NSTextField(wrappingLabelWithString: "Tutorial text".localized)
        helpLabel.font = .systemFont(ofSize: 10)
        helpLabel.textColor = .secondaryLabelColor
        helpLabel.maximumNumberOfLines = 0
        helpLabel.preferredMaxLayoutWidth = 294
        helpRow = NSStackView(views: [helpLabel])
        helpRow.orientation = .vertical
        helpRow.alignment = .leading
        helpRow.edgeInsets = NSEdgeInsets(top: 0, left: 18, bottom: 0, right: 0)
        helpRow.translatesAutoresizingMaskIntoConstraints = false
        helpRow.isHidden = true
        contentStack.addArrangedSubview(helpRow)

        autoHideCheck = checkbox("Automatically hide icon(s) after:".localized, action: #selector(autoHideChanged))
        contentStack.addArrangedSubview(autoHideCheck)

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
        let delayRow = NSStackView(views: [delayPopup])
        delayRow.orientation = .horizontal
        delayRow.alignment = .centerY
        delayRow.edgeInsets = NSEdgeInsets(top: 0, left: 18, bottom: 0, right: 0)
        delayRow.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(delayRow)

        keepSystemItemsCheck = checkbox("Always keep system menu-bar items visible".localized, action: #selector(keepSystemItemsChanged))
        contentStack.addArrangedSubview(keepSystemItemsCheck)

        engineNote = NSTextField(wrappingLabelWithString: "")
        engineNote.font = .systemFont(ofSize: 10)
        engineNote.textColor = .secondaryLabelColor
        engineNote.maximumNumberOfLines = 3
        engineNote.preferredMaxLayoutWidth = 312
        contentStack.addArrangedSubview(engineNote)

        contentStack.addArrangedSubview(sectionTitle("Global Shortcut".localized))

        shortcutButton = NSButton(title: "Set Shortcut".localized,
                                  target: self,
                                  action: #selector(beginShortcutRecording))
        shortcutButton.bezelStyle = .rounded
        shortcutButton.setContentHuggingPriority(.defaultLow, for: .horizontal)

        clearButton = NSButton(title: "⌫", target: self, action: #selector(clearShortcut))
        clearButton.bezelStyle = .rounded
        clearButton.toolTip = "Clear Shortcut".localized
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.widthAnchor.constraint(equalToConstant: 38).isActive = true

        let shortcutRow = NSStackView(views: [shortcutButton, clearButton])
        shortcutRow.orientation = .horizontal
        shortcutRow.alignment = .centerY
        shortcutRow.spacing = 6
        shortcutRow.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(shortcutRow)

        let hint = NSTextField(wrappingLabelWithString: "Click the button, then press the keys.".localized)
        hint.font = .systemFont(ofSize: 10)
        hint.textColor = .tertiaryLabelColor
        hint.maximumNumberOfLines = 2
        hint.preferredMaxLayoutWidth = 312
        contentStack.addArrangedSubview(hint)

        contentStack.addArrangedSubview(sectionTitle("Menu bar".localized))
        contentStack.addArrangedSubview(preview)

        addAboutSection()
    }

    private func addAboutSection() {
        contentStack.addArrangedSubview(sectionTitle("About".localized))

        let version = Bundle.main.releaseVersionNumber ?? "—"
        let build = Bundle.main.buildVersionNumber ?? "—"
        versionLabel = NSTextField(labelWithString: "\(Constant.appName) \(version) (\(build))")
        versionLabel.font = .systemFont(ofSize: 11)
        versionLabel.textColor = .secondaryLabelColor
        contentStack.addArrangedSubview(versionLabel)

        contentStack.addArrangedSubview(linkRow(icon: "ico_compass",
                                                title: "Maintained by Vitalii Tereshchuk (xVoLAnD)".localized,
                                                href: "https://dotoca.net/"))
        contentStack.addArrangedSubview(linkRow(icon: "ico_github",
                                                title: "This fork is fully open source".localized,
                                                href: "https://github.com/xvoland/hidden"))
        contentStack.addArrangedSubview(linkRow(icon: "ico_twitter",
                                                title: "Upstream project".localized,
                                                href: "https://github.com/dwarvesf/hidden"))
        contentStack.addArrangedSubview(linkRow(icon: "ico_email",
                                                title: "Contact the maintainer".localized,
                                                href: "mailto:adv@dotoca.net"))

        let copyright = NSTextField(wrappingLabelWithString: "Copyright © 2019 Dwarves Foundation. All rights reserved. MIT licensed.")
        copyright.font = .systemFont(ofSize: 10)
        copyright.textColor = .tertiaryLabelColor
        copyright.maximumNumberOfLines = 2
        copyright.preferredMaxLayoutWidth = 312
        contentStack.addArrangedSubview(copyright)
    }

    // MARK: - View helpers

    private func sectionTitle(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title.uppercased())
        label.font = .systemFont(ofSize: 10, weight: .semibold)
        label.textColor = .tertiaryLabelColor
        return label
    }

    private func checkbox(_ title: String, action: Selector) -> NSButton {
        let button = NSButton(checkboxWithTitle: title, target: self, action: action)
        button.font = .systemFont(ofSize: 13)
        return button
    }

    private func row(_ first: NSView, _ second: NSView) -> NSStackView {
        let stack = NSStackView(views: [first, second])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    private func helpButton() -> NSButton {
        let image = NSImage(systemSymbolName: "questionmark.circle", accessibilityDescription: nil) ?? NSImage()
        let button = NSButton(image: image, target: self, action: #selector(showAlwaysHiddenHelp(_:)))
        button.isBordered = false
        button.bezelStyle = .inline
        button.imagePosition = .imageOnly
        button.contentTintColor = .secondaryLabelColor
        button.toolTip = "How the always hidden section works".localized
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 18),
            button.heightAnchor.constraint(equalToConstant: 18)
        ])
        return button
    }

    private func linkRow(icon: String, title: String, href: String) -> NSView {
        let imageView = NSImageView()
        imageView.image = NSImage(named: NSImage.Name(icon))
        imageView.imageScaling = .scaleProportionallyDown
        imageView.contentTintColor = .secondaryLabelColor
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 14),
            imageView.heightAnchor.constraint(equalToConstant: 14)
        ])

        let link = HyperlinkTextField()
        link.href = href
        link.stringValue = title
        link.isEditable = false
        link.isSelectable = false
        link.isBordered = false
        link.drawsBackground = false
        link.font = .systemFont(ofSize: 11)
        link.textColor = .linkColor
        link.lineBreakMode = .byTruncatingTail
        link.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let stack = NSStackView(views: [imageView, link])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    // MARK: - Refresh

    @objc private func refreshControls() {
        guard isViewLoaded else { return }

        loginCheck.state = Preferences.isAutoStart ? .on : .off
        showOnLaunchCheck.state = Preferences.isShowPreference ? .on : .off
        fullStatusBarCheck.state = Preferences.useFullStatusBarOnExpandEnabled ? .on : .off
        alwaysHiddenCheck.state = Preferences.alwaysHiddenSectionEnabled ? .on : .off
        keepSystemItemsCheck.state = Preferences.keepSystemItemsVisible ? .on : .off
        autoHideCheck.state = Preferences.isAutoHide ? .on : .off

        delayPopup.selectItem(at: SelectedSecond.secondToPossition(seconds: Preferences.numberOfSecondForAutoHide))
        delayPopup.isEnabled = Preferences.isAutoHide

        preview.refresh(alwaysHidden: Preferences.alwaysHiddenSectionEnabled)
        updateEngineNote()
        updateShortcut()
        updateStatus()
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
            shortcutButton.title = key.description
            clearButton.isEnabled = true
        } else {
            shortcutButton.title = "Set Shortcut".localized
            clearButton.isEnabled = false
        }
    }

    // MARK: - Actions

    @objc private func loginChanged() {
        Preferences.isAutoStart = loginCheck.state == .on
    }

    @objc private func showOnLaunchChanged() {
        Preferences.isShowPreference = showOnLaunchCheck.state == .on
    }

    @objc private func fullStatusBarChanged() {
        Preferences.useFullStatusBarOnExpandEnabled = fullStatusBarCheck.state == .on
    }

    @objc private func alwaysHiddenChanged() {
        Preferences.alwaysHiddenSectionEnabled = alwaysHiddenCheck.state == .on
        preview.refresh(alwaysHidden: Preferences.alwaysHiddenSectionEnabled)
    }

    @objc private func keepSystemItemsChanged() {
        Preferences.keepSystemItemsVisible = keepSystemItemsCheck.state == .on
    }

    @objc private func autoHideChanged() {
        Preferences.isAutoHide = autoHideCheck.state == .on
        delayPopup.isEnabled = Preferences.isAutoHide
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
        open("https://dotoca.net/")
    }

    private func open(_ string: String) {
        guard let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Shortcut recording

    @objc private func beginShortcutRecording() {
        guard listeningMonitor == nil else { return }

        isListening = true
        shortcutButton.highlight(true)
        shortcutButton.title = "Type a shortcut…".localized
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
        shortcutButton.title = bind.description.isEmpty
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
            shortcutButton.title = bind.description
            clearButton.isEnabled = true
        }
    }

    private func endShortcutRecording(restoreTitle: Bool) {
        if let monitor = listeningMonitor {
            NSEvent.removeMonitor(monitor)
            listeningMonitor = nil
        }
        isListening = false
        shortcutButton?.highlight(false)
        if restoreTitle {
            updateShortcut()
        }
    }

    @objc private func clearShortcut() {
        Preferences.globalKey = nil
        (NSApp.delegate as? AppDelegate)?.hotKey = nil
        updateShortcut()
    }

    // MARK: - Help

    @objc private func showAlwaysHiddenHelp(_ sender: NSButton) {
        helpRow.isHidden.toggle()
        sender.toolTip = (helpRow.isHidden
            ? "How the always hidden section works"
            : "Hide the always hidden help").localized
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
