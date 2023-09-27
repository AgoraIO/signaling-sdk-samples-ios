//
//  GettingStartedView.swift
//  Example-App
//
//  Created by Max Cobb on 01/08/2023.
//

import SwiftUI
import AgoraRtm

public class StorageSignalingManager: SignalingManager, RtmClientDelegate {

    /// A collection of all sent and received messages, stored in a custom struct.
    @Published var messages: [SignalingMessage] = []

    /// Log into Signaling with a token, and subscribe to a message channel.
    /// - Parameters:
    ///   - channel: Channel name to subscribe to.
    ///   - token: token to be used for login authentication.
    public func loginAndSub(to channel: String, with token: String?) async {
        do {
            try await self.login(byToken: token)
            try await self.signalingEngine.subscribe(
                toChannel: channel, features: .messages
            )
            await self.updateLabel(to: "success")
        } catch let err as RtmErrorInfo {
            await self.handleLoginSubError(error: err, channel: channel)
        } catch {
            print("other error occurred: \(error.localizedDescription)")
        }
    }

    @Published var localMetadata: [String: String] = [:]

    public func setUserInfo(to localData: [String: String]) async throws {
        self.localMetadata = localData

        guard let userMd = try await self.signalingEngine.storage?.getUserMetadata(
            userId: self.userId
        )?.data else { return }

        userMd.setMetadataItems(localData)
        _ = try await self.signalingEngine.storage?.setUserMetadata(
            userId: self.userId, data: userMd
        )
    }

    public func removeUserInfo(for keys: [String]) async throws {
        guard let removeMetadata = signalingEngine.storage?
            .createMetadata() else { return }

        keys.forEach { key in
            removeMetadata.setMetadataItem(.init(key: key, value: ""))
        }

        _ = try await signalingEngine.storage?.removeUserMetadata(
            userId: self.userId, data: removeMetadata
        )
    }

    public func rtmKit(
        _ rtmClient: RtmClientKit, didReceiveMessageEvent event: RtmMessageEvent
    ) {
        switch event.message.content {
        case .string(let str):
            DispatchQueue.main.async {
                self.messages.append(SignalingMessage(
                    text: str, sender: event.publisher, id: .init()
                ))
            }
        case .data(let data):
            print("other data object in message: \(data)")
        }
    }

    // MARK: Handle Errors
    /// Handle different error cases, and fetch a new token if appropriate.
    /// - Parameters:
    ///   - error: Error thrown by logging in or subscribing to a channel.
    ///   - channel: Channel to which a subscription was attempted.
    func handleLoginSubError(error: RtmErrorInfo, channel: String) async {
        switch error.errorCode {
        case .loginNoServerResources, .loginTimeout, .loginRejected, .loginAborted:
            await self.updateLabel(to: "could not log in, check your app ID and token")
        case .channelSubscribeFailed, .channelSubscribeTimeout, .channelNotSubscribed:
            await self.updateLabel(to: "could not subscribe to channel")
        case .invalidToken:
            if label == nil, let token = try? await self.fetchToken(
                from: DocsAppConfig.shared.tokenUrl,
                username: DocsAppConfig.shared.uid
            ) {
                await self.updateLabel(to: "fetching token")
                await self.loginAndSub(to: channel, with: token)
            }
        default:
            await self.updateLabel(to: """
            failed: \(error.operation)
            reason: \(error.reason)
            """)
        }

    }
}

// MARK: - UI

struct StorageView: View {
    @ObservedObject var signalingManager: GetStartedSignalingManager
    let channelId: String

    var body: some View {
        ZStack {
            VStack {
                MessagesListView(
                    messages: $signalingManager.messages,
                    localUser: signalingManager.userId
                ).padding()
                MessageInputView(publish: publish(message:))
            }
            ToastView(message: $signalingManager.label)
        }.onAppear {
            await signalingManager.loginAndSub(
                to: self.channelId, with: DocsAppConfig.shared.token
            )
        }.onDisappear { try? await signalingManager.destroy() }
    }

    // MARK: - Helpers and Setup

    func publish(message: String) async {
        await self.signalingManager.publish(
            message: message, to: self.channelId
        )
    }

    init(channelId: String, userId: String) {
        DocsAppConfig.shared.channel = channelId
        DocsAppConfig.shared.uid = userId

        self.channelId = channelId
        self.signalingManager = GetStartedSignalingManager(
            appId: DocsAppConfig.shared.appId, userId: userId
        )
    }

    static var docPath: String = "storage"
    static var docTitle: String = "Store channel and user data"
}

// MARK: - Previews

struct StorageView_Previews: PreviewProvider {
    static var previews: some View {
        GettingStartedView(
            channelId: DocsAppConfig.shared.channel,
            userId: DocsAppConfig.shared.uid
        )
    }
}
