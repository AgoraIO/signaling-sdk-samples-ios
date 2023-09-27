//
//  MessagesListView.swift
//  Example-App
//
//  Created by Max Cobb on 11/08/2023.
//

import SwiftUI

struct MessagesListView<T: DisplayMessage>: View {
    @Binding var messages: [T]
    var localUser: String?
    var body: some View {
        ScrollView { LazyVStack(spacing: 12) {
            ForEach(messages) { message in
                MessageCellView(
                    message: message,
                    isLocalUser: (localUser ?? "") == message.sender
                )
            }
        }}
    }
}

// MARK: - Previews

struct MessagesListView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            MessagesListView(messages: .constant([
                SignalingMessage(text: "Hey there! 🌟", sender: "Alice", id: .init()),
                SignalingMessage(text: "Hey Alice! How's it going?", sender: "Bob", id: .init()),
                SignalingMessage(
                    text: "I'm doing great. Just started learning RTM 2.0. It's really cool!",
                    sender: "Alice", id: .init()
                ),
                SignalingMessage(
                    text: "That's awesome! I've been working with it for a while now."
                    + " Let me know if you need any help.",
                    sender: "Bob", id: .init()
                ),
                SignalingMessage(text: "Thanks, Bob. I appreciate that. 😊", sender: "Alice", id: .init())
            ]), localUser: "Bob").padding()
            MessageInputView(publish: { print($0) })
        }
    }
}
