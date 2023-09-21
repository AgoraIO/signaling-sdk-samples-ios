//
//  UserInputView.swift
//  Example-App
//
//  Created by Max Cobb on 16/08/2023.
//

import SwiftUI
import AgoraRtm

/// A protocol for views that require a `channelId` string as input.
protocol HasUserInput: HasDocPath {
    init(userId: String)
}

extension ConnectionStatesView: HasUserInput {}

/// A view that takes a user inputted `userId` string and navigates to a view
/// which conforms to the `HasUserInput` protocol.
///
/// The generic parameter `Content` specifies the type of view to navigate to,
/// and must conform to the `HasUserInput` protocol.
struct UserInputView<Content: HasUserInput>: View {
    /// The user inputted `userId` string for logging in.
    @State private var userId: String = ""
    /// The type of view to navigate to.
    var continueTo: Content.Type

    var body: some View {
        VStack {
            VStack(alignment: .leading) {
                Text("Username")
                TextField("Enter username", text: $userId)
                    .textContentType(.username).textFieldStyle(.roundedBorder)
            }.padding([.leading, .trailing])
            NavigationLink(destination: NavigationLazyView(continueTo.init(
                userId: userId.trimmingCharacters(in: .whitespaces)
            ).navigationTitle(continueTo.docTitle).toolbar {
                ToolbarItem(placement: .automatic) {
//                    GitHubButtonView(continueTo.docPath)
                }
            }), label: {
                Text("Continue")
            }).disabled(userId.isEmpty)
                .buttonStyle(.borderedProminent)
                .navigationTitle("Channel Input")
        }.onChange(of: userId) { newVal in
            if let filtered = self.filter(
                string: newVal, by: RtmLegalCharacterSets.username
            ) { userId = filtered }
        }.onAppear {
            userId = DocsAppConfig.shared.uid
        }
    }
}

struct UserInputView_Previews: PreviewProvider {
    static var previews: some View {
        UserInputView(continueTo: ConnectionStatesView.self)
    }
}
