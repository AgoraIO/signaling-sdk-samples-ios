//
//  CloudProxyInputView.swift
//  Example-App
//
//  Created by Max Cobb on 27/10/2023.
//

import SwiftUI
import AgoraRtm

/// A protocol for views relating to cloud proxy for this demo app.
///
/// This protocol requires the init parameters:
///   - channelId
///   - userId
///   - proxyServer
///   - proxyPort
///   - proxyAccount
///   - proxyPassword
protocol HasCloudProxyInput: HasDocPath {
    init(
        channelId: String, userId: String,
        proxyServer: String, proxyPort: UInt16,
        proxyAccount: String?, proxyPassword: String?
    )
}


extension CloudProxyView: HasCloudProxyInput {}

/// A view that takes a user inputted `channelId` string and navigates to a view
/// which conforms to the `HasChannelInput` protocol.
///
/// The generic parameter `Content` specifies the type of view to navigate to,
/// and must conform to the `HasChannelInput` protocol.
struct CloudProxyInputView<Content: HasCloudProxyInput>: View {
    /// The user inputted `channelId` string.
    @State var channelId: String = ""
    /// The user inputted `userId` string for logging in.
    @State var userId: String = ""

    /// The user inputted `proxyUrl` string for cloud proxy.
    @State var proxyUrl: String = ""
    /// The user inputted `proxyPort` string for cloud proxy.
    @State var proxyPort: String = ""
    /// The user inputted `proxyAccount` string for cloud proxy.
    @State var proxyAccount: String = ""
    /// The user inputted `proxyPassword` string for cloud proxy.
    @State var proxyPassword: String = ""
    /// The type of view to navigate to.
    var continueTo: Content.Type

    var body: some View {
        VStack {
            VStack(alignment: .leading) {
                Text("Username")
                TextField("Enter username", text: $userId)
                    .textContentType(.username).textFieldStyle(.roundedBorder)
                Text("Channel ID")
                TextField("Enter channel id", text: $channelId)
                    .textContentType(.username).textFieldStyle(.roundedBorder)

                TextField("Proxy URL", text: $proxyUrl)
                    .textContentType(.URL).textFieldStyle(.roundedBorder)
                TextField("Proxy Port", text: $proxyPort)
                    .textContentType(.creditCardNumber).textFieldStyle(.roundedBorder)
                TextField("Proxy Account", text: $proxyAccount)
                    .textContentType(.username).textFieldStyle(.roundedBorder)
                TextField("Proxy Password", text: $proxyPassword)
                    .textContentType(.password).textFieldStyle(.roundedBorder)
            }.padding([.leading, .trailing])

            let proxyPassword: String? = proxyPassword.isEmpty ? nil : proxyPassword
            let proxyAccount: String? = proxyAccount.isEmpty ? nil : proxyAccount
            NavigationLink(destination: NavigationLazyView(continueTo.init(
                channelId: channelId.trimmingCharacters(in: .whitespaces),
                userId: userId.trimmingCharacters(in: .whitespaces),
                proxyServer: proxyUrl, proxyPort: UInt16(proxyPort) ?? 8080,
                proxyAccount: proxyAccount, proxyPassword: proxyPassword

            ).navigationTitle(continueTo.docTitle).toolbar {
                ToolbarItem(placement: .automatic) {
//                    GitHubButtonView(continueTo.docPath)
                }
            }), label: {
                Text("Continue")
            }).disabled(channelId.isEmpty || userId.isEmpty)
                .buttonStyle(.borderedProminent)
                .navigationTitle("Channel Input")
        }.onChange(of: channelId, initial: false) { (oldVal, newVal) in
            if oldVal.contains(newVal) { return }
            if let filtered = self.filter(
                string: newVal, by: RtmLegalCharacterSets.channelName
            ) { channelId = filtered }
        }.onChange(of: userId, initial: false) { (oldVal, newVal) in
            if oldVal.contains(newVal) { return }
            if let filtered = self.filter(
                string: newVal, by: RtmLegalCharacterSets.username
            ) { userId = filtered }
        }.onAppear {
            channelId = DocsAppConfig.shared.channel
            userId = DocsAppConfig.shared.uid
        }
    }
}

#Preview {
    CloudProxyInputView(continueTo: CloudProxyView.self)
}
