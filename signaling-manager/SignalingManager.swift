//
//  SignalingManager.swift
//  Example-App
//
//  Created by Max Cobb on 01/08/2023.
//

import Foundation
import AgoraRtm

open class SignalingManager: NSObject, ObservableObject {
    /// The Agora App ID for the session.
    public let appId: String

    public let userId: String

    init(appId: String, userId: String) {
        self.appId = appId
        self.userId = userId
        super.init()
    }

    public var engine: RtmClientKit?
    /// The Agora Signaling Engine for the session.
    public var agoraEngine: RtmClientKit {
        if let engine { return engine }
        return setupEngine()
    }
    open func setupEngine() -> RtmClientKit {
        let config = RtmClientConfig(appId: self.appId, userId: self.userId)
        config.logConfig?.level = .error
        guard let eng = RtmClientKit(
            config: config, delegate: self as? RtmClientDelegate
        ) else {
            fatalError("could not create client engine: check parameters")
        }
        self.engine = eng
        return eng
    }

    @Published var label: String?

    @discardableResult
    func login(byToken token: String? = nil) async throws -> RtmCommonResponse {
        if token != nil { DocsAppConfig.shared.token = token }
        do {
            // First try logging in with the current temporary token
            return try await self.agoraEngine.login(byToken: DocsAppConfig.shared.token)
        } catch {
            guard let err = error as? RtmErrorInfo else { throw error }
            switch err.errorCode {
            case .invalidToken, .tokenExpired: // fetch a new token if there's a token URL
                if let newToken = try? await self.fetchToken(
                     from: DocsAppConfig.shared.tokenUrl,
                     username: DocsAppConfig.shared.uid,
                     channelName: DocsAppConfig.shared.channel
                ) {
                    // Set the new token, then try logging in once more with it
                    DocsAppConfig.shared.token = newToken
                    return try await self.agoraEngine.login(byToken: DocsAppConfig.shared.token)
                }
            default: break
            }
            throw err
        }
    }

    @discardableResult func destroy() async -> RtmErrorCode? {
        _ = try? await self.agoraEngine.logout()
        return self.agoraEngine.destroy()
    }
}
