//
//  AuthViewModel.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Sign up, sign in and sign out with Firebase Auth, KUET ID checks,
//  email verification, and the user's profile in Firestore.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import UserNotifications
import WidgetKit

class AuthViewModel: ObservableObject {
    @Published var user: User? = nil
    @Published var profile: AppUser? = nil
    @Published var isSignedIn: Bool = false
    @Published var isEmailVerified: Bool = false
    @Published var errorMessage: String = ""
    @Published var infoMessage: String = ""

    private let db = Firestore.firestore()
    private var profileListener: ListenerRegistration?

    init() {
        self.user = Auth.auth().currentUser
        self.isSignedIn = user != nil
        self.isEmailVerified = user?.isEmailVerified ?? false
        if let uid = user?.uid {
            listenToProfile(uid: uid)
        }
    }

    // Students and teachers with a real KUET email must open the link Firebase sends them.
    var mustVerifyEmail: Bool {
        guard let profile = profile else { return false }
        return KUETVerifier.needsEmailVerification(role: profile.role, email: profile.email)
            && !isEmailVerified
    }

    func signUp(name: String, email: String, password: String, role: UserRole, kuetId: String) {
        errorMessage = ""
        let email = email.lowercased().trimmingCharacters(in: .whitespaces)
        let kuetId = kuetId.trimmingCharacters(in: .whitespaces)

        // Check the KUET ID and email before an account is created.
        if let problem = KUETVerifier.validate(role: role, email: email, kuetId: kuetId) {
            errorMessage = problem
            return
        }

        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                self.errorMessage = error.localizedDescription
                // Full details (error code and server message) go to the Xcode console.
                print("Sign up error: \((error as NSError).userInfo)")
                return
            }
            guard let firebaseUser = result?.user else { return }

            // Students are approved straight away. Teachers and drivers wait for the transport admin.
            var newProfile = AppUser(name: name, email: email, role: role)
            newProfile.kuetId = kuetId
            newProfile.isApproved = !newProfile.needsApproval
            do {
                // Add: the profile document uses the Auth uid as its ID.
                try self.db.collection("users").document(firebaseUser.uid).setData(from: newProfile)
            } catch {
                self.errorMessage = String(localized: "Could not save profile: \(error.localizedDescription)")
                return
            }

            if KUETVerifier.needsEmailVerification(role: role, email: email) {
                firebaseUser.sendEmailVerification { error in
                    if let error = error {
                        self.errorMessage = String(localized: "Could not send verification email: \(error.localizedDescription)")
                    }
                }
            }

            self.user = firebaseUser
            self.isEmailVerified = firebaseUser.isEmailVerified
            self.isSignedIn = true
            self.listenToProfile(uid: firebaseUser.uid)
        }
    }

    func signIn(email: String, password: String) {
        errorMessage = ""
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                self.errorMessage = error.localizedDescription
                print("Sign in error: \((error as NSError).userInfo)")
                return
            }
            self.user = result?.user
            self.isEmailVerified = result?.user.isEmailVerified ?? false
            self.isSignedIn = true
            if let uid = result?.user.uid {
                self.listenToProfile(uid: uid)
            }
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            profileListener?.remove()
            profileListener = nil
            self.user = nil
            self.profile = nil
            self.isSignedIn = false
            self.isEmailVerified = false
            self.infoMessage = ""
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    // Read: a live listener, so an admin's approval shows up without signing in again.
    func listenToProfile(uid: String) {
        profileListener?.remove()
        profileListener = db.collection("users").document(uid).addSnapshotListener { snapshot, error in
            if let error = error {
                self.errorMessage = error.localizedDescription
                return
            }
            self.profile = try? snapshot?.data(as: AppUser.self)
        }
    }

    // Firebase only learns that the link was opened after the user is reloaded.
    func refreshVerification() {
        infoMessage = ""
        user?.reload { error in
            if let error = error {
                self.errorMessage = error.localizedDescription
                return
            }
            self.user = Auth.auth().currentUser
            self.isEmailVerified = Auth.auth().currentUser?.isEmailVerified ?? false
            if !self.isEmailVerified {
                self.infoMessage = String(localized: "Not verified yet. Open the link in your KUET email first.")
            }
        }
    }

    func resendVerification() {
        infoMessage = ""
        user?.sendEmailVerification { error in
            if let error = error {
                self.errorMessage = error.localizedDescription
                return
            }
            let email = self.user?.email ?? String(localized: "your email")
            self.infoMessage = String(localized: "Verification email sent to \(email).")
        }
    }

    // Delete: removes the account for good (App Store rule 5.1.1(v)).
    // 1. Checks the password again, because Firebase only deletes a login that signed in recently.
    // 2. Ends a driver's trip, then deletes their bus and the profile (which holds the push token).
    // 3. Deletes the Firebase Auth login, then forgets everything this phone saved.
    // Calls completion with nil when done, or with a message to show.
    func deleteAccount(password: String, beforeDeleting: (() -> Void)? = nil,
                       completion: @escaping (String?) -> Void) {
        guard let firebaseUser = Auth.auth().currentUser, let email = firebaseUser.email,
              let profile = profile else {
            completion(String(localized: "You are not signed in."))
            return
        }
        let uid = firebaseUser.uid

        Task { @MainActor in
            do {
                // The last admin can't leave, or nobody could approve teachers and drivers.
                if profile.role == .admin {
                    let admins = try await db.collection("users")
                        .whereField("role", isEqualTo: UserRole.admin.rawValue)
                        .getDocuments()
                    if let reason = AccountDeletion.blockReason(role: .admin, adminCount: admins.count) {
                        completion(reason)
                        return
                    }
                }

                let credential = EmailAuthProvider.credential(withEmail: email, password: password)
                try await firebaseUser.reauthenticate(with: credential)

                // Only now that the password is right: stop GPS and take the bus off the map.
                beforeDeleting?()
                let buses = try await db.collection("buses").whereField("driverId", isEqualTo: uid).getDocuments()
                for bus in buses.documents {
                    try await bus.reference.delete()
                }

                profileListener?.remove()
                profileListener = nil
                try await db.collection("users").document(uid).delete()
                try await firebaseUser.delete()
            } catch {
                completion(Self.deletionMessage(for: error))
                // A failed step may have stopped the profile listener; start it again.
                if profileListener == nil, Auth.auth().currentUser != nil {
                    listenToProfile(uid: uid)
                }
                return
            }

            clearLocalData(uid: uid)
            signOut()
            completion(nil)
        }
    }

    // Everything this phone kept for the account: lock settings, passcode, alerts,
    // the push topic, the widget's trips and any Live Activity.
    private func clearLocalData(uid: String) {
        PushManager.shared.forgetDevice()
        AccountDeletion.clearLocalSettings(in: .standard)
        UserDefaults.standard.removeObject(forKey: AnnouncementViewModel.hiddenKey(for: uid))
        AppPasscode.remove()
        SharedStore.clear()
        WidgetCenter.shared.reloadAllTimelines()
        LiveActivityManager.shared.stop()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    private static func deletionMessage(for error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == FirestoreErrorDomain, nsError.code == FirestoreErrorCode.unavailable.rawValue {
            return String(localized: "No internet connection. Nothing was deleted. Try again when you're online.")
        }
        guard nsError.domain == AuthErrorDomain else {
            return String(localized: "Could not delete the account: \(error.localizedDescription)")
        }
        switch AuthErrorCode(rawValue: nsError.code) {
        case .wrongPassword, .invalidCredential:
            return String(localized: "That password is not right. Nothing was deleted.")
        case .networkError:
            return String(localized: "No internet connection. Nothing was deleted. Try again when you're online.")
        case .tooManyRequests:
            return String(localized: "Too many tries. Wait a few minutes and try again.")
        default:
            return String(localized: "Could not delete the account: \(error.localizedDescription)")
        }
    }

    // Update: saves the rider's favourite stop on their profile.
    func saveFavoriteStop(_ stop: Stop) {
        guard let uid = user?.uid else { return }
        db.collection("users").document(uid).updateData([
            "favoriteStopName": stop.name,
            "favoriteStopLat": stop.lat,
            "favoriteStopLng": stop.lng
        ]) { error in
            if let error = error {
                self.errorMessage = error.localizedDescription
            }
            // No local copy to update: the profile listener receives the change.
        }
    }
}
