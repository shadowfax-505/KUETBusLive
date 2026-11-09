//
//  PasscodePad.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  A number pad with four dots, like the iPhone lock screen. It calls
//  onComplete once four digits are entered, then clears itself.
//  A wrong code makes the dots shake.
//

import SwiftUI

struct PasscodePad: View {
    let title: String
    let message: String
    let shakes: Int                      // increase this to shake the dots
    let onComplete: (String) -> Void

    @State private var code = ""

    let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "", "0", "⌫"]

    var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.headline)

            HStack(spacing: 18) {
                ForEach(0..<AppPasscode.length, id: \.self) { index in
                    Circle()
                        .fill(index < code.count ? Color.primary : Color.clear)
                        .overlay(Circle().stroke(Color.primary, lineWidth: 1.5))
                        .frame(width: 14, height: 14)
                        .scaleEffect(index < code.count ? 1.15 : 1)
                        .animation(.spring(response: 0.25, dampingFraction: 0.5), value: code.count)
                }
            }
            // VoiceOver reads "2 of 4 digits entered" instead of four unnamed circles.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Passcode")
            .accessibilityValue("\(code.count) of \(AppPasscode.length) digits entered")
            .modifier(Shake(amount: CGFloat(shakes)))
            .animation(.linear(duration: 0.4), value: shakes)

            Text(message)
                .font(.footnote)
                .foregroundColor(.red)
                .frame(height: 18)

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(78), spacing: 22), count: 3), spacing: 16) {
                ForEach(keys, id: \.self) { key in
                    if key.isEmpty {
                        Color.clear.frame(width: 72, height: 72)
                            .accessibilityHidden(true)
                    } else {
                        Button {
                            press(key)
                        } label: {
                            Text(key)
                                .font(.title)
                                .frame(width: 72, height: 72)
                                .background(key == "⌫" ? Color.clear : Color.secondary.opacity(0.15))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(key == "⌫" ? String(localized: "Delete last digit") : key)
                    }
                }
            }
        }
        .sensoryFeedback(.error, trigger: shakes)
    }

    func press(_ key: String) {
        if key == "⌫" {
            if !code.isEmpty {
                code.removeLast()
            }
            return
        }
        guard code.count < AppPasscode.length else { return }
        code.append(key)
        if code.count == AppPasscode.length {
            let entered = code
            // A short pause so the last dot is visible before the pad clears.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                code = ""
                onComplete(entered)
            }
        }
    }
}

// Moves a view left and right a few times. Animating "amount" by 1 is one shake.
struct Shake: GeometryEffect {
    var amount: CGFloat
    var animatableData: CGFloat {
        get { amount }
        set { amount = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 10 * sin(amount * .pi * 4), y: 0))
    }
}
