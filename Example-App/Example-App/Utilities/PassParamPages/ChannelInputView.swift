//
//  ChannelInputView.swift
//  Example-App
//
//  Created by Max Cobb on 01/08/2023.
//

import SwiftUI
import AgoraRtm

protocol HasDocPath: View {
    static var docPath: String { get }
    static var docTitle: String { get }
}

/// A protocol for views that require a `channelId` string as input.
protocol HasChannelInput: HasDocPath {
    init(channelId: String, userId: String)
}

internal struct NavigationLazyView<Content: View>: View {
    let build: () -> Content
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    var body: Content {
        build()
    }
}

internal func getFolderName(from path: String) -> String {
    let fileURL = URL(fileURLWithPath: path)
    return fileURL.deletingLastPathComponent().lastPathComponent
}

extension GettingStartedView: HasChannelInput {}

/// A view that takes a user inputted `channelId` string and navigates to a view
/// which conforms to the `HasChannelInput` protocol.
///
/// The generic parameter `Content` specifies the type of view to navigate to,
/// and must conform to the `HasChannelInput` protocol.
struct ChannelInputView<Content: HasChannelInput>: View {
    /// The user inputted `channelId` string.
    @State var channelId: String = ""
    /// The user inputted `userId` string for logging in.
    @State var userId: String = ""
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
            }.padding([.leading, .trailing])

            NavigationLink(destination: NavigationLazyView(continueTo.init(
                channelId: channelId.trimmingCharacters(in: .whitespaces),
                userId: userId.trimmingCharacters(in: .whitespaces)
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
        }
    }
}

struct ChannelInputView_Previews: PreviewProvider {
    static var previews: some View {
        ChannelInputView(continueTo: GettingStartedView.self)
    }
}
