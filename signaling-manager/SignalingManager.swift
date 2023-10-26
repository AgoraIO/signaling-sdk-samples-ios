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
    public var signalingEngine: RtmClientKit {
        if let engine { return engine }
        return setupEngine()
    }
    open func setupEngine() -> RtmClientKit {
        let config = RtmClientConfig(appId: self.appId, userId: self.userId)
        config.logConfig?.level = .error
        guard let eng = try? RtmClientKit(
            config: config, delegate: self as? RtmClientDelegate
        ) else {
            fatalError("could not create client engine: check parameters")
        }
        self.engine = eng
        return eng
    }

    /// For displaying error messages etc.
    @Published var label: String?

    @MainActor
    func updateLabel(to message: String) {
        self.label = message
    }

    @discardableResult
    func login(byToken token: String? = nil) async throws -> RtmCommonResponse {
        if token != nil { DocsAppConfig.shared.token = token }
        do {
            // First try logging in with the current temporary token
            return try await self.signalingEngine.login(byToken: DocsAppConfig.shared.token)
        } catch {
            guard let err = error as? RtmErrorInfo else { throw error }
            switch err.errorCode {
            case .invalidToken, .tokenExpired: // fetch a new token if there's a token URL
//                try? await self.agoraEngine.logout()
                if let newToken = try? await self.fetchToken(
                     from: DocsAppConfig.shared.tokenUrl,
                     username: DocsAppConfig.shared.uid
                ) {
                    // Set the new token, then try logging in once more with it
                    DocsAppConfig.shared.token = newToken
                    return try await self.signalingEngine.login(byToken: newToken)
                }
            default: break
            }
            throw err
        }
    }

    /// Log into Signaling with a token, and subscribe to a message channel.
    /// - Parameters:
    ///   - channel: Channel name to subscribe to.
    ///   - token: token to be used for login authentication.
    public func loginAndSub(to channel: String, with token: String?) async {
        do {
            try await self.login(byToken: token)
            try await self.subscribe(to: channel)
            await self.updateLabel(to: "success")
        } catch let err as RtmErrorInfo {
            await self.handleLoginSubError(error: err, channel: channel, tryloginAgain: loginAndSub(to:with:))
        } catch {
            await self.updateLabel(to: "other error occurred: \(error.localizedDescription)")
        }
    }

    @discardableResult
    func subscribe(to channel: String) async throws -> RtmCommonResponse {
        try await self.signalingEngine.subscribe(
            toChannel: channel,
            features: [.messages, .presence]
        )
    }

    func destroy() async throws {
        try await self.signalingEngine.logout()
        try self.signalingEngine.destroy()
    }

    // MARK: Handle Errors
    /// Handle different error cases, and fetch a new token if appropriate.
    /// - Parameters:
    ///   - error: Error thrown by logging in or subscribing to a channel.
    ///   - channel: Channel to which a subscription was attempted.
    func handleLoginSubError(
        error: RtmErrorInfo, channel: String,
        tryloginAgain: ((String, String) async -> Void)? = nil
    ) async {
        switch error.errorCode {
        case .loginNoServerResources, .loginTimeout, .loginRejected, .loginAborted:
            await self.updateLabel(to: "could not log in, check your app ID and token")
        case .channelSubscribeFailed, .channelSubscribeTimeout, .channelNotSubscribed:
            await self.updateLabel(to: "could not subscribe to channel")
        case .invalidToken:
            if let tryloginAgain, label == nil, let token = try? await self.fetchToken(
                from: DocsAppConfig.shared.tokenUrl,
                username: DocsAppConfig.shared.uid
            ) {
                await self.updateLabel(to: "fetching token")
                await tryloginAgain(channel, token)
            }
        default:
            await self.updateLabel(to: "failed: \(error.operation)\nreason: \(error.reason)")
        }
    }

}
