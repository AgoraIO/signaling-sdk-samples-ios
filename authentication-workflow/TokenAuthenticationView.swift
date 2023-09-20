//
//  TokenAuthenticationView.swift
//  Example-App
//
//  Created by Max Cobb on 11/08/2023.
//

import SwiftUI

extension SignalingManager {
    struct TokenResponse: Codable {
        var token: String
    }

    func fetchToken(from urlString: String, username: String, channelName: String? = nil) async throws -> String {
        guard let url = URL(string: urlString) else {
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
}

extension GetStartedSignalingManager {
    func loginAndSub(to channel: String, withTokenUrl tokenUrl: String) async throws {
        let token = try await fetchToken(from: tokenUrl, username: self.userId)

        await self.loginAndSub(to: channel, with: token)
    }
}

// MARK: - UI

struct TokenAuthenticationView: View {
    @ObservedObject var signalingManager: GetStartedSignalingManager
    let channelId: String
    let userId: String
    let tokenUrl: String

    var body: some View {
        ZStack {
            VStack {
                MessagesListView(
                    messages: $signalingManager.messages, localUser: self.userId
                ).padding()
                MessageInputView(publish: publish(message:))
            }
            ToastView(message: $signalingManager.label)
        }.onAppear {
            await self.viewAppeared()
        }.onDisappear {
            try? await signalingManager.destroy()
        }
    }

    // MARK: - Helpers and Setup

    func viewAppeared() async {
        do {
            try await signalingManager.loginAndSub(
                to: self.channelId, withTokenUrl: self.tokenUrl
            )
        } catch {
            signalingManager.label = "Could not fetch token\n\(error.localizedDescription)"
        }
    }

    func publish(message: String) async {
        await self.signalingManager.publish(
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
