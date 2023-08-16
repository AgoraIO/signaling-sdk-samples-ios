//
//  SignalingManager.swift
//  Example-App
//
//  Created by Max Cobb on 01/08/2023.
//

import Foundation
import AgoraRtm

open class SignalingManager: NSObject, ObservableObject {
    /// The Agora App ID for the session.
    public let appId: String

    public let userId: String

    init(appId: String, userId: String) {
        self.appId = appId
        self.userId = userId
        super.init()
    }

    public var engine: RtmClientKit?
    /// The Agora Signaling Engine for the session.
    public var agoraEngine: RtmClientKit {
        if let engine { return engine }
        return setupEngine()
    }
    open func setupEngine() -> RtmClientKit {
        let config = RtmClientConfig(appId: self.appId, userId: self.userId)
        config.logConfig?.level = .error
        guard let eng = RtmClientKit(
            config: config, delegate: self as? RtmClientDelegate
        ) else {
            fatalError("could not create client engine: check parameters")
        }
        self.engine = eng
        return eng
    }

    @Published var label: String?
}
