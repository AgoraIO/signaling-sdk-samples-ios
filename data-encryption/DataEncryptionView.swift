import SwiftUI
import AgoraRtm

public class EncryptionSignalingManager: GetStartedSignalingManager {

    let encryptionKey: String
    let encryptionSalt: String
    public override func setupEngine() -> RtmClientKit {
        let config = RtmClientConfig(appId: self.appId, userId: self.userId)

        config.encryptionConfig = .aes128GCM(
            key: encryptionKey, salt: encryptionSalt
        )

        guard let eng = try? RtmClientKit(
            config: config, delegate: self
        ) else {
            fatalError("could not create client engine: check parameters")
        }

        self.engine = eng
        return eng
    }

    init(
        appId: String, userId: String,
        encryptionKey: String, encryptionSalt: String
    ) {
        self.encryptionKey = encryptionKey
        self.encryptionSalt = encryptionSalt
        super.init(appId: appId, userId: userId)
    }
}

struct DataEncryptionView: View {
    @ObservedObject var signalingManager: EncryptionSignalingManager
    let channelId: String

    var body: some View {
        ZStack {
            VStack {
                MessagesListView(
                    messages: $signalingManager.messages,
                    localUser: signalingManager.userId
                ).padding()
                MessageInputView(publish: publish(message:))
            }
            ToastView(message: $signalingManager.label)
        }.onAppear {
            await signalingManager.loginAndSub(
                to: self.channelId, with: DocsAppConfig.shared.token
            )
        }.onDisappear { try? await signalingManager.destroy()
        }
    }

    // MARK: - Helpers and Setup

    func publish(message: String) async {
        await self.signalingManager.publish(
            message: message, to: self.channelId
        )
    }

    init(
        channelId: String, userId: String,
        encryptionKey: String, encryptionSalt: String
    ) {
        DocsAppConfig.shared.channel = channelId
        DocsAppConfig.shared.uid = userId

        self.channelId = channelId
        self.signalingManager = EncryptionSignalingManager(
            appId: DocsAppConfig.shared.appId, userId: userId,
            encryptionKey: encryptionKey, encryptionSalt: encryptionSalt
        )
    }

    static var docPath: String = "data-encryption"
    static var docTitle: String = "Data encryption"
}
