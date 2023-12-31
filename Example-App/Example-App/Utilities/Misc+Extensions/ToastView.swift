//
//  ToastView.swift
//  Example-App
//
//  Created by Max Cobb on 22/08/2023.
//

import SwiftUI
import Combine

struct ToastView: View {
    @Binding var message: String?

    @State private var isShowingMessage = true
    @State private var cancellable: Timer?

    var body: some View {
        VStack {
            if let message {
                Text(message)
                    .padding()
                    .background(Color.secondary)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .opacity(isShowingMessage ? 1 : 0)
                    .multilineTextAlignment(.center)
            }
        }.onChange(of: self.message) { _ in
            self.setupCancellable()
        }
    }

    private func setupCancellable() {
        cancellable?.invalidate()
        cancellable = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { _ in
            cancellable?.invalidate()
            withAnimation { message = nil }
        }
    }
}

struct ToastView_Previews: PreviewProvider {
    @Binding var msg: String?
    static var previews: some View {
        ToastView(message: .constant("hello 1"))
    }
}
