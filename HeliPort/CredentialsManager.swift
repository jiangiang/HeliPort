//
//  CredentialsManager.swift
//  HeliPort
//
//  Created by Igor Kulman on 22/06/2020.
//  Copyright © 2020 OpenIntelWireless. All rights reserved.
//

/*
 * This program and the accompanying materials are licensed and made available
 * under the terms and conditions of the The 3-Clause BSD License
 * which accompanies this distribution. The full text of the license may be found at
 * https://opensource.org/licenses/BSD-3-Clause
 */

import Foundation
import KeychainAccess
import Security

final class CredentialsManager {
    static let instance: CredentialsManager = CredentialsManager()

    private let keychain: Keychain
    private let ssidCache: NSCache = NSCache<NSString, NSSet>()
    private let ssidCacheKey = NSString("savedSSIDs")
    private let storageCache = NSCache<NSString, NSString>()

    private init() {
        keychain = Keychain(service: Bundle.main.bundleIdentifier!)
    }

    private func invalidateStorageCache(for ssid: String? = nil) {
        guard let ssid else {
            storageCache.removeAllObjects()
            return
        }
        storageCache.removeObject(forKey: ssid as NSString)
    }

    private func getStoredSSIDs() -> [String] {
        let keychainKeys = keychain.allKeys()
        if !keychainKeys.isEmpty {
            return keychainKeys
        }

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Bundle.main.bundleIdentifier!,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true
        ]

        if #available(macOS 10.11, *) {
            query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUIAllow
        }

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let items = result as? [[String: Any]] else {
                return []
            }
            return items.compactMap { $0[kSecAttrAccount as String] as? String }
        case errSecItemNotFound:
            return []
        default:
            Log.error("Failed to enumerate saved networks: \(status)")
            return []
        }
    }

    func save(_ network: NetworkInfo) {
        guard let networkAuthJson = try? String(decoding: JSONEncoder().encode(network.auth), as: UTF8.self) else {
            return
        }
        network.auth = NetworkAuth()
        let entity = NetworkInfoStorageEntity(network)
        guard let entityJson = try? String(decoding: JSONEncoder().encode(entity), as: UTF8.self) else {
            return
        }

        ssidCache.removeObject(forKey: ssidCacheKey)

        Log.debug("Saving password for network \(network.ssid)")
        try? keychain.comment(entityJson).set(networkAuthJson, key: network.keychainKey)
        invalidateStorageCache(for: network.keychainKey)
    }

    private func decodeAuth(from data: Data, ssid: String) -> NetworkAuth? {
        if let auth = try? JSONDecoder().decode(NetworkAuth.self, from: data) {
            return auth
        }

        guard let password = String(data: data, encoding: .utf8), !password.isEmpty else {
            Log.debug("Could not decode stored password for network \(ssid)")
            return nil
        }

        let auth = NetworkAuth()
        auth.password = password
        return auth
    }

    func get(_ network: NetworkInfo) -> NetworkAuth? {
        guard let password = keychain[string: network.keychainKey],
            let jsonData = password.data(using: .utf8) else {
            Log.debug("No stored password for network \(network.ssid)")
            return nil
        }

        Log.debug("Loading password for network \(network.ssid)")
        return decodeAuth(from: jsonData, ssid: network.ssid)
    }

    func remove(_ network: NetworkInfo) {
        Log.debug("Removing \(network.ssid) from keychain")
        try? keychain.remove(network.keychainKey)
        ssidCache.removeObject(forKey: ssidCacheKey)
        invalidateStorageCache(for: network.keychainKey)
    }

    func getStorageFromSsid(_ ssid: String) -> NetworkInfoStorageEntity? {
        if let cached = storageCache.object(forKey: ssid as NSString),
           let jsonData = (cached as String).data(using: .utf8) {
            return try? JSONDecoder().decode(NetworkInfoStorageEntity.self, from: jsonData)
        }

        guard let attributes = try? keychain.get(ssid, handler: {$0}),
            let json = attributes.comment,
            let jsonData = json.data(using: .utf8) else {
                return nil
        }

        guard let entity = try? JSONDecoder().decode(NetworkInfoStorageEntity.self, from: jsonData) else {
            return nil
        }

        storageCache.setObject(json as NSString, forKey: ssid as NSString)
        return entity
    }

    func getAuthFromSsid(_ ssid: String) -> NetworkAuth? {
        guard let attributes = try? keychain.get(ssid, handler: {$0}),
            let jsonData = attributes.data
            else {
                return nil
        }

        return decodeAuth(from: jsonData, ssid: ssid)
    }

    func setAutoJoin(_ ssid: String, _ autoJoin: Bool) {
        guard let auth = getAuthFromSsid(ssid) else {
                return
        }
        let entity = getStorageFromSsid(ssid) ?? NetworkInfoStorageEntity(NetworkInfo(ssid: ssid))

        entity.autoJoin = autoJoin

        guard let entityJson = try? String(decoding: JSONEncoder().encode(entity), as: UTF8.self),
              let authJson = try? String(decoding: JSONEncoder().encode(auth), as: UTF8.self) else {
            return
        }

        try? keychain.comment(entityJson).set(authJson, key: ssid)
        invalidateStorageCache(for: ssid)
    }

    func setPriority(_ ssid: String, _ priority: Int) {
        guard let auth = getAuthFromSsid(ssid) else {
                return
        }
        let entity = getStorageFromSsid(ssid) ?? NetworkInfoStorageEntity(NetworkInfo(ssid: ssid))

        entity.order = priority

        guard let entityJson = try? String(decoding: JSONEncoder().encode(entity), as: UTF8.self),
              let authJson = try? String(decoding: JSONEncoder().encode(auth), as: UTF8.self) else {
            return
        }

        try? keychain.comment(entityJson).set(authJson, key: ssid)
        invalidateStorageCache(for: ssid)
    }

    func getSavedNetworks() -> [NetworkInfo] {
        return getSavedNetworkEntities(includeAuth: false, autoJoinOnly: true).map { entity in
            entity.network
        }
    }

    func getSavedNetworkSSIDs() -> Set<String> {
        if let cached = ssidCache.object(forKey: ssidCacheKey) as? Set<String> {
            return cached
        }
        let savedSSIDs = Set(getStoredSSIDs())
        ssidCache.setObject(savedSSIDs as NSSet, forKey: ssidCacheKey)
        return savedSSIDs
    }

    func getSavedNetworksEntity() -> [NetworkInfoStorageEntity] {
        return getSavedNetworkEntities(includeAuth: true, autoJoinOnly: false)
    }

    private func getSavedNetworkEntities(includeAuth: Bool, autoJoinOnly: Bool) -> [NetworkInfoStorageEntity] {
        return getStoredSSIDs().compactMap { ssid -> NetworkInfoStorageEntity? in
            if let entity = getStorageFromSsid(ssid),
               entity.version == NetworkInfoStorageEntity.CURRENT_VERSION {
                if includeAuth, let auth = getAuthFromSsid(entity.network.ssid) {
                    entity.network.auth = auth
                }
                return entity
            }

            guard let auth = getAuthFromSsid(ssid) else {
                return nil
            }

            let network = NetworkInfo(ssid: ssid)
            if includeAuth {
                network.auth = auth
            }
            return NetworkInfoStorageEntity(network)
        }.filter { entity in
            !autoJoinOnly || entity.autoJoin
        }.sorted {
            $0.order < $1.order
        }
    }
}

fileprivate extension NetworkInfo {
    var keychainKey: String {
        return ssid
    }
}
