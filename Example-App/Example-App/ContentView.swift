//
//  ContentView.swift
//  Example-App
//
//  Created by Max Cobb on 15/08/2023.
//

import SwiftUI
import AgoraRtm

struct ContentView: View {
    var body: some View {
        NavigationStack {
            #if os(iOS)
            content.navigationBarTitleDisplayMode(.inline)
            #elseif os(macOS)
            if #available(macOS 14.0, *) {
                content.toolbarTitleDisplayMode(.inline)
            } else {
                content
            }
            #endif
            Text(RtmClientKit.getVersion()).opacity(0.6).padding(.bottom)
        }.navigationTitle("Signaling SDK reference app")
    }

    @ViewBuilder
    var content: some View {
        List {
            Section("Get Started") {
                NavigationLink(GettingStartedView.docTitle) {
                    ChannelInputView(continueTo: GettingStartedView.self)
                }
                NavigationLink(TokenAuthenticationView.docTitle) {
                    TokenUrlInputView(continueTo: TokenAuthenticationView.self)
                }
                NavigationLink(ConnectionStatesView.docTitle) {
                    UserInputView(continueTo: ConnectionStatesView.self)
                }
                NavigationLink(StreamChannelsView.docTitle) {
                    ChannelInputView(continueTo: StreamChannelsView.self)
                }
                NavigationLink(PresenceView.docTitle) {
                    ChannelInputView(continueTo: PresenceView.self)
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
