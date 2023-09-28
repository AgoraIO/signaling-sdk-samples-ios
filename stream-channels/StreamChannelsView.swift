//
//  GettingStartedView.swift
//  Example-App
//
//  Created by Max Cobb on 01/08/2023.
//

import SwiftUI
import AgoraRtm

public class StreamChannelSignalingManager: SignalingManager, RtmClientDelegate {

    /// A collection of all sent and received messages, stored in a custom struct.
    @Published var messages: [SignalingMessage] = []

    @Published var topics: [String] = []

    internal var streamChannel: RtmStreamChannel?

    /// Log into Signaling with a token, and subscribe to a message channel.
    /// - Parameters:
    ///   - channel: Channel name to subscribe to.
    ///   - token: token to be used for login authentication.
    public func loginAndJoin(streamChannel channelName: String, with token: String?) async {
        do {
            try await self.login(byToken: token)

            // Get stream channel token
            var streamChannelToken: String?
            if !DocsAppConfig.shared.tokenUrl.isEmpty {
                streamChannelToken = try? await self.fetchToken(
                     from: DocsAppConfig.shared.tokenUrl,
                     username: DocsAppConfig.shared.uid,
                     channelName: channelName
                )
            }

            // Create stream channel
            guard let streamChannel = try signalingEngine
                .createStreamChannel(channelName) else {
                return await self.updateLabel(to: "creating stream channel failed")
            }

            // Join Stream Channel
            _ = try await streamChannel.join(with: RtmJoinChannelOption(
                token: streamChannelToken, features: [.presence]
            ))
            self.streamChannel = streamChannel

            await self.updateLabel(to: "success")
        } catch let err as RtmErrorInfo {
            await self.handleLoginSubError(error: err, channel: channelName)
        } catch {
            await self.updateLabel(to: "other error occurred: \(error.localizedDescription)")
        }
    }

    func joinTopic(named topic: String) async throws {
        try await self.streamChannel?.joinTopic(
            topic, with: RtmJoinTopicOption(qos: .ordered)
        )
        print("self.streamChannel")
        print(self.streamChannel)
    }

    func subTopic(named topic: String) async throws {
        try await self.streamChannel?.subscribe(toTopic: topic)
    }

    func unsubTopic(named topic: String) async throws {
        try await self.streamChannel?.unsubscribe(fromTopic: topic)
    }

    func leaveTopic(named topic: String) async throws {
        try await self.streamChannel?.leaveTopic(topic)
        DispatchQueue.main.async {
            self.topics = self.topics.filter { $0 != topic }
        }
    }

    /// Publish a message to a message channel.
    /// - Parameters:
    ///   - message: String to be sent to the channel. UTF-8 suppported 👋.
    ///   - channel: Channel name to publish the message to.
    public func publish(message: String, in channel: RtmStreamChannel, to topic: String) async {
        do {
            _ = try await self.streamChannel?.publishTopicMessage(
                message: message, inTopic: topic, with: nil
            )
        } catch let err as RtmErrorInfo {
            return await self.updateLabel(to: "Could not publish message: \(err.reason)")
        } catch {
            return await self.updateLabel(to: "Unknown error: \(error.localizedDescription)")
        }
        DispatchQueue.main.async {
            self.messages.append(
                SignalingMessage(
                    text: "[\(topic)]\n\(message)",
                    sender: DocsAppConfig.shared.uid,
                    id: .init()
                )
            )
        }
    }

    public func rtmKit(
        _ rtmClient: RtmClientKit, didReceiveMessageEvent event: RtmMessageEvent
    ) {
        switch event.message.content {
        case .string(let str):
            DispatchQueue.main.async {
                var message = str
                if let topic = event.channelTopic {
                    message = "[\(topic)]\n\(message)"
                }
                self.messages.append(SignalingMessage(
                    text: message, sender: event.publisher, id: .init()
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
            if self.label == nil {
                await self.updateLabel(to: "fetching token")
                if let token = try? await self.fetchToken(
                    from: DocsAppConfig.shared.tokenUrl,
                    username: DocsAppConfig.shared.uid, channelName: channel
                ) {
                    _ = try? await self.signalingEngine.logout()
                    await self.loginAndJoin(streamChannel: channel, with: token)
                }
            } else {
                await self.updateLabel(to: "token fetch failed twice")
            }
        default:
            await self.updateLabel(to: "failed: \(error.operation)\nreason: \(error.reason)")
        }
    }

    override func destroy() async throws {
        _ = try await streamChannel?.leave()
        try await super.destroy()
    }
}

// MARK: - UI

struct StreamChannelsView: View {
    @ObservedObject var signalingManager: StreamChannelSignalingManager
    let channelId: String

    @State private var showingAddTopicView: Bool = false
    @State private var selectedTopic: String?

    var body: some View {
        ZStack {
            VStack {
                ScrollView(.horizontal) { HStack {
                    topicSections
                } }.padding([.leading, .trailing]).frame(maxHeight: 30)
                MessagesListView(
                    messages: $signalingManager.messages,
                    localUser: signalingManager.userId
                ).padding()
                HStack {
                    if !signalingManager.topics.isEmpty {
                        Picker("Send to:", selection: $selectedTopic) {
                            Text("Select a topic").tag(nil as String?)
                            ForEach(signalingManager.topics, id: \.self) { topic in
                                Text(topic).tag(topic as String?)
                            }
                        }.pickerStyle(.menu)
                            .frame(maxWidth: 200, maxHeight: 30)
                            .padding(.leading)
                    }
                    Spacer()
                }
                MessageInputView(publish: publish(message:)).disabled(self.selectedTopic == nil)
            }
            if signalingManager.topics.isEmpty {
                Text("Add a topic first")
            }
            ToastView(message: $signalingManager.label)
        }.onAppear {
            await signalingManager.loginAndJoin(streamChannel: self.channelId, with: DocsAppConfig.shared.token
            )
        }.onDisappear {
            try? await signalingManager.destroy()
        }.sheet(isPresented: $showingAddTopicView) {
            // 3. Present the add topic view
            AddTopicView { newTopic in
                DispatchQueue.main.async {
                    signalingManager.topics.append(newTopic)
                    showingAddTopicView = false
                    Task {
                        do {
                            try await signalingManager.joinTopic(named: newTopic)
                            try await signalingManager.subTopic(named: newTopic)
                            print("topic joined: \"\(newTopic)\"")
                        } catch let err as RtmErrorInfo {
                            signalingManager.updateLabel(to: "Could not join topic: \(err.reason)")
                        } catch {
                            signalingManager.updateLabel(
                                to: "\(#function): Unknown error: \(error.localizedDescription)"
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers and Setup

    @ViewBuilder
    var topicSections: some View {
        ForEach(signalingManager.topics, id: \.self) { topic in
            Button(action: {
                Task {
                    try await self.signalingManager.unsubTopic(named: topic)
                    try await self.signalingManager.leaveTopic(named: topic)
                }
            }, label: {
                HStack {
                    Image(systemName: "x.circle.fill")
                    Text(topic)
                }
            }).padding(3).buttonBorderShape(.roundedRectangle)
                .background(Color.accentColor.opacity(0.3))
                .cornerRadius(5)
        }
        Button {
            showingAddTopicView = true
        } label: {
            Text("+ Topic")
        }
    }

    func publish(message: String) async {
        guard let streamChannel = signalingManager.streamChannel else {
            return self.signalingManager.updateLabel(
                to: "Stream channel not initialised")
        }
        guard let selectedTopic else {
            return self.signalingManager.updateLabel(
                to: "Topic not selected")
        }
        await self.signalingManager.publish(
            message: message, in: streamChannel, to: selectedTopic
        )
    }

    init(channelId: String, userId: String) {
        DocsAppConfig.shared.channel = channelId
        DocsAppConfig.shared.uid = userId

        self.channelId = channelId
        self.signalingManager = StreamChannelSignalingManager(
            appId: DocsAppConfig.shared.appId, userId: userId
        )
    }

    static var docPath: String = "stream-channels"
    static var docTitle: String = "Stream channels"
}

struct AddTopicView: View {
    @State private var newTopic: String = ""
    let onAdd: (String) -> Void

    var body: some View {
        VStack(spacing: 20) {
            TextField("Enter topic name", text: $newTopic)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)

            Button("Add Topic") {
                if !newTopic.isEmpty {
                    onAdd(newTopic)
                }
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }.padding()
    }
}

// MARK: - Previews

struct StreamChannelsView_Previews: PreviewProvider {
    static var previews: some View {
        GettingStartedView(
            channelId: DocsAppConfig.shared.channel,
            userId: DocsAppConfig.shared.uid
        )
    }
}
