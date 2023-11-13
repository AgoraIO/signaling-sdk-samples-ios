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

    /// Publish a message to a message channel.
    /// - Parameters:
    ///   - message: String to be sent to the channel. UTF-8 suppported 👋.
    ///   - channel: Channel name to publish the message to.
    public func publishAndRecord(message: String, to channel: String) async {
        guard (try? await super.publish(message: message, to: channel)) != nil else {
            return
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
        await self.signalingManager.publishAndRecord(
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

#Preview {
    GettingStartedView(
        channelId: DocsAppConfig.shared.channel,
        userId: DocsAppConfig.shared.uid
    )
}
