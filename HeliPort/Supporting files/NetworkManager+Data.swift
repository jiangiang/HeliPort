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

    var auth = NetworkAuth()

    init (ssid: String, rssi: Int = 0, bssid: String = "") {
        self.ssid = ssid
        self.rssi = rssi
        self.bssid = bssid
    }

    var displaySSID: String {
        guard UserDefaults.standard.bool(forKey: .DefaultsKey.showDuplicateSSIDsByBSSID),
              !bssid.isEmpty else {
            return ssid
        }
        return "\(ssid) (\(bssid))"
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
