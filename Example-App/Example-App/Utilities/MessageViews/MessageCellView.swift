//
//  MessageCellView.swift
//  Example-App
//
//  Created by Max Cobb on 11/08/2023.
//

import SwiftUI

struct MessageCellView: View {
    var message: SignalingMessage
    var isLocalUser: Bool

    var body: some View {
        HStack {
            if isLocalUser {
                Spacer()
            }
            VStack(alignment: .leading, spacing: 4) {
                if !isLocalUser, !message.sender.isEmpty {
                    Text(message.sender)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Text(message.text)
                    .padding(10)
                    .foregroundColor(Color.white)
                    .background(isLocalUser ? Color.blue : Color.gray)
                    .cornerRadius(8)
            }
            if !isLocalUser {
                Spacer()
            }
        }
    }
}

struct MessageCellView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            MessageCellView(message: SignalingMessage(
                text: "Hello World 🌏🌍🌎", sender: "Bob", id: .init()
            ), isLocalUser: false)
            MessageCellView(message: SignalingMessage(
                text: "Hello Bob 🌟", sender: "Me", id: .init()
            ), isLocalUser: true)
        }.padding()
    }
}
