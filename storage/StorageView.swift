//
//  GettingStartedView.swift
//  Example-App
//
//  Created by Max Cobb on 01/08/2023.
//

import SwiftUI
import AgoraRtm

public class StorageSignalingManager: SignalingManager, RtmClientDelegate {

    /// Log into Signaling with a token, and subscribe to a message channel.
    /// - Parameters:
    ///   - channel: Channel name to subscribe to.
    ///   - token: token to be used for login authentication.
    override func subscribe(to channel: String) async throws -> RtmCommonResponse {
        try await self.signalingEngine.subscribe(
            toChannel: channel, features: .metadata
        )
    }

    @Published public var selectedUser: RtmMetadata?
    @Published var localMetadata: RtmMetadata?
    @Published var remoteUsers: [String: [String: String]] = [:]

    public func setUserMetadata(to localData: [String: String]) async throws {
        guard let storage = signalingEngine.storage,
              let userMetadata = signalingEngine.storage?.createMetadata()
        else { return }

        self.localMetadata = userMetadata

        localData.forEach { item in
            userMetadata.setMetadataItem(
                RtmMetadataItem(key: item.key, value: item.value, revision: -1)
            )
        }

        _ = try await storage.setUserMetadata(
            userId: self.userId, data: userMetadata,
            options: RtmMetadataOptions(recordTs: true, recordUserId: true)
        )
    }

    public func updateUserInfo(with updates: [String: String]) async throws {
        guard let localMetadata else { return }

        for metadataItem in localMetadata.metadataItems
            where updates.keys.contains(metadataItem.key) {
            metadataItem.value = updates[metadataItem.key]!
        }

        _ = try await signalingEngine.storage?.setUserMetadata(
            userId: self.userId, data: localMetadata,
            options: RtmMetadataOptions(recordTs: true, recordUserId: true)
        )
    }

    func getMetadata(for user: String) async throws -> RtmGetMetadataResponse {
        try await signalingEngine.storage!.getMetadata(forUser: user)
    }

    func subscribeToMetadata(for user: String) async throws {
        try await signalingEngine.storage?.subscribeToMetadata(forUser: user)
    }

    func setMetadata(
        forChannel channel: String,
        metaItem: (key: String, value: String), revision: Int64 = -1,
        lock: String? = nil
    ) async throws {
        // If we have a lock string, try to acquire it
        if let lock {
            try await signalingEngine.lock?.acquireLock(
                named: lock, fromChannel: .messageChannel(channel)
            )
        }

        // Ensure we can create metadata
        guard let metadata = signalingEngine.storage?.createMetadata() else { return }

        // Set the metadata item
        metadata.setMetadataItem(RtmMetadataItem(
            key: metaItem.key, value: metaItem.value, revision: revision
        ))
        try await signalingEngine.storage?.setMetadata(
            forChannel: .messageChannel(channel),
            data: metadata, lock: lock
        )

        // If we have a lock string, release it.
        if let lock {
            try await signalingEngine.lock?.releaseLock(
                named: lock, fromChannel: .messageChannel(channel)
            )
            await self.updateLabel(to: "success")
        }
    }

    func getMetadata(forChannel channel: String) async throws -> RtmGetMetadataResponse {
        try await signalingEngine.storage!.getMetadata(
            forChannel: .messageChannel(channel)
        )
    }

    public func removeUserInfo(for keys: [String]) async throws {
        guard let removeMetadata = signalingEngine.storage?
            .createMetadata() else { return }

        keys.forEach { key in
            removeMetadata.setMetadataItem(.init(key: key, value: ""))
        }

        _ = try await signalingEngine.storage?.removeUserMetadata(
            userId: self.userId, data: removeMetadata
        )
    }
    public func rtmKit(_ rtmClient: RtmClientKit, didReceiveStorageEvent event: RtmStorageEvent) {
        switch (event.eventType, event.storageType) {
        case (.set, .user), (.update, .user), (.snapshot, .user):
            // user metadata set, updated, or a snapshot has been given
            print("user update")
        case (.set, .channel), (.update, .channel), (.snapshot, .channel):
            // channel metadata set, updated, or a snapshot has been given
            print("channel update")
        default: break
        }
    }

    // MARK: Handle Errors
    /// Handle different error cases, and fetch a new token if appropriate.
    /// - Parameters:
    ///   - error: Error thrown by logging in or subscribing to a channel.
    ///   - channel: Channel to which a subscription was attempted.
    func handleLoginSubError(error: RtmErrorInfo, channel: String) async {
        switch error.errorCode {
        case .loginNoServerResources, .loginTimeout, .loginRejected, .loginAborted:
            await self.updateLabel(to: "could not log in, check your app ID and token")
        case .channelSubscribeFailed, .channelSubscribeTimeout, .channelNotSubscribed:
            await self.updateLabel(to: "could not subscribe to channel")
        case .invalidToken:
            if label == nil, let token = try? await self.fetchToken(
                from: DocsAppConfig.shared.tokenUrl,
                username: DocsAppConfig.shared.uid
            ) {
                await self.updateLabel(to: "fetching token")
                await self.loginAndSub(to: channel, with: token)
            }
        default:
            await self.updateLabel(to: """
            failed: \(error.operation)
            reason: \(error.reason)
            """)
        }

    }
}

// MARK: - UI

struct StorageView: View {
    @ObservedObject var signalingManager: StorageSignalingManager
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
            try? await signalingManager.setUserMetadata(to: ["joinedAt": Date.now.description])
        }.onDisappear {
            try? await signalingManager.destroy()
        }
    }

    // MARK: - Helpers and Setup

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
        DocsAppConfig.shared.channel = channelId
        DocsAppConfig.shared.uid = userId

        self.channelId = channelId
        self.signalingManager = StorageSignalingManager(
            appId: DocsAppConfig.shared.appId, userId: userId
        )
    }

    static var docPath: String = "storage"
    static var docTitle: String = "Store channel and user data"
}

// MARK: - Previews

struct StorageView_Previews: PreviewProvider {
    static var previews: some View {
        GettingStartedView(
            channelId: DocsAppConfig.shared.channel,
            userId: DocsAppConfig.shared.uid
        )
    }
}
