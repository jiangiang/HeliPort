//
//  NetworkManager+Data.swift
//  HeliPort
//
//  Created by 梁怀宇 on 2020/3/23.
//  Copyright © 2020 OpenIntelWireless. All rights reserved.
//

/*
 * This program and the accompanying materials are licensed and made available
 * under the terms and conditions of the The 3-Clause BSD License
 * which accompanies this distribution. The full text of the license may be found at
 * https://opensource.org/licenses/BSD-3-Clause
 */

import Foundation

final class NetworkInfo: Codable {
    let ssid: String
    var rssi: Int
    var bssid: String
    var channel: Int

    var auth = NetworkAuth()

    init (ssid: String, rssi: Int = 0, bssid: String = "", channel: Int = 0) {
        self.ssid = ssid
        self.rssi = rssi
        self.bssid = bssid
        self.channel = channel
    }

    var displaySSID: String {
        var details = [String]()
        if !bandDescription.isEmpty {
            details.append(bandDescription)
        }

        if UserDefaults.standard.bool(forKey: .DefaultsKey.showDuplicateSSIDsByBSSID),
           !bssid.isEmpty {
            details.append(bssid)
        }

        guard !details.isEmpty else {
            return ssid
        }
        return "\(ssid) (\(details.joined(separator: ", ")))"
    }

    var bandDescription: String {
        guard channel > 0 else { return "" }
        return channel <= 14 ? "2.4 GHz" : "5 GHz"
    }

    func matchesAccessPoint(_ other: NetworkInfo?) -> Bool {
        guard let other else { return false }
        if !bssid.isEmpty, !other.bssid.isEmpty {
            return bssid == other.bssid
        }
        return ssid == other.ssid
    }
}

extension NetworkInfo: Hashable {
    static func == (lhs: NetworkInfo, rhs: NetworkInfo) -> Bool {
        return lhs.ssid == rhs.ssid
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ssid)
    }
}

final class NetworkAuth: Codable {
    var security: itl80211_security = ITL80211_SECURITY_NONE
    var option: UInt64 = 0
    var identity = [UInt8]()
    var username: String = ""
    var password: String = ""
}

final class NetworkInfoStorageEntity: Codable {
    static let CURRENT_VERSION: UInt = 2

    var version: UInt = CURRENT_VERSION
    var autoJoin: Bool = true
    var order: Int = 0
    var network: NetworkInfo

    init (_ network: NetworkInfo, _ autoJoin: Bool = true, _ order: Int = 0) {
        self.network = network
        self.autoJoin = autoJoin
        self.order = order
    }
}

struct CurrentNetworkInfo {
    var interfaceName: String = .unavailable
    var ssid: String = .unavailable
    var bssid: String = .unavailable
    var channel: String = .unavailable
    var rssi: String = .unavailable
    var noise: String = .unavailable
    var txRate: String = .unavailable
    var phyMode: String = .unavailable
    var ipAddress: String = .unavailable
    var router: String = .unavailable
    var internet: String = .unavailable
    var isConnected = false
}

private extension String {
    static let unavailable = NSLocalizedString("Unavailable")
    static let unknown = NSLocalizedString("Unknown")
    static let reachable = NSLocalizedString("Reachable")
    static let unreachable = NSLocalizedString("Unreachable")
}
