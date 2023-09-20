//
//  GettingStartedView.swift
//  Example-App
//
//  Created by Max Cobb on 01/08/2023.
//

import SwiftUI
import AgoraRtm

/// Custom identifiable struct to store incoming and outgoing messages.
struct SignalingMessage: Identifiable {
    /// Content of the message
    var text: String
    /// Username of the sender
    var sender: String
    /// A random, unique ID for the message. These IDs are not synchonised.
    var id: UUID
}

public class GetStartedSignalingManager: SignalingManager, RtmClientDelegate {

    /// A collection of all sent and received messages, stored in a custom struct.
    @Published var messages: [SignalingMessage] = []

    /// Log into Signaling with a token, and subscribe to a message channel.
    /// - Parameters:
    ///   - channel: Channel name to subscribe to.
    ///   - token: token to be used for login authentication.
    public func loginAndSub(to channel: String, with token: String?) async {
        do {
            try await self.login(byToken: token)
            try await self.agoraEngine.subscribe(
                toChannel: channel, features: .messages
            )
            self.label = "success"
        } catch let err as RtmErrorInfo {
            await self.handleLoginSubError(error: err, channel: channel)
        } catch {
            print("other error occurred: \(error.localizedDescription)")
        }
    }

    /// Publish a message to a message channel.
    /// - Parameters:
    ///   - message: String to be sent to the channel. UTF-8 suppported 👋.
    ///   - channel: Channel name to publish the message to.
    public func publish(message: String, to channel: String) async {
        guard (try? await self.agoraEngine.publish(
            message: message,
            to: channel
        )) != nil else { return print("Could not publish message") }

        DispatchQueue.main.async {
            self.messages.append(
                SignalingMessage(text: message, sender: DocsAppConfig.shared.uid, id: .init())
            )
        }
    }

    public func rtmClient(
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
            label = "could not log in, check your app ID and token"
        case .channelSubscribeFailed, .channelSubscribeTimeout, .channelNotSubscribed:
            label = "could not subscribe to channel"
        case .invalidToken:
            if label == nil, let token = try? await self.fetchToken(
                from: DocsAppConfig.shared.tokenUrl,
                username: DocsAppConfig.shared.uid
            ) {
                label = "fetching token"
                await self.loginAndSub(to: channel, with: token)
            }
        default:
            DispatchQueue.main.async {
                self.label = "failed: \(error.operation)\nreason: \(error.reason)"
            }
        }

    }
}

// MARK: - UI

struct GettingStartedView: View {
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

    static var docPath: String = "get-started-sdk"
    static var docTitle: String = "Get Started SDK"
}

// MARK: - Previews

struct GettingStartedView_Previews: PreviewProvider {
    static var previews: some View {
        GettingStartedView(
            channelId: DocsAppConfig.shared.channel,
            userId: DocsAppConfig.shared.uid
        )
    }
}
