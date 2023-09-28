//
//  GettingStartedView.swift
//  Example-App
//
//  Created by Max Cobb on 01/08/2023.
//

import SwiftUI
import AgoraRtm

public protocol DisplayMessage: Identifiable {
    var text: String { get }
    var sender: String { get }
    var id: UUID { get }
}

#if canImport(AppKit)
import AppKit
extension NSColor {
    static var systemBackground: NSColor { NSColor.windowBackgroundColor }
}
#endif

/// Custom identifiable struct to store incoming and outgoing messages.
public struct SignalingMessage: DisplayMessage {
    /// Content of the message
    public var text: String
    /// Username of the sender
    public var sender: String
    /// A random, unique ID for the message. These IDs are not synchonised.
    public var id: UUID
}

public class GetStartedSignalingManager: SignalingManager, RtmClientDelegate {

    /// A collection of all sent and received messages, stored in a custom struct.
    @Published var messages: [SignalingMessage] = []

    @Published var remoteUsers: Set<String> = []

    /// Log into Signaling with a token, and subscribe to a message channel.
    /// - Parameters:
    ///   - channel: Channel name to subscribe to.
    ///   - token: token to be used for login authentication.
    public func loginAndSub(to channel: String, with token: String?) async {
        do {
            try await self.login(byToken: token)
            try await self.signalingEngine.subscribe(
                toChannel: channel, features: [.messages, .presence]
            )
            await self.updateLabel(to: "success")
        } catch let err as RtmErrorInfo {
            await self.handleLoginSubError(error: err, channel: channel)
        } catch {
            await self.updateLabel(to: "other error occurred: \(error.localizedDescription)")
        }
    }

    /// Publish a message to a message channel.
    /// - Parameters:
    ///   - message: String to be sent to the channel. UTF-8 suppported 👋.
    ///   - channel: Channel name to publish the message to.
    public func publish(message: String, to channel: String) async {
        do {
            try await self.signalingEngine.publish(
                message: message,
                to: channel
            )
        } catch let err as RtmErrorInfo {
            return await self.updateLabel(to: "Could not publish message: \(err.reason)")
        } catch {
            await self.updateLabel(to: "Unknown error: \(error.localizedDescription)")
        }

        DispatchQueue.main.async {
            self.messages.append(
                SignalingMessage(text: message, sender: DocsAppConfig.shared.uid, id: .init())
            )
        }
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

    public func rtmKit(_ rtmClient: RtmClientKit, didReceivePresenceEvent event: RtmPresenceEvent) {
        DispatchQueue.main.async {
            switch event.type {
            case .remoteJoinChannel(let publisher):
                // remote user joined channel
                self.remoteUsers.insert(publisher)
            case .remoteLeaveChannel(let publisher):
                // remote user left channel
                self.remoteUsers.remove(publisher)
            case .snapshot(let snapshot):
                // local user joined or reconnected to channel
                // snapshot shows everyone in the channel and their states
                self.remoteUsers = Set(snapshot.keys).filter {
                    $0 != self.userId
                }
            default: break
            }
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
            await self.updateLabel(to: "failed: \(error.operation)\nreason: \(error.reason)")
        }

    }
}

// MARK: - UI

struct GettingStartedView: View {
    @ObservedObject var signalingManager: GetStartedSignalingManager
    let channelId: String
    @State var presenceViewPresented: Bool = false

    var body: some View {
        ZStack {
            VStack {
                MessagesListView(
                    messages: $signalingManager.messages,
                    localUser: signalingManager.userId
                ).padding()

                // Presence of others in the meeting
                PresenceButtonView(presenceViewPresented: self.$presenceViewPresented, remoteCount: Binding(
                    get: { self.signalingManager.remoteUsers.count },
                    set: { _ in }
                ))

                MessageInputView(publish: publish(message:))
            }
            ToastView(message: $signalingManager.label)
        }.onAppear {
            await signalingManager.loginAndSub(
                to: self.channelId, with: DocsAppConfig.shared.token
            )
        }.onDisappear { try? await signalingManager.destroy()
        }.sheet(isPresented: self.$presenceViewPresented) {
            RemoteUsersView(remoteUsers: $signalingManager.remoteUsers)
        }
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
