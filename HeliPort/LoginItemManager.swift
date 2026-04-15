//
//  LoginItemManager.swift
//  HeliPort
//
//  Created by Bat.bat on 7/14/20.
//  Copyright © 2020 OpenIntelWireless. All rights reserved.
//

/*
 * This program and the accompanying materials are licensed and made available
 * under the terms and conditions of the The 3-Clause BSD License
 * which accompanies this distribution. The full text of the license may be found at
 * https://opensource.org/licenses/BSD-3-Clause
 */

import Foundation
import ServiceManagement
import Security

class LoginItemManager {

    private static let launcherId = Bundle.main.bundleIdentifier! + "-Launcher"

    public class func isEnabled() -> Bool {
        guard let jobs =
            (LoginItemManager.self as DeprecationWarningWorkaround.Type).jobsDict
        else {
            return false
        }

        let job = jobs.first { $0["Label"] as? String? == launcherId }

        return job?["OnDemand"] as? Bool ?? false
    }

    public class func setStatus(enabled: Bool) {
        SMLoginItemSetEnabled(launcherId as CFString, enabled)
    }

    public class var isAvailable: Bool {
        isCodeSigned
    }

    public class var unavailableReason: String? {
        guard !isAvailable else {
            return nil
        }
        return NSLocalizedString("Launch at login is unavailable for unsigned local builds. "
                                 + "Code signing is required for the embedded launcher helper.",
                                 comment: "")
    }

    private class var isCodeSigned: Bool {
        let bundleURL = Bundle.main.bundleURL as CFURL
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(bundleURL, [], &staticCode) == errSecSuccess,
              let staticCode else {
            return false
        }

        return SecStaticCodeCheckValidity(staticCode, [], nil) == errSecSuccess
    }
}

private protocol DeprecationWarningWorkaround {
    static var jobsDict: [[String: AnyObject]]? { get }
}

extension LoginItemManager: DeprecationWarningWorkaround {
    // Workaround to silence "'SMCopyAllJobDictionaries' was deprecated in OS X 10.10" warning
    @available(*, deprecated)
    static var jobsDict: [[String: AnyObject]]? {
        SMCopyAllJobDictionaries(kSMDomainUserLaunchd)?.takeRetainedValue() as? [[String: AnyObject]]
    }
}
