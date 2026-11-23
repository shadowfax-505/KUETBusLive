//
//  NetworkMonitor.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Whether the phone can reach the internet right now. Without it the map shows the
//  last positions Firestore had, and a driver's positions wait on the phone until the
//  signal comes back, so both screens say so instead of looking live.
//

import Foundation
import Network
import SwiftUI

final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published private(set) var isOnline = true

    private let monitor = NWPathMonitor()

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            DispatchQueue.main.async {
                if self?.isOnline != online { self?.isOnline = online }
            }
        }
        monitor.start(queue: DispatchQueue(label: "KUETBusLive.network"))
    }
}

// A small pill for the top of a screen while the phone is offline.
struct OfflineBanner: View {
    let message: LocalizedStringKey

    var body: some View {
        Label(message, systemImage: "wifi.slash")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.orange))
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isStaticText)
    }
}
