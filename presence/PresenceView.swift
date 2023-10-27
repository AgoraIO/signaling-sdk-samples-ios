import AgoraRtm
import SwiftUI

public class PresenceSignalingManager: SignalingManager, RtmClientDelegate {

    @Published public var selectedUser: RtmMetadata?

    override func subscribe(to channel: String) async throws -> RtmCommonResponse {
        try await self.signalingEngine.subscribe(
            toChannel: channel,
            features: .presence
        )
    }

    func setLocalUserMetadata(key: String, value: String) async throws {
        guard let storage = self.signalingEngine.storage,
              let newMetadata = storage.createMetadata()
        else { return }

        newMetadata.setMetadataItem(
            RtmMetadataItem(key: key, value: value)
        )
        try await storage.setUserMetadata(
            userId: self.userId, data: newMetadata
        )
    }

    @Published var remoteUsers: [String: [String: String]] = [:]

    public func rtmKit(_ rtmClient: RtmClientKit, didReceivePresenceEvent event: RtmPresenceEvent) {
        DispatchQueue.main.async {
            switch event.type {
            case .snapshot(let states):
                self.remoteUsers = states
            case .remoteJoinChannel(let user):
                // remote user joined channel
                if self.remoteUsers[user] == nil {
                    self.remoteUsers[user] = [:]
                }
            case .remoteLeaveChannel(let user):
                // remote user left channel
                self.remoteUsers.removeValue(forKey: user)
            case .remoteStateChanged(let user, let states):
                self.remoteUsers.updateValue(states, forKey: user)
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

    var body: some View {
        ZStack {
            if self.signalingManager.remoteUsers.isEmpty {
                Text("None").padding()
            } else {
                List(signalingManager.remoteUsers.keys.sorted(), id: \.self) { key in
                    Button(action: {
                        Task {try await self.didSelectUser(key)}
                    }, label: {
                        Text(key)
                    })
                }.sheet(isPresented: $isSheetPresented) {
                    if let selectedUser = signalingManager.selectedUser {
                        DictionaryView(data: selectedUser)
                    }
                }
            }
        }.onAppear {
            await signalingManager.loginAndSub(to: self.channelId, with: DocsAppConfig.shared.token)
            try? await self.signalingManager.setLocalUserMetadata(
                key: "metaId", value: UUID().uuidString
            )
        }.onDisappear {
            try? await signalingManager.destroy()
        }
    }

    func didSelectUser(_ user: String) async throws {
        guard let storage = self.signalingManager.signalingEngine.storage,
              let data = try await storage.getMetadata(forUser: user).data
        else { return }

        DispatchQueue.main.async {
            self.signalingManager.selectedUser = data
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

struct DictionaryView: View {
    @State var data: RtmMetadata

    var body: some View {
        Group {
            if data.metadataItems.isEmpty {
                Text("No data")
            } else {
                List(data.metadataItems, id: \.key) { item in
                    Text("\(item.key): \(item.value)")
                }
            }
        }.navigationTitle("User Details")
    }
}

#Preview {
    PresenceView(channelId: DocsAppConfig.shared.channel, userId: DocsAppConfig.shared.uid)
}
