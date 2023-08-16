//
//  ContentView.swift
//  Example-App
//
//  Created by Max Cobb on 15/08/2023.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Get Started") {
                    NavigationLink(GettingStartedView.docTitle) {
                        ChannelInputView(continueTo: GettingStartedView.self)
                    }
                    NavigationLink(TokenAuthenticationView.docTitle) {
                        TokenUrlInputView(continueTo: TokenAuthenticationView.self)
                    }
                }
            }.navigationTitle("Signaling SDK reference app").navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
