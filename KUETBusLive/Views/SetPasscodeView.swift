//
//  SetPasscodeView.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Two steps: type a new passcode, then type it again to confirm.
//

import SwiftUI

struct SetPasscodeView: View {
    let onDone: (Bool) -> Void          // true when a passcode was saved
    @Environment(\.dismiss) private var dismiss

    @State private var firstEntry: String?
    @State private var message = ""
    @State private var shakes = 0

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                PasscodePad(title: firstEntry == nil ? "Choose a 4-digit passcode" : "Enter it again",
                            message: message,
                            shakes: shakes) { code in
                    handle(code)
                }
                Spacer()
            }
            .navigationTitle("App Passcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDone(false)
                        dismiss()
                    }
                }
            }
        }
        .interactiveDismissDisabled()
    }

    func handle(_ code: String) {
        guard let first = firstEntry else {
            firstEntry = code
            message = ""
            return
        }
        if code == first {
            AppPasscode.save(code)
            onDone(true)
            dismiss()
        } else {
            firstEntry = nil
            message = "The passcodes didn't match. Try again."
            shakes += 1
        }
    }
}
