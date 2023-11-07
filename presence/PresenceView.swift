import AgoraRtm
import SwiftUI

public class PresenceSignalingManager: SignalingManager, RtmClientDelegate {

    @Published public var selectedUser: RtmPresenceGetStateResponse?

    override func subscribe(to channel: String) async throws -> RtmCommonResponse {
        try await self.signalingEngine.subscribe(
            toChannel: channel,
            features: .presence
        )
    }

    @discardableResult
    func setUserState(
        in channel: String, to state: [String: String]
    ) async throws -> RtmCommonResponse? {
        try await self.signalingEngine.presence?.setUserState(
            inChannel: .messageChannel(channel),
            to: state
        )
    }

    func getState(of user: String, from channel: String) async throws -> RtmPresenceGetStateResponse? {
        let presence = self.signalingEngine.presence
        return try? await presence?.getState(
            ofUser: user,
            inChannel: .messageChannel(channel)
        )
    }

    func getOnlineUsers(in channelName: String) async -> [String]? {
        try? await signalingEngine.presence?.getOnlineUsers(
            inChannel: .messageChannel(channelName),
            options: RtmPresenceOptions(include: .userId)
        ).users
    }

    @Published var remoteUsers: [String] = []

    public func rtmKit(_ rtmClient: RtmClientKit, didReceivePresenceEvent event: RtmPresenceEvent) {
        DispatchQueue.main.async {
            switch event.type {
            case .snapshot(let states):
                // states snapshot received
                break
            case .remoteJoinChannel(let user):
                // remote user joined channel
                break
            case .remoteLeaveChannel(let user):
                // remote user left channel
                break
            case .remoteStateChanged(let user, let states):
                // remote user updated states
                break
            default: break
            }
        }
    }

    override init(appId: String, userId: String) {
        super.init(appId: appId, userId: userId)
    }
}

struct PresenceView: View {
    @ObservedObject var signalingManager: PresenceSignalingManager
    let channelId: String
    @State private var isSheetPresented: Bool = false
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            if self.signalingManager.remoteUsers.isEmpty {
                Text("None").padding()
            } else {
                List(signalingManager.remoteUsers.sorted(), id: \.self) { key in
                    Button(action: {
                        Task { try await self.didSelectUser(key) }
                    }, label: {
                        Text(key)
                    })
                }.sheet(isPresented: $isSheetPresented) {
                    if let selectedUser = signalingManager.selectedUser {
                        DictionaryView(data: selectedUser)
                    }
                }
            }
        }.onReceive(timer, perform: { out in
            Task {
                // fetch online users every 5 seconds.
                // fetching directly is an alternative to checking delegate callbacks
                guard let users = await self.signalingManager.getOnlineUsers(in: self.channelId)
                else { return }
                self.signalingManager.remoteUsers = users
            }
        }).onAppear {
            await signalingManager.loginAndSub(to: self.channelId, with: DocsAppConfig.shared.token)
            _ = try? await self.signalingManager.setUserState(in: self.channelId, to: ["joinedAt": Date.now.description])
        }.onDisappear {
            timer.upstream.connect().cancel()
            try? await signalingManager.destroy()
        }
    }

    func didSelectUser(_ user: String) async throws {
        guard let states = try? await self.signalingManager.getState(of: user, from: self.channelId)
        else { return }

        DispatchQueue.main.async {
            self.signalingManager.selectedUser = states
            self.isSheetPresented = true
        }
    }

    init(channelId: String, userId: String) {
        self.signalingManager = PresenceSignalingManager(appId: DocsAppConfig.shared.appId, userId: userId)
        self.channelId = channelId
    }

    static var docPath: String = "presence"
    static var docTitle: String = "Presence"
}

fileprivate struct DictionaryView: View {
    @State var data: RtmPresenceGetStateResponse

    var body: some View {
        Group {
            if data.states.isEmpty {
                Text("No data")
            } else {
                List(Array(data.states.keys), id: \.self) { item in
                    Text("\(item): \(data.states[item] ?? "invalid")")
                }
                Text("some data")
            }
        }.navigationTitle("User Details")
    }
}

#Preview {
    PresenceView(channelId: DocsAppConfig.shared.channel, userId: DocsAppConfig.shared.uid)
}
