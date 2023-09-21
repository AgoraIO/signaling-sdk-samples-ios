//
//  TokenUrlInputView.swift
//  Example-App
//
//  Created by Max Cobb on 16/08/2023.
//

import SwiftUI
import AgoraRtm

/// A protocol for views that require a `channelId` string as input.
protocol HasTokenUrlInput: HasDocPath {
    init(channelId: String, userId: String, tokenUrl: String)
}

extension TokenAuthenticationView: HasTokenUrlInput {}

struct TokenUrlInputView<Content: HasTokenUrlInput>: View {
    /// The user inputted `channelId` string.
    @State var channelId: String = ""
    /// The user inputted `userId` string for logging in.
    @State var userId: String = ""
    /// The user inputted `tokenUrl` for fetching tokens.
    @State var tokenUrl: String = ""
    /// The type of view to navigate to.
    var continueTo: Content.Type

    #if os(macOS)
    // URL only available on macOS 14+.
    let textType: NSTextContentType? = .none
    #else
    let textType: UITextContentType = .URL
    #endif

    var body: some View {
        VStack {
            VStack(alignment: .leading) {
                Text("Username")
                TextField("Enter username", text: $userId)
                    .textContentType(.username).textFieldStyle(.roundedBorder).autocorrectionDisabled()
                Text("Channel ID")
            TextField("Enter channel id", text: $channelId)
                    .textContentType(.username).textFieldStyle(.roundedBorder).autocorrectionDisabled()
                Text("Token URL")
            TextField("Enter token URL", text: $tokenUrl)
                    .textContentType(self.textType).textFieldStyle(.roundedBorder).autocorrectionDisabled()
            }.padding([.leading, .trailing])

            NavigationLink(destination: NavigationLazyView(continueTo.init(
                channelId: channelId.trimmingCharacters(in: .whitespaces),
                userId: userId.trimmingCharacters(in: .whitespaces),
                tokenUrl: tokenUrl.trimmingCharacters(in: .whitespaces)
            ).navigationTitle(continueTo.docTitle).toolbar {
                ToolbarItem(placement: .automatic) {
//                    GitHubButtonView(continueTo.docPath)
                }
            }), label: {
                Text("Continue")
            }).disabled(channelId.isEmpty || userId.isEmpty)
                .buttonStyle(.borderedProminent)
                .navigationTitle("Channel Input")
        }.onChange(of: channelId) { newVal in
            if let filtered = self.filter(
                string: newVal, by: RtmLegalCharacterSets.channelName
            ) { channelId = filtered }
        }.onChange(of: userId) { newVal in
            if let filtered = self.filter(
                string: newVal, by: RtmLegalCharacterSets.username
            ) { userId = filtered }
        }.onAppear {
            channelId = DocsAppConfig.shared.channel
            userId = DocsAppConfig.shared.uid
            tokenUrl = DocsAppConfig.shared.tokenUrl
        }
    }
}

struct TokenUrlInputView_Previews: PreviewProvider {
    static var previews: some View {
        TokenUrlInputView(continueTo: TokenAuthenticationView.self)
    }
}