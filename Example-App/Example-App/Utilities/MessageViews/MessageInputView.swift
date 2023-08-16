//
//  MessageInputView.swift
//  Example-App
//
//  Created by Max Cobb on 11/08/2023.
//

import SwiftUI

struct MessageInputView: View {
    var publish: (String) async -> Void
    @State var message: String = ""
    var body: some View {
        HStack {
            TextField("Type your message", text: $message)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)

            Button("Send") {
                Task {
                    await publish(message)
                    message = ""
                }
            }.padding(.horizontal).disabled(message.isEmpty)
        }.padding()
    }
}

struct MessageInputView_Previews: PreviewProvider {
    static var previews: some View {
        MessageInputView(publish: { str in print(str) })
    }
}
