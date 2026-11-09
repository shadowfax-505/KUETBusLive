//
//  ComplaintViewModel.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Riders and drivers send complaints and see their own. The admin sees every
//  complaint, changes its status and writes a reply. The security rules make
//  sure nobody else can read or change them.
//

import Foundation
import FirebaseFirestore

class ComplaintViewModel: ObservableObject {
    @Published var complaints = [Complaint]()
    @Published var errorMessage = ""

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    // Complaints the admin hasn't opened yet: the number on the inbox tab.
    var unreadCount: Int {
        complaints.filter { !$0.readByAdmin }.count
    }

    func complaints(with status: ComplaintStatus?) -> [Complaint] {
        guard let status = status else { return complaints }
        return complaints.filter { $0.status == status }
    }

    // Read: only my own complaints. Sorted here, so Firestore needs no extra index.
    func listenToMine(uid: String) {
        listen(to: db.collection("complaints").whereField("uid", isEqualTo: uid))
    }

    // Read (admin): every complaint.
    func listenToAll() {
        listen(to: db.collection("complaints"))
    }

    private func listen(to query: Query) {
        listener?.remove()
        listener = query.addSnapshotListener { snapshot, error in
            if let error = error {
                self.errorMessage = error.localizedDescription
                return
            }
            self.complaints = (snapshot?.documents.compactMap { try? $0.data(as: Complaint.self) } ?? [])
                .sorted { $0.createdAt > $1.createdAt }
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    // Add: once sent, the rider can't edit it.
    func send(_ complaint: Complaint, completion: @escaping (String?) -> Void) {
        do {
            _ = try db.collection("complaints").addDocument(from: complaint) { error in
                completion(error?.localizedDescription)
            }
        } catch {
            completion(error.localizedDescription)
        }
    }

    // Update (admin): opening a complaint clears it from the unread badge.
    func markRead(_ complaint: Complaint) {
        guard let id = complaint.id, !complaint.readByAdmin else { return }
        db.collection("complaints").document(id).updateData(["readByAdmin": true])
    }

    // Update (admin): new status and an optional reply the rider will see.
    func update(_ complaint: Complaint, status: ComplaintStatus, reply: String,
                completion: @escaping (String?) -> Void) {
        guard let id = complaint.id else { return }
        var fields: [String: Any] = ["status": status.rawValue, "readByAdmin": true]
        let reply = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        if reply != (complaint.adminReply ?? "") {
            fields["adminReply"] = reply.isEmpty ? FieldValue.delete() : reply
            fields["repliedAt"] = Date()
        }
        db.collection("complaints").document(id).updateData(fields) { error in
            completion(error?.localizedDescription)
        }
    }
}
