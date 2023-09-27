//
//  RemoteUsersView.swift
//  Example-App
//
//  Created by Max Cobb on 27/09/2023.
//

import SwiftUI

struct RemoteUsersView: View {
    @Binding var remoteUsers: Set<String>
    var body: some View {
        if self.remoteUsers.isEmpty {
            Text("None").padding()
        } else {
            Form {
                Section("Remote Users") {
                    List(Array(remoteUsers), id: \.self) { user in
                        Text(user)
                    }.listStyle(PlainListStyle())
                }
            }.padding()
            #if os(macOS)
                .frame(
                    minWidth: 300,
                    minHeight: 35 * (CGFloat(
                        min(remoteUsers.count, 5) + 1
                    ))
                )
            #endif

        }
    }
}

struct PresenceButtonView: View {
    @Binding var presenceViewPresented: Bool
    @Binding var remoteCount: Int
    var body: some View {
        Button(action: {
            self.presenceViewPresented = true
        }, label: {
            HStack {
                Spacer()
                Text("Remote Users (\(remoteCount))")
                Spacer()
            }
        }).frame(maxHeight: 50)
            .background {
                Color(.systemBackground)
                    .shadow(radius: 5, x: 0, y: -10)
            }

    }
}

#Preview {
    VStack {
        Spacer()
        PresenceButtonView(presenceViewPresented: .constant(true), remoteCount: .constant(2))
    }.sheet(isPresented: .constant(true), content: {
            RemoteUsersView(remoteUsers: .constant(["One", "Two", "three", "four"]))
    })
}
