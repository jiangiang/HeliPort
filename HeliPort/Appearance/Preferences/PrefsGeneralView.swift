//
//  PrefsGeneralView.swift
//  HeliPort
//
//  Created by Erik Bautista on 8/3/20.
//  Copyright © 2020 OpenIntelWireless. All rights reserved.
//

/*
 * This program and the accompanying materials are licensed and made available
 * under the terms and conditions of the The 3-Clause BSD License
 * which accompanies this distribution. The full text of the license may be found at
 * https://opensource.org/licenses/BSD-3-Clause
 */

import Cocoa
import Sparkle

class PrefsGeneralView: NSView {

    let startupLabel: NSTextField = {
        let view = NSTextField(labelWithString: .startup)
        view.alignment = .right
        return view
    }()

    lazy var launchAtLoginCheckbox: NSButton = {
        let checkbox = NSButton(checkboxWithTitle: .launchAtLogin,
                                target: self,
                                action: #selector(checkboxChanged(_:)))
        checkbox.identifier = .launchAtLoginId
        checkbox.state = LoginItemManager.isEnabled() ? .on : .off
        checkbox.isEnabled = LoginItemManager.isAvailable
        return checkbox
    }()

    let launchAtLoginInfoLabel: NSTextField = {
        let label = NSTextField(wrappingLabelWithString: LoginItemManager.unavailableReason ?? "")
        label.textColor = .secondaryLabelColor
        label.maximumNumberOfLines = 0
        label.isHidden = LoginItemManager.isAvailable
        return label
    }()

    let updatesLabel: NSTextField = {
        let view = NSTextField(labelWithString: .updates)
        view.alignment = .right
        return view
    }()

    lazy var autoUpdateCheckbox: NSButton = {
        let checkbox = NSButton(checkboxWithTitle: .autoCheckUpdate,
                                target: self,
                                action: #selector(checkboxChanged(_:)))
        checkbox.identifier = .autoUpdateId
        checkbox.state = UpdateManager.sharedUpdater.automaticallyChecksForUpdates ? .on : .off
        return checkbox
    }()

    lazy var autoDownloadCheckbox: NSButton = {
        let checkbox = NSButton(checkboxWithTitle: .autoDownload,
                                target: self,
                                action: #selector(checkboxChanged(_:)))
        checkbox.identifier = .autoDownloadId
        checkbox.state = UpdateManager.sharedUpdater.automaticallyDownloadsUpdates ? .on : .off
        return checkbox
    }()

    let appearanceLabel: NSTextField = {
        let view = NSTextField(labelWithString: .appearance)
        view.alignment = .right
        return view
    }()

    lazy var legacyUICheckbox: NSButton = {
        let checkbox = NSButton(checkboxWithTitle: .useLegacyUI,
                                target: self,
                                action: #selector(self.checkboxChanged(_:)))
        checkbox.identifier = .legacyUIId

        if #available(macOS 11, *) {
            checkbox.state = UserDefaults.standard.bool(forKey: .DefaultsKey.legacyUI) ? .on : .off
        } else {
            checkbox.state = .on
            checkbox.isEnabled = false
        }

        return checkbox
    }()

    let advancedLabel: NSTextField = {
        let view = NSTextField(labelWithString: .advanced)
        view.alignment = .right
        return view
    }()

    lazy var showDuplicateSSIDsCheckbox: NSButton = {
        let checkbox = NSButton(checkboxWithTitle: .showDuplicateSSIDs,
                                target: self,
                                action: #selector(self.checkboxChanged(_:)))
        checkbox.identifier = .showDuplicateSSIDsId
        checkbox.state = UserDefaults.standard.bool(forKey: .DefaultsKey.showDuplicateSSIDsByBSSID) ? .on : .off
        return checkbox
    }()

    lazy var preferStrongestKnownNetworkCheckbox: NSButton = {
        let checkbox = NSButton(checkboxWithTitle: .preferStrongestKnownNetwork,
                                target: self,
                                action: #selector(self.checkboxChanged(_:)))
        checkbox.identifier = .preferStrongestKnownNetworkId
        checkbox.state = UserDefaults.standard.bool(forKey: .DefaultsKey.preferStrongestKnownNetwork) ? .on : .off
        return checkbox
    }()

    let gridView: NSGridView = {
        let view = NSGridView()
        view.setContentHuggingPriority(.init(rawValue: 600), for: .horizontal)
        return view
    }()

    convenience init() {
        self.init(frame: NSRect.zero)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        gridView.addRow(with: [startupLabel, launchAtLoginCheckbox])
        if !LoginItemManager.isAvailable {
            gridView.addRow(with: [NSView(), launchAtLoginInfoLabel])
        }
        let updatesRow = gridView.addRow(with: [updatesLabel, autoUpdateCheckbox])
        updatesRow.topPadding = 5
        gridView.addRow(with: [NSView(), autoDownloadCheckbox])
        let appearanceRow = gridView.addRow(with: [appearanceLabel, legacyUICheckbox])
        appearanceRow.topPadding = 5
        let advancedRow = gridView.addRow(with: [advancedLabel, showDuplicateSSIDsCheckbox])
        advancedRow.topPadding = 5
        gridView.addRow(with: [NSView(), preferStrongestKnownNetworkCheckbox])

        addSubview(gridView)
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupConstraints() {
        subviews.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        let inset: CGFloat = 20
        gridView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset).isActive = true
        gridView.topAnchor.constraint(equalTo: topAnchor, constant: inset).isActive = true
        gridView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset).isActive = true
        gridView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -inset).isActive = true
    }
}

extension PrefsGeneralView {
    @objc private func checkboxChanged(_ sender: NSButton) {
        guard let identifier = sender.identifier else { return }
        Log.debug("State changed for \(identifier)")

        switch identifier {
        case .launchAtLoginId:
            LoginItemManager.setStatus(enabled: sender.state == .on)
            sender.state = LoginItemManager.isEnabled() ? .on : .off
        case .autoUpdateId:
            UpdateManager.sharedUpdater.automaticallyChecksForUpdates = sender.state == .on
        case .autoDownloadId:
            UpdateManager.sharedUpdater.automaticallyDownloadsUpdates = sender.state == .on
        case .legacyUIId:
            if #available(macOS 11, *) {
                UserDefaults.standard.set(sender.state == .on, forKey: .DefaultsKey.legacyUI)
                let alert = CriticalAlert(message: .heliportRestart,
                                          informativeText: .restartInfoText,
                                          options: [.restart, .later])

                if alert.show() == .alertFirstButtonReturn {
                    NSApp.restartApp()
                }
            }
        case .showDuplicateSSIDsId:
            UserDefaults.standard.set(sender.state == .on, forKey: .DefaultsKey.showDuplicateSSIDsByBSSID)
        case .preferStrongestKnownNetworkId:
            UserDefaults.standard.set(sender.state == .on, forKey: .DefaultsKey.preferStrongestKnownNetwork)
        default:
            break
        }
    }
}

private extension NSUserInterfaceItemIdentifier {
    static let launchAtLoginId = NSUserInterfaceItemIdentifier(rawValue: "LaunchAtLoginCheckbox")
    static let autoUpdateId = NSUserInterfaceItemIdentifier(rawValue: "AutoUpdateCheckbox")
    static let autoDownloadId = NSUserInterfaceItemIdentifier(rawValue: "AutoDownloadCheckbox")

    static let legacyUIId = NSUserInterfaceItemIdentifier(rawValue: "legacyUICheckbox")
    static let showDuplicateSSIDsId = NSUserInterfaceItemIdentifier(rawValue: "showDuplicateSSIDsCheckbox")
    static let preferStrongestKnownNetworkId = NSUserInterfaceItemIdentifier(
        rawValue: "preferStrongestKnownNetworkCheckbox"
    )
}

private extension String {
    static let startup = NSLocalizedString("Startup:")
    static let launchAtLogin = NSLocalizedString("Launch HeliPort at login")
    static let updates = NSLocalizedString("Updates:")
    static let autoCheckUpdate = NSLocalizedString("Automatically check for updates.")
    static let autoDownload = NSLocalizedString("Automatically download new updates.")

    static let appearance = NSLocalizedString("Appearance:")
    static let useLegacyUI = NSLocalizedString("Use Legacy UI")
    static let advanced = NSLocalizedString("Advanced:")
    static let showDuplicateSSIDs = NSLocalizedString("Show duplicate SSIDs by BSSID")
    static let preferStrongestKnownNetwork = NSLocalizedString("Auto-connect to strongest known Wi-Fi")

    static let heliportRestart = NSLocalizedString("HeliPort Restart Required")
    static let restartInfoText =
        NSLocalizedString("Switching appearance requires a restart of the application to take effect.")
    static let restart = NSLocalizedString("Restart")
    static let later = NSLocalizedString("Later")
}
