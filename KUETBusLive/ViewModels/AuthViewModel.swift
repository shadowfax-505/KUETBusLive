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
