//
//  View+Extensions.swift
//  Example-App
//
//  Created by Max Cobb on 11/08/2023.
//

import SwiftUI

extension View {
    @ViewBuilder
    func onAppear(performAsync action: @escaping () async -> Void) -> some View {
        self.onAppear {
            Task { await action() }
        }
    }
    func onDisappear(performAsync action: @escaping () async -> Void) -> some View {
        self.onDisappear {
            Task { await action() }
        }
    }
    internal func filter(string: String, by charSet: CharacterSet) -> String? {
        let filtered = String(string.unicodeScalars.filter {
            charSet.contains($0)
        })
        if filtered != string {
            return filtered
        } else { return nil }

    }

}
