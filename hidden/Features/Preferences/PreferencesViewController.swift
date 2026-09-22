//
//  ViewController.swift
//  vanillaClone
//
//  Created by Thanh Nguyen on 1/24/19.
//  Changed by Vitalii Tereshchuk, 2026
//  Copyright © 2019 Dwarves Foundation. All rights reserved.
//

import Cocoa
import Carbon
import HotKey

class PreferencesViewController: NSViewController {
    
   
    //MARK: - Outlets
    @IBOutlet weak var checkBoxKeepLastState: NSButton!
    @IBOutlet weak var textFieldTitle: NSTextField!
    @IBOutlet weak var imageViewTop: NSImageView!
    
    @IBOutlet weak var statusBarStackView: NSStackView!
    @IBOutlet weak var arrowPointToHiddenImage: NSImageView!
    @IBOutlet weak var arrowPointToAlwayHiddenImage: NSImageView!
    @IBOutlet weak var lblAlwayHidden: NSTextField!
    
    @IBOutlet weak var generalStackView: NSStackView!
    @IBOutlet weak var appearanceSection: NSStackView!
    
    
    @IBOutlet weak var checkBoxAutoHide: NSButton!
    @IBOutlet weak var checkBoxKeepInDock: NSButton!
    @IBOutlet weak var checkBoxLogin: NSButton!
    @IBOutlet weak var checkBoxShowPreferences: NSButton!
    @IBOutlet weak var checkBoxShowAlwaysHiddenSection: NSButton!
    
    @IBOutlet weak var checkBoxUseFullStatusbar: NSButton!
    @IBOutlet weak var timePopup: NSPopUpButton!

    // Hiding-engine selector (auto / native / legacy). Built in code rather than
    // in the storyboard so the menu-bar mechanics stay out of Main.storyboard.
    private lazy var engineSegmentedControl: NSSegmentedControl = {
        let control = NSSegmentedControl(labels: [
            "Auto".localized,
            "Native".localized,
            "Legacy".localized
        ], trackingMode: .selectOne, target: self,
           action: #selector(enginePreferenceChanged(_:)))
        control.translatesAutoresizingMaskIntoConstraints = false
        control.toolTip = "Auto picks native hiding on macOS 27 (direct build), legacy otherwise. Native forced requires the direct, non-sandboxed build; Legacy always works but depends on display width.".localized
        return control
    }()

    private lazy var enginePreferenceLabel: NSTextField = {
        let label = NSTextField(labelWithString: "Hiding engine".localized)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var enginePreferenceNote: NSTextField = {
        let note = NSTextField(wrappingLabelWithString: "")
        note.translatesAutoresizingMaskIntoConstraints = false
        note.font = .systemFont(ofSize: 10)
        note.textColor = .secondaryLabelColor
        note.maximumNumberOfLines = 2
        note.preferredMaxLayoutWidth = 320
        return note
    }()
    
    @IBOutlet weak var btnClear: NSButton!
    @IBOutlet weak var btnShortcut: NSButton!
    
    public var listening = false {
        didSet {
            let isHighlight = listening
            
            DispatchQueue.main.async { [weak self] in
                self?.btnShortcut.highlight(isHighlight)
            }
        }
    }
    
    // MARK: - UI Setup
    
    //MARK: - VC Life cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        updateData()
        loadHotkey()
        createTutorialView()
        setupEnginePreferenceUI()
        NotificationCenter.default.addObserver(self, selector: #selector(updateData), name: .prefsChanged, object: nil)
        
        // Lower imageViewTop slightly to avoid overlap with segment buttons
        if let imageView = imageViewTop {
            imageView.translatesAutoresizingMaskIntoConstraints = true
            // Move image down by 12 points - adjust as needed
            var frame = imageView.frame
            frame.origin.y += 12
            imageView.frame = frame
        }
    }

    deinit {
        // Balance the viewDidLoad observer (PRs #335/#346).
        NotificationCenter.default.removeObserver(self, name: .prefsChanged, object: nil)
    }

    static func initWithStoryboard() -> PreferencesViewController {
        let vc = NSStoryboard(name:"Main", bundle: nil).instantiateController(withIdentifier: "prefVC") as! PreferencesViewController
        return vc
    }
    
    //MARK: - Actions
    @IBAction func loginCheckChanged(_ sender: NSButton) {
        Preferences.isAutoStart = sender.state == .on
    }
    
    @IBAction func autoHideCheckChanged(_ sender: NSButton) {
        Preferences.isAutoHide = sender.state == .on
    }
    
    @IBAction func showPreferencesChanged(_ sender: NSButton) {
        Preferences.isShowPreference = sender.state == .on
    }
    
    
    @IBAction func showAlwaysHiddenSectionChanged(_ sender: NSButton) {
        Preferences.alwaysHiddenSectionEnabled = sender.state == .on
        createTutorialView()
    }
    @IBAction func useFullStatusBarOnExpandChanged(_ sender: NSButton) {
        Preferences.useFullStatusBarOnExpandEnabled = sender.state == .on
    }
    
    
    @IBAction func timePopupDidSelected(_ sender: NSPopUpButton) {
        let selectedIndex = sender.indexOfSelectedItem
        if let selectedInSecond = SelectedSecond(rawValue: selectedIndex)?.toSeconds() {
            Preferences.numberOfSecondForAutoHide = selectedInSecond
        }
    }

    // MARK: - Hiding engine preference

    private func setupEnginePreferenceUI() {
        guard let container = generalStackView else { return }
        // A row: label, segmented control, then a note underneath.
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false
        row.addArrangedSubview(enginePreferenceLabel)
        row.addArrangedSubview(enginePreferenceControl)

        let noteRow = NSStackView()
        noteRow.orientation = .horizontal
        noteRow.translatesAutoresizingMaskIntoConstraints = false
        noteRow.addArrangedSubview(enginePreferenceNote)

        container.addView(row, in: .top)
        container.addView(noteRow, in: .top)
        updateEnginePreferenceUI()
    }

    private var enginePreferenceControl: NSSegmentedControl { engineSegmentedControl }

    @objc private func enginePreferenceChanged(_ sender: NSSegmentedControl) {
        let preference: Preferences.MenuBarEnginePreference
        switch sender.indexOfSelectedItem {
        case 1: preference = .native
        case 2: preference = .legacy
        default: preference = .auto
        }
        Preferences.menuBarEnginePreference = preference
        updateEnginePreferenceUI()
    }

    private func updateEnginePreferenceUI() {
        let selected: Int
        switch Preferences.menuBarEnginePreference {
        case .native: selected = 1
        case .legacy: selected = 2
        default: selected = 0
        }
        engineSegmentedControl.selectedSegment = selected


        let resolved = MenuBarEngineFactory.resolvedPreference(Preferences.menuBarEnginePreference)
        let nativeOffered = MenuBarEngineFactory.nativeVisibilityAvailable
        if !nativeOffered && Preferences.menuBarEnginePreference == .native {
            enginePreferenceNote.stringValue = "Native hiding needs the direct (non-sandboxed) build on macOS 27 — falling back to Legacy.".localized
        } else if resolved == .native {
            enginePreferenceNote.stringValue = "Using native hiding (independent of display width).".localized
        } else {
            enginePreferenceNote.stringValue = "Using Legacy spacer hiding (limited on wide displays).".localized
        }
    }
    
    // When the set shortcut button is pressed start listening for the new shortcut
    @IBAction func register(_ sender: Any) {
        listening = true
        view.window?.makeFirstResponder(nil)
    }
    
    // If the shortcut is cleared, clear the UI and tell AppDelegate to stop listening to the previous keybind.
    @IBAction func unregister(_ sender: Any?) {
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        appDelegate.hotKey = nil
        btnShortcut.title = "Set Shortcut".localized
        listening = false
        btnClear.isEnabled = false
        
        // Remove globalkey from userdefault
        Preferences.globalKey = nil
    }
    
    public func updateGlobalShortcut(_ event: NSEvent) {
        self.listening = false
        
        guard let characters = event.charactersIgnoringModifiers else {return}
        
        let newGlobalKeybind = GlobalKeybindPreferences(
            function: event.modifierFlags.contains(.function),
            control: event.modifierFlags.contains(.control),
            command: event.modifierFlags.contains(.command),
            shift: event.modifierFlags.contains(.shift),
            option: event.modifierFlags.contains(.option),
            capsLock: event.modifierFlags.contains(.capsLock),
            carbonFlags: event.modifierFlags.carbonFlags,
            characters: characters,
            keyCode: uint32(event.keyCode))
        
        Preferences.globalKey = newGlobalKeybind
        
        updateKeybindButton(newGlobalKeybind)
        btnClear.isEnabled = true
        
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        appDelegate.hotKey = HotKey(keyCombo: KeyCombo(carbonKeyCode: UInt32(event.keyCode), carbonModifiers: event.modifierFlags.carbonFlags))
    }
    
    public func updateModiferFlags(_ event: NSEvent) {
        let newGlobalKeybind = GlobalKeybindPreferences(
            function: event.modifierFlags.contains(.function),
            control: event.modifierFlags.contains(.control),
            command: event.modifierFlags.contains(.command),
            shift: event.modifierFlags.contains(.shift),
            option: event.modifierFlags.contains(.option),
            capsLock: event.modifierFlags.contains(.capsLock),
            carbonFlags: 0,
            characters: nil,
            keyCode: uint32(event.keyCode))
        
        updateModifierbindButton(newGlobalKeybind)
        
    }
    
    @objc private func updateData(){
        checkBoxUseFullStatusbar.state = Preferences.useFullStatusBarOnExpandEnabled ? .on : .off
        checkBoxLogin.state = Preferences.isAutoStart ? .on : .off
        checkBoxAutoHide.state = Preferences.isAutoHide ? .on : .off
        checkBoxShowPreferences.state = Preferences.isShowPreference ? .on : .off
        checkBoxShowAlwaysHiddenSection.state = Preferences.alwaysHiddenSectionEnabled ? .on : .off
        timePopup.selectItem(at: SelectedSecond.secondToPossition(seconds: Preferences.numberOfSecondForAutoHide))
        updateEnginePreferenceUI()

        // Visual feedback: highlight changed items
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    }
    
    private func loadHotkey() {
        if let globalKey = Preferences.globalKey {
            updateKeybindButton(globalKey)
            updateClearButton(globalKey)
        }
    }
    
    // Set the shortcut button to show the keys to press
    private func updateKeybindButton(_ globalKeybindPreference : GlobalKeybindPreferences) {
        btnShortcut.title = globalKeybindPreference.description
        
        if globalKeybindPreference.description.count <= 1 {
            unregister(nil)
        }
    }
    
    // Set the shortcut button to show the modifier to press
      private func updateModifierbindButton(_ globalKeybindPreference : GlobalKeybindPreferences) {
          btnShortcut.title = globalKeybindPreference.description
          
          if globalKeybindPreference.description.isEmpty {
              unregister(nil)
          }
      }
    
    // If a keybind is set, allow users to clear it by enabling the clear button.
    private func updateClearButton(_ globalKeybindPreference : GlobalKeybindPreferences?) {
        btnClear.isEnabled = globalKeybindPreference != nil
    }
}

//MARK: - Show tutorial
extension PreferencesViewController {
    
    func createTutorialView() {
        if Preferences.alwaysHiddenSectionEnabled {
            alwayHideStatusBar()
        }else {
            hideStatusBar()
        }
    }
    
    func hideStatusBar() {
        lblAlwayHidden.isHidden = true
        arrowPointToAlwayHiddenImage.isHidden = true
        statusBarStackView.removeAllSubViews()
        let imageWidth: CGFloat = 16
        
        
        let images = ["ico_1","ico_2","ico_3","seprated", "ico_collapse","ico_4","ico_5","ico_6","ico_7"].map { imageName in
            NSImageView(image: NSImage(named: imageName)!)
        }
        
        
        for image in images {
            statusBarStackView.addArrangedSubview(image)
            image.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                image.widthAnchor.constraint(equalToConstant: imageWidth),
                image.heightAnchor.constraint(equalToConstant: imageWidth)
                
            ])
            image.contentTintColor = .labelColor
        }
        let dateTimeLabel = NSTextField()
        dateTimeLabel.stringValue = Date.dateString() + " " + Date.timeString()
        dateTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        dateTimeLabel.isBezeled = false
        dateTimeLabel.isEditable = false
        dateTimeLabel.sizeToFit()
        dateTimeLabel.backgroundColor = .clear
        statusBarStackView.addArrangedSubview(dateTimeLabel)
        NSLayoutConstraint.activate([dateTimeLabel.heightAnchor.constraint(equalToConstant: imageWidth)
        ])
       
        NSLayoutConstraint.activate([
            arrowPointToHiddenImage.centerXAnchor.constraint(equalTo: statusBarStackView.arrangedSubviews[3].centerXAnchor)
        ])
    }
    
    func alwayHideStatusBar() {
        lblAlwayHidden.isHidden = false
        arrowPointToAlwayHiddenImage.isHidden = false
        statusBarStackView.removeAllSubViews()
        let imageWidth: CGFloat = 16
        
        
        let images = ["ico_1","ico_2","ico_3","ico_4", "seprated_1","ico_5","ico_6","seprated", "ico_collapse","ico_7"].map { imageName in
            NSImageView(image: NSImage(named: imageName)!)
        }
        
        
        for image in images {
            statusBarStackView.addArrangedSubview(image)
            image.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                image.widthAnchor.constraint(equalToConstant: imageWidth),
                image.heightAnchor.constraint(equalToConstant: imageWidth)
                
            ])
            image.contentTintColor = .labelColor
        }
        let dateTimeLabel = NSTextField()
        dateTimeLabel.stringValue = Date.dateString() + " " + Date.timeString()
        dateTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        dateTimeLabel.isBezeled = false
        dateTimeLabel.isEditable = false
        dateTimeLabel.sizeToFit()
        dateTimeLabel.backgroundColor = .clear
        statusBarStackView.addArrangedSubview(dateTimeLabel)
        NSLayoutConstraint.activate([dateTimeLabel.heightAnchor.constraint(equalToConstant: imageWidth)
        ])
        
        NSLayoutConstraint.activate([
            arrowPointToAlwayHiddenImage.centerXAnchor.constraint(equalTo: statusBarStackView.arrangedSubviews[4].centerXAnchor)
        ])
        NSLayoutConstraint.activate([
            arrowPointToHiddenImage.centerXAnchor.constraint(equalTo: statusBarStackView.arrangedSubviews[7].centerXAnchor)
        ])
    }
    
    @IBAction func btnAlwayHiddenHelpPressed(_ sender: NSButton) {
        self.showHowToUseAlwayHiddenPopover(sender: sender)
    }
    
    private func showHowToUseAlwayHiddenPopover(sender: NSButton) {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        
        // Create a modern tutorial view
        let tutorialView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 150))
        tutorialView.wantsLayer = true
        tutorialView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        tutorialView.layer?.cornerRadius = 10
        tutorialView.layer?.masksToBounds = true
        
        let label = NSTextField(labelWithString: NSLocalizedString("Tutorial text", comment: "Step by step tutorial"))
        label.font = .systemFont(ofSize: 13)
        label.textColor = NSColor.labelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        
        let maintainerText = NSAttributedString(string: "Maintained by Vitalii Tereshchuk (xVoLAnD)",
                                                attributes: [.font: NSFont.systemFont(ofSize: 11),
                                                             .foregroundColor: NSColor.secondaryLabelColor])
        
        let linkButton = NSButton(title: "https://dotoca.net", target: self, action: #selector(openMaintainerSite))
        linkButton.attributedTitle = maintainerText
        linkButton.isBordered = false
        linkButton.isEnabled = true
        linkButton.translatesAutoresizingMaskIntoConstraints = false
        
        tutorialView.addSubview(label)
        tutorialView.addSubview(linkButton)
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: tutorialView.topAnchor, constant: 16),
            label.leadingAnchor.constraint(equalTo: tutorialView.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(lessThanOrEqualTo: tutorialView.trailingAnchor, constant: -16),
            
            linkButton.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
            linkButton.leadingAnchor.constraint(equalTo: tutorialView.leadingAnchor, constant: 16),
            linkButton.bottomAnchor.constraint(equalTo: tutorialView.bottomAnchor, constant: -16),
        ])
        
        popover.contentViewController = NSViewController()
        popover.contentViewController?.view = tutorialView
        popover.contentSize = tutorialView.frame.size
        
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: NSRectEdge.maxX)
    }
    
    @objc private func openMaintainerSite() {
        NSWorkspace.shared.open(URL(string: "https://dotoca.net")!)
    }
}
