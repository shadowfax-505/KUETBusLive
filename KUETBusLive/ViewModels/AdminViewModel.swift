//
//  AdminViewModel.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Transport admin: approves teachers and drivers after checking their KUET ID.
//

import Foundation
import FirebaseFirestore

class AdminViewModel: ObservableObject {
    @Published var users = [AppUser]()

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    // Accounts still waiting. Older accounts without the isApproved field count as waiting too.
    var pendingUsers: [AppUser] {
        users.filter { !$0.approved }
    }

    // Read: live list of every teacher and driver.
    func startListening() {
        guard listener == nil else { return }
        listener = db.collection("users")
            .whereField("role", in: [UserRole.teacher.rawValue, UserRole.driver.rawValue])
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error getting users: \(error)")
                    return
                }
                self.users = snapshot?.documents.compactMap { document in
                    try? document.data(as: AppUser.self)
                } ?? []
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    // Update
    func approve(_ user: AppUser) {
        guard let id = user.id else { return }
        db.collection("users").document(id).updateData(["isApproved": true])
    }

    // Delete: removes the profile, so the account can't use the app.
    func reject(_ user: AppUser) {
        guard let id = user.id else { return }
        db.collection("users").document(id).delete()
    }
}
