//
//  DataEncryptionInputView.swift
//  Example-App
//
//  Created by Max Cobb on 27/10/2023.
//

import SwiftUI
import AgoraRtm

/// A protocol for views that require a `channelId` string as input.
protocol HasDataEncryptionInput: HasDocPath {
    init(
        channelId: String, userId: String,
        encryptionKey: String, encryptionSalt: String
    )
}

extension DataEncryptionView: HasDataEncryptionInput {}

/// A view that takes a user inputted `channelId` and encryption data, and navigates to a view
/// which conforms to the `HasDataEncryptionInput` protocol.
///
/// The generic parameter `Content` specifies the type of view to navigate to,
/// and must conform to the `HasDataEncryptionInput` protocol.
struct DataEncryptionInputView<Content: HasDataEncryptionInput>: View {
    /// The user inputted `channelId` string.
    @State var channelId: String = ""
    /// The user inputted `userId` string for logging in.
    @State var userId: String = ""

    /// The user inputted `encryptionKey` string for encrypting data.
    @State var encryptionKey: String = ""
    /// The user inputted `encryptionSalt` string for encrypting data.
    @State var encryptionSalt: String = ""
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

                TextField("Encryption Key", text: $encryptionKey)
                    .textContentType(.username).textFieldStyle(.roundedBorder)
                TextField("Encryption Salt", text: $encryptionSalt)
                    .textContentType(.username).textFieldStyle(.roundedBorder)
            }.padding([.leading, .trailing])

            NavigationLink(destination: NavigationLazyView(continueTo.init(
                channelId: channelId.trimmingCharacters(in: .whitespaces),
                userId: userId.trimmingCharacters(in: .whitespaces),
                encryptionKey: encryptionKey, encryptionSalt: encryptionSalt

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
            encryptionKey = DocsAppConfig.shared.cipherKey
            encryptionSalt = DocsAppConfig.shared.salt
        }
    }
}

#Preview {
    CloudProxyInputView(continueTo: CloudProxyView.self)
}
