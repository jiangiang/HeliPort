//
//  PrefsWindow.swift
//  HeliPort
//
//  Created by Erik Bautista on 8/1/20.
//  Copyright © 2020 OpenIntelWireless. All rights reserved.
//

/*
 * This program and the accompanying materials are licensed and made available
 * under the terms and conditions of the The 3-Clause BSD License
 * which accompanies this distribution. The full text of the license may be found at
 * https://opensource.org/licenses/BSD-3-Clause
 */

import Cocoa

class PrefsWindow: NSWindow {

    // MARK: Properties

    var previousIdentifier: NSToolbarItem.Identifier = .none

    convenience init() {
        self.init(contentRect: NSRect.zero,
                  styleMask: [.titled, .closable],
                  backing: .buffered,
                  defer: false)
    }

    override init(contentRect: NSRect,
                  styleMask style: NSWindow.StyleMask,
                  backing backingStoreType: NSWindow.BackingStoreType,
                  defer flag: Bool) {

        super.init(contentRect: contentRect,
                   styleMask: style,
                   backing: backingStoreType,
                   defer: flag)

        isReleasedWhenClosed = false

        title = .networkPrefs

        toolbar = NSToolbar(identifier: "NetworkPrefWindowToolbar")
        toolbar!.delegate = self
        toolbar!.displayMode = .iconAndLabel
        toolbar!.insertItem(withItemIdentifier: .general, at: 0)
        toolbar!.insertItem(withItemIdentifier: .networks, at: 1)
        toolbar!.insertItem(withItemIdentifier: .current, at: 2)
        toolbar!.selectedItemIdentifier = .general

        if #available(OSX 11.0, *) {
            self.toolbarStyle = .preference
        }

        // Set selected item

        clickToolbarItem(NSToolbarItem(itemIdentifier: toolbar!.selectedItemIdentifier!))
    }

    func show() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
        center()
    }

    func showGeneral() {
        previousIdentifier = .none
        toolbar?.selectedItemIdentifier = .general
        clickToolbarItem(NSToolbarItem(itemIdentifier: .general))
        show()
    }

    override func close() {
        super.close()
        self.orderOut(NSApp)
    }

    @objc private func clickToolbarItem(_ sender: NSToolbarItem) {
        guard let identifier = toolbar?.selectedItemIdentifier else { return }
        guard previousIdentifier != identifier else {
            Log.debug("Toolbar Item already showing \(identifier)")
            return
        }

        Log.debug("Toolbar Item clicked: \(identifier)")

        var newView: NSView?
        var origin = frame.origin
        var size = frame.size
        switch identifier {
        case .networks:
            newView = PrefsSavedNetworksView()
            size = NSSize(width: 620, height: 420)
        case .current:
            newView = PrefsCurrentNetworkView()
            size = NSSize(width: 430, height: 340)
        case .general:
            newView = PrefsGeneralView()
            size = newView!.fittingSize
        default:
            Log.error("Toolbar Item not implemented: \(identifier)")
        }

        guard let view = newView else { return }

        origin.y -= size.height - frame.size.height
        contentView = view
        setFrame(NSRect(origin: origin, size: size), display: true, animate: true)
        previousIdentifier = identifier
    }
}

// MARK: NSToolbarItemDelegate

extension PrefsWindow: NSToolbarDelegate {

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.general, .networks, .current]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.general, .networks, .current]
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.general, .networks, .current]
    }

    func toolbar(_ toolbar: NSToolbar,
                 itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {

        let toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)
        toolbarItem.target = self
        toolbarItem.action = #selector(clickToolbarItem(_:))

        switch itemIdentifier {
        case .networks:
            toolbarItem.label = .networks
            toolbarItem.paletteLabel = .networks
            if #available(OSX 11.0, *) {
                toolbarItem.image = NSImage(systemSymbolName: "wifi", accessibilityDescription: .general)
            } else {
                toolbarItem.image = #imageLiteral(resourceName: "WiFi")
            }
            toolbarItem.isEnabled = true
            return toolbarItem
        case .current:
            toolbarItem.label = .current
            toolbarItem.paletteLabel = .current
            if #available(OSX 11.0, *) {
                toolbarItem.image = NSImage(systemSymbolName: "dot.radiowaves.left.and.right",
                                            accessibilityDescription: .current)
            } else {
                toolbarItem.image = #imageLiteral(resourceName: "WiFi")
            }
            toolbarItem.isEnabled = true
            return toolbarItem
        case .general:
            toolbarItem.label = .general
            toolbarItem.paletteLabel = .general
            if #available(OSX 11.0, *) {
                toolbarItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: .general)
            } else {
                toolbarItem.image = NSImage(named: NSImage.preferencesGeneralName)
            }
            toolbarItem.isEnabled = true
            return toolbarItem
        default:
            return nil
        }
    }
}

// MARK: Toolbar Item Identifiers

private extension NSToolbarItem.Identifier {
    static let networks = NSToolbarItem.Identifier("WiFiNetworks")
    static let current = NSToolbarItem.Identifier("CurrentWiFi")
    static let general = NSToolbarItem.Identifier("General")
    static let none = NSToolbarItem.Identifier("none")
}

// MARK: Localized Strings

private extension String {
    static let networkPrefs = NSLocalizedString("Network Preferences")
    static let networks = NSLocalizedString("Networks")
    static let current = NSLocalizedString("Current")
    static let general = NSLocalizedString("General")
}

final class PrefsCurrentNetworkView: NSView {
    private let titleLabel = NSTextField(labelWithString: .currentNetwork)
    private let statusLabel = NSTextField(labelWithString: .notConnected)
    private let gridView: NSGridView = {
        let view = NSGridView()
        view.rowSpacing = 6
        view.columnSpacing = 12
        return view
    }()
    private var refreshTimer: Timer?
    private var valueLabels = [String: NSTextField]()

    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        let rows: [(String, String)] = [
            (.interfaceName, "interface"),
            (.networkName, "ssid"),
            (.bssid, "bssid"),
            (.channel, "channel"),
            (.rssi, "rssi"),
            (.noise, "noise"),
            (.txRate, "txRate"),
            (.phyMode, "phyMode"),
            (.ipAddress, "ipAddress"),
            (.router, "router"),
            (.internet, "internet")
        ]

        rows.forEach { title, key in
            let keyLabel = NSTextField(labelWithString: title)
            keyLabel.alignment = .right
            let valueLabel = NSTextField(labelWithString: .unavailableValue)
            valueLabel.lineBreakMode = .byTruncatingMiddle
            valueLabels[key] = valueLabel
            gridView.addRow(with: [keyLabel, valueLabel])
        }

        addSubview(titleLabel)
        addSubview(statusLabel)
        addSubview(gridView)
        setupConstraints()
        refresh()

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        if let refreshTimer {
            RunLoop.main.add(refreshTimer, forMode: .common)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        refreshTimer?.invalidate()
    }

    private func setupConstraints() {
        subviews.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        let inset: CGFloat = 20
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: inset),

            statusLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),

            gridView.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            gridView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 12),
            gridView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -inset),
            gridView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -inset)
        ])
    }

    private func refresh() {
        DispatchQueue.global(qos: .background).async {
            let info = NetworkManager.getCurrentNetworkInfo()
            DispatchQueue.main.async {
                self.statusLabel.stringValue = info.isConnected ? .connected : .notConnected
                self.gridView.isHidden = !info.isConnected
                guard info.isConnected else { return }
                self.valueLabels["interface"]?.stringValue = info.interfaceName
                self.valueLabels["ssid"]?.stringValue = info.ssid
                self.valueLabels["bssid"]?.stringValue = info.bssid
                self.valueLabels["channel"]?.stringValue = info.channel
                self.valueLabels["rssi"]?.stringValue = info.rssi
                self.valueLabels["noise"]?.stringValue = info.noise
                self.valueLabels["txRate"]?.stringValue = info.txRate
                self.valueLabels["phyMode"]?.stringValue = info.phyMode
                self.valueLabels["ipAddress"]?.stringValue = info.ipAddress
                self.valueLabels["router"]?.stringValue = info.router
                self.valueLabels["internet"]?.stringValue = info.internet
            }
        }
    }
}

private extension String {
    static let currentNetwork = NSLocalizedString("Current Network:")
    static let notConnected = NSLocalizedString("Not connected")
    static let connected = NSLocalizedString("Connected")
    static let unavailableValue = NSLocalizedString("Unavailable")
    static let interfaceName = NSLocalizedString("Interface:")
    static let networkName = NSLocalizedString("Network:")
    static let bssid = NSLocalizedString("BSSID:")
    static let channel = NSLocalizedString("Channel:")
    static let rssi = NSLocalizedString("RSSI:")
    static let noise = NSLocalizedString("Noise:")
    static let txRate = NSLocalizedString("Tx Rate:")
    static let phyMode = NSLocalizedString("PHY Mode:")
    static let ipAddress = NSLocalizedString("IP Address:")
    static let router = NSLocalizedString("Router:")
    static let internet = NSLocalizedString("Internet:")
}
