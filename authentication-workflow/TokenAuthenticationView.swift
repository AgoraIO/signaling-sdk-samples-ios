//
//  TokenAuthenticationView.swift
//  Example-App
//
//  Created by Max Cobb on 11/08/2023.
//

import SwiftUI
import AgoraRtm

extension SignalingManager {
    struct TokenResponse: Codable {
        var token: String
    }

    var tokenUrl: String {
        DocsAppConfig.shared.tokenUrl
    }

    func fetchToken(from urlString: String, username: String, channelName: String? = nil) async throws -> String {
        guard let url = URL(string: "\(urlString)/getToken") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        var userData = [
            "tokenType": "rtm",
            "uid": username
        ]

        // This is used only for stream channels
        if let channelName {
            userData["channel"] = channelName
        }

        let requestData = try JSONEncoder().encode(userData)
        request.httpBody = requestData

        let (data, _) = try await URLSession.shared.data(for: request)
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

        return tokenResponse.token
    }

    func loginMessageChannel(tokenUrl: String, username: String) async throws {
        let token = try await self.fetchToken(
            from: tokenUrl, username: username
        )

        try await self.signalingEngine.login(byToken: token)
    }

    func loginStreamChannel(tokenUrl: String, username: String, streamChannel: String) async throws {
        let token = try await self.fetchToken(
            from: tokenUrl, username: username, channelName: streamChannel
        )

        let channel = try self.signalingEngine.createStreamChannel(streamChannel)
        let joinOption = RtmJoinChannelOption(token: token, features: [.presence])
        try await channel.join(with: joinOption)
    }
}

extension GetStartedSignalingManager {
    func loginAndSub(to channel: String, withTokenUrl tokenUrl: String) async throws {
        let token = try await fetchToken(from: tokenUrl, username: self.userId)

        await self.loginAndSub(to: channel, with: token)
    }

    public func rtmKit(_ rtmClient: RtmClientKit, tokenPrivilegeWillExpire channel: String?) {
        Task {
            let token = try await self.fetchToken(from: self.tokenUrl, username: self.userId)
            try await signalingEngine.renewToken(token)
        }
    }
}

// MARK: - UI

struct TokenAuthenticationView: View {
    @ObservedObject var signalingManager: GetStartedSignalingManager
    let channelId: String
    let userId: String
    let tokenUrl: String
    @State var presenceViewPresented: Bool = false

    var body: some View {
        ZStack {
            VStack {
                MessagesListView(
                    messages: $signalingManager.messages, localUser: self.userId
                ).padding()
                PresenceButtonView(
                    presenceViewPresented: $presenceViewPresented,
                    remoteCount: Binding(
                        get: { self.signalingManager.remoteUsers.count },
                        set: { _ in }
                    )
                )
                MessageInputView(publish: publish(message:))
            }
            ToastView(message: $signalingManager.label)
        }.onAppear {
            await self.viewAppeared()
        }.onDisappear {
            try? await signalingManager.destroy()
        }.sheet(isPresented: self.$presenceViewPresented) {
            RemoteUsersView(remoteUsers: $signalingManager.remoteUsers)
        }
    }

    // MARK: - Helpers and Setup

    func viewAppeared() async {
        do {
            try await signalingManager.loginAndSub(
                to: self.channelId, withTokenUrl: self.tokenUrl
            )
        } catch {
            signalingManager.updateLabel(to: "Could not fetch token\n\(error.localizedDescription)")
        }
    }

    func publish(message: String) async {
        await self.signalingManager.publishAndRecord(
            message: message, to: self.channelId
        )
    }

    init(channelId: String, userId: String, tokenUrl: String) {
        DocsAppConfig.shared.channel = channelId
        DocsAppConfig.shared.uid = userId
        DocsAppConfig.shared.tokenUrl = tokenUrl
        self.channelId = channelId
        self.userId = userId
        self.tokenUrl = tokenUrl
        self.signalingManager = GetStartedSignalingManager(
            appId: DocsAppConfig.shared.appId, userId: userId
        )
    }

    static var docPath: String = "authentication-workflow"
    static var docTitle: String = "Secure authentication with tokens"
}

struct TokenAuthenticationView_Previews: PreviewProvider {
    static var previews: some View {
        TokenAuthenticationView(
            channelId: "test", userId: DocsAppConfig.shared.uid,
            tokenUrl: DocsAppConfig.shared.tokenUrl
        )
    }
}
