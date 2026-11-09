//
//  BiometricAuth.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Face ID (or Touch ID) unlock using Apple's LocalAuthentication framework.
//  When the app has its own passcode, a failed Face ID falls back to that.
//  Otherwise iOS falls back to the phone's passcode.
//

import Foundation
import LocalAuthentication

struct BiometricAuth {
    // "Face ID", "Touch ID", or nil when the phone has neither set up.
    static var biometryName: String? {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return nil
        }
        switch context.biometryType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        default:
            return nil
        }
    }

    static var isAvailable: Bool {
        biometryName != nil
    }

    // Shows the Face ID prompt. The completion runs on the main thread.
    static func authenticate(reason: String,
                             allowDevicePasscode: Bool = true,
                             completion: @escaping (Bool, String?) -> Void) {
        let context = LAContext()
        context.localizedCancelTitle = "Not now"
        let policy: LAPolicy = allowDevicePasscode
            ? .deviceOwnerAuthentication
            : .deviceOwnerAuthenticationWithBiometrics
        if !allowDevicePasscode {
            // Hides the "Enter Password" button; the app's own passcode pad is the fallback.
            context.localizedFallbackTitle = ""
        }
        context.evaluatePolicy(policy, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                completion(success, error?.localizedDescription)
            }
        }
    }
}
