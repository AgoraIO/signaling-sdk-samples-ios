//
//  GettingStartedView.swift
//  Example-App
//
//  Created by Max Cobb on 01/08/2023.
//

import SwiftUI
import AgoraRtm

struct SignalingMessage: Identifiable {
    var text: String
    var sender: String
    var id: UUID
}

public class GetStartedSignalingManager: SignalingManager, RtmClientDelegate {

    @Published var messages: [SignalingMessage] = []

    func loginAndSub(to channel: String, with token: String?) async {
        do {
            try await self.agoraEngine.login(byToken: token)
            try await self.agoraEngine.subscribe(
                toChannel: channel, features: .messages
            )
        } catch let err as RtmBaseErrorInfo {
            switch err.errorCode {
            case .loginNoServerResources, .loginTimeout, .loginRejected, .loginAborted:
                label = "could not log in, check your app ID and token"
            case .channelSubscribeFailed, .channelSubscribeTimeout, .channelNotSubscribed:
                label = "could not subscribe to channel"
            default:
                label = "failed: \(err.operation)\nreason: \(err.reason)"
            }
        } catch { print("other error occurred: \(error.localizedDescription)") }
    }

    func publish(message: String, to channel: String) async {
        guard (try? await self.agoraEngine.publish(
            message: message,
            to: channel
        )) != nil else { return print("Could not publish message") }

        self.messages.append(
            SignalingMessage(text: message, sender: "", id: .init())
        )
    }

    public func rtmClient(
        _ rtmClient: RtmClientKit, didReceiveMessageEvent event: RtmMessageEvent
    ) {
        guard let str = event.message.getString() else {
            return print("invalid message")
        }
        self.messages.append(SignalingMessage(text: str, sender: event.publisher, id: .init()))
    }
}

struct GettingStartedView: View {
    @ObservedObject var signalingManager: GetStartedSignalingManager
    let channelId: String
    let userId: String

    var body: some View {
        ZStack {
            VStack {
                MessagesListView(messages: $signalingManager.messages, localUser: self.userId).padding()
                MessageInputView(publish: publish(message:))
            }
            if let label = self.signalingManager.label {
                Text(label).multilineTextAlignment(.center).padding()
                    .background(Color.secondary).cornerRadius(5)
            }
        }.onAppear {
            await signalingManager.loginAndSub(to: self.channelId, with: DocsAppConfig.shared.token)
        }.onDisappear {
            _ = try? await signalingManager.engine?.logout()
        }
    }

    func publish(message: String) async {
        await self.signalingManager.publish(
            message: message, to: self.channelId
        )
    }

    init(channelId: String, userId: String) {
        self.channelId = channelId
        self.userId = userId
        self.signalingManager = GetStartedSignalingManager(
            appId: DocsAppConfig.shared.appId, userId: userId
        )
    }

    static var docPath: String = "get-started-sdk"
    static var docTitle: String = "Get Started SDK"
}

struct GettingStartedView_Previews: PreviewProvider {
    static var previews: some View {
        GettingStartedView(channelId: "test", userId: "Bob")
    }
}
