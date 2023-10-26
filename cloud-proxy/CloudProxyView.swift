
import SwiftUI
import AgoraRtm

public class CloudProxyManager: GetStartedSignalingManager {

    let proxyServer: String
    let proxyPort: UInt16
    let proxyAccount: String?
    let proxyPassword: String?

    public override func setupEngine() -> RtmClientKit {
        let config = RtmClientConfig(appId: self.appId, userId: self.userId)

        let proxyConfig = RtmProxyConfig(
            proxyType: .http,
            server: proxyServer,
            port: proxyPort
        )
        proxyConfig.account = self.proxyAccount
        proxyConfig.password = self.proxyPassword

        config.proxyConfig = proxyConfig

        guard let eng = try? RtmClientKit(
            config: config, delegate: self
        ) else {
            fatalError("could not create client engine: check parameters")
        }
        self.engine = eng
        return eng
    }

    public func rtmKit(
        _ rtmClient: RtmClientKit, channel: String,
        connectionChangedToState state: RtmClientConnectionState,
        reason: RtmClientConnectionChangeReason
    ) {
        guard reason == .settingProxyServer else { return }

        switch state {
        case .disconnected: break
        case .connecting: break
        case .connected: break
        case .reconnecting: break
        case .failed: break
        default: break
        }
    }

    init(
        appId: String, userId: String,
        proxyServer: String, proxyPort: UInt16,
        proxyAccount: String?, proxyPassword: String?
    ) {
        self.proxyServer = proxyServer
        self.proxyPort = proxyPort
        self.proxyAccount = proxyAccount
        self.proxyPassword = proxyPassword
        super.init(appId: appId, userId: userId)
    }
}

struct CloudProxyView: View {
    @ObservedObject var signalingManager: CloudProxyManager
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
        proxyServer: String, proxyPort: UInt16,
        proxyAccount: String?, proxyPassword: String?
    ) {
        DocsAppConfig.shared.channel = channelId
        DocsAppConfig.shared.uid = userId

        self.channelId = channelId
        self.signalingManager = CloudProxyManager(
            appId: DocsAppConfig.shared.appId, userId: userId,
            proxyServer: proxyServer, proxyPort: proxyPort,
            proxyAccount: proxyAccount, proxyPassword: proxyPassword
        )
    }

    static var docPath: String = "cloud-proxy"
    static var docTitle: String = "Connect through restricted networks with Cloud Proxy"
}
