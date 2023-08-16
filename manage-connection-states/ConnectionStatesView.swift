//
//  ConnectionStatesView.swift
//  Example-App
//
//  Created by Max Cobb on 11/08/2023.
//

import SwiftUI
import AgoraRtm

public class ConnectionStatesManager: SignalingManager, RtmClientDelegate {

    @Published var loggedIn: Bool = false

    @discardableResult
    func logout() async throws -> RtmCommonResponse {
        try await self.agoraEngine.logout()
    }

    func subscribe(_ channel: String) async throws -> RtmCommonResponse {
        try await self.agoraEngine.subscribe(toChannel: channel)
    }

    public func rtmClient(
        _ rtmClient: RtmClientKit, channel: String,
        connectionStateChanged state: RtmClientConnectionState,
        changeReason reason: RtmClientConnectionChangeReason
    ) {
        label = """
        Connection
        state: \(state.description)
        reason: \(reason.description)
        """
    }
}

struct ConnectionStatesView: View {
    @ObservedObject var signalingManager: ConnectionStatesManager

    @State var logInButtonDisabled = false
    var body: some View {
        VStack {
            Spacer()
            Text(signalingManager.label ?? "Press \"Log in\" below")
                .multilineTextAlignment(.center)
            Spacer()
            HStack {
                Button {
                    logInButtonDisabled = true
                    Task {
                        defer { logInButtonDisabled = false }
                        do {
                            if signalingManager.loggedIn {
                                _ = try? await self.signalingManager.logout()
                            } else {
                                try await self.signalingManager.login()
                            }
                            signalingManager.loggedIn.toggle()
                        } catch {
                            print(error.localizedDescription)
                        }
                    }
                } label: {
                    Text("Log \(signalingManager.loggedIn ? "out" : "in")")
                }.disabled(logInButtonDisabled)
            }
        }
    }

    init(userId: String) {
        DocsAppConfig.shared.uid = userId
        self.signalingManager = ConnectionStatesManager(
            appId: DocsAppConfig.shared.appId, userId: userId
        )
    }
    static var docPath: String = "manage-connection-states"
    static var docTitle: String = "Manage connection states"
}

struct ConnectionStatesView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectionStatesView(userId: DocsAppConfig.shared.uid)
    }
}
