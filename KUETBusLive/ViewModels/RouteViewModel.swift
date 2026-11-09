//
//  RouteViewModel.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//

import Foundation
import FirebaseFirestore

class RouteViewModel: ObservableObject {
    @Published var routes = [BusRoute]()

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    // Read: live list of routes, sorted by name.
    func startListening() {
        guard listener == nil else { return }
        listener = db.collection("routes").order(by: "name").addSnapshotListener { snapshot, error in
            if let error = error {
                print("Error getting routes: \(error)")
                return
            }
            self.routes = snapshot?.documents.compactMap { document in
                try? document.data(as: BusRoute.self)
            } ?? []
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    // Add a new route, or Update an existing one (it already has a document ID).
    // Renaming, adding, moving and deleting stops all save the whole route again.
    func save(_ route: BusRoute, completion: @escaping (String?) -> Void) {
        do {
            if let id = route.id {
                try db.collection("routes").document(id).setData(from: route) { error in
                    completion(error?.localizedDescription)
                }
            } else {
                _ = try db.collection("routes").addDocument(from: route) { error in
                    completion(error?.localizedDescription)
                }
            }
        } catch {
            completion(error.localizedDescription)
        }
    }

    // Delete
    func delete(_ route: BusRoute) {
        guard let id = route.id else { return }
        db.collection("routes").document(id).delete { error in
            if let error = error {
                print("Error deleting route: \(error)")
            }
        }
    }

    // Add: two sample routes so a fresh Firebase project has data to show.
    // Coordinates are approximate.
    func addSampleRoutes() {
        let sonadanga = BusRoute(name: "KUET to Sonadanga", nameBn: "কুয়েট – সোনাডাঙ্গা", stops: [
            Stop(name: "KUET Main Gate", nameBn: "কুয়েট মেইন গেট", lat: 22.8999, lng: 89.5024),
            Stop(name: "Fulbarigate", nameBn: "ফুলবাড়ীগেট", lat: 22.8890, lng: 89.5095),
            Stop(name: "Daulatpur", nameBn: "দৌলতপুর", lat: 22.8660, lng: 89.5170),
            Stop(name: "Notun Rasta", nameBn: "নতুন রাস্তা", lat: 22.8460, lng: 89.5330),
            Stop(name: "Sonadanga Bus Terminal", nameBn: "সোনাডাঙ্গা বাস টার্মিনাল", lat: 22.8170, lng: 89.5440)
        ])
        let royalMore = BusRoute(name: "KUET to Royal More", nameBn: "কুয়েট – রয়্যাল মোড়", stops: [
            Stop(name: "KUET Main Gate", nameBn: "কুয়েট মেইন গেট", lat: 22.8999, lng: 89.5024),
            Stop(name: "Fulbarigate", nameBn: "ফুলবাড়ীগেট", lat: 22.8890, lng: 89.5095),
            Stop(name: "Daulatpur", nameBn: "দৌলতপুর", lat: 22.8660, lng: 89.5170),
            Stop(name: "Shibbari More", nameBn: "শিববাড়ী মোড়", lat: 22.8150, lng: 89.5590),
            Stop(name: "Royal More", nameBn: "রয়্যাল মোড়", lat: 22.8105, lng: 89.5630)
        ])

        for route in [sonadanga, royalMore] {
            do {
                _ = try db.collection("routes").addDocument(from: route)
            } catch {
                print("Error adding route: \(error)")
            }
        }
    }
}
