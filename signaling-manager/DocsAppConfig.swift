//
//  DocsAppConfig.swift
//  Docs-Examples
//
//  Created by Max Cobb on 29/06/2023.
//

import Foundation
import SwiftUI

public struct DocsAppConfig: Codable {
    static var shared: DocsAppConfig = {
        guard let fileUrl = Bundle.main.url(forResource: "config", withExtension: "json"),
              let jsonData  = try? Data(contentsOf: fileUrl) else { fatalError() }

        let decoder = JSONDecoder()
        // For this sample code we can assume the json is a valid format.
        // swiftlint:disable:next force_try
        var obj = try! decoder.decode(DocsAppConfig.self, from: jsonData)
        if (obj.token ?? "").isEmpty {
            obj.token = nil
        }
        #if os(iOS)
        if obj.uid == "identifierForVendor",
           let vendorId = UIDevice.current.identifierForVendor?.uuidString {
            obj.uid = vendorId
        }
        #endif
        // if macos, or the identifier otherwise failed
        if obj.uid == "identifierForVendor" {
            obj.uid = DocsAppConfig.appUniqueIdentifier()
        }
        return obj
    }()

    static func appUniqueIdentifier() -> String {
        let userDefaults = UserDefaults.standard
        if let uuid = userDefaults.string(forKey: "appUniqueIdentifier") {
            return uuid
        } else {
            let newUUID = UUID().uuidString
            userDefaults.set(newUUID, forKey: "appUniqueIdentifier")
            return newUUID
        }
    }

    var uid: String
    // APP ID from https://console.agora.io
    var appId: String
    /// Channel prefil text to join
    var channel: String
    /// Generate RTC Token at ...
    var token: String?
    /// Mode for encryption, choose from 1-8
    var encryptionMode: Int
    /// RTC encryption salt
    var salt: String
    /// RTC encryption key
    var cipherKey: String
    /// Add Proxy Server URL
    var proxyUrl: String
    /// Add Proxy Server Port
    var proxyPort: String
    /// Add Proxy Server Account
    var proxyAccount: String
    /// Add Proxy Server Password
    var proxyPassword: String
    /// Add Proxy type from "none", "tcp", "udp"
    var proxyType: String
    /// Add Token Generator URL
    var tokenUrl: String
}

enum RtcProducts: String, CaseIterable, Codable {
    case rtc
    case ils
    case voice
    var description: String {
        switch self {
        case .rtc: return "Video Calling"
        case .ils: return "Interactive Live Streaming"
        case .voice: return "Voice Calling"
        }
    }
}
