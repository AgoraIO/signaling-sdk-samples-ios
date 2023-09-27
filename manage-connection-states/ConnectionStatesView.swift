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
        try await self.signalingEngine.logout()
    }

    func subscribe(_ channel: String) async throws -> RtmCommonResponse {
        try await self.signalingEngine.subscribe(toChannel: channel)
    }
    public func rtmKit(
        _ rtmClient: RtmClientKit, channel: String,
        connectionChangedToState state: RtmClientConnectionState,
        reason: RtmClientConnectionChangeReason
    ) {
        Task { await self.updateLabel(to: """
        Connection
        state: \(state.description)
        reason: \(reason.description)
        """) }
    }
}

// MARK: - UI

struct ConnectionStatesView: View {
    @ObservedObject var signalingManager: ConnectionStatesManager

    @State var logInButtonDisabled = false
    var body: some View {
        ZStack {
            VStack {
                Spacer()
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
                        } catch let error as RtmErrorInfo {
                            signalingManager.label = "Couldn't log in: \(error.errorCode)\n\(error.reason)"
                        }
                    }
                } label: {
                    Text("Log \(signalingManager.loggedIn ? "out" : "in")").padding(5)
                }.buttonStyle(.borderedProminent).disabled(logInButtonDisabled).cornerRadius(8).padding()
            }
            ToastView(message: $signalingManager.label)
        }.onDisappear {
            try? await signalingManager.destroy()
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
