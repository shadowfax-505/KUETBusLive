//
//  RoutesListView.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//

import SwiftUI

struct RoutesListView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var routeViewModel = RouteViewModel()

    var isAdmin: Bool {
        authViewModel.profile?.role == .admin
    }

    var body: some View {
        NavigationStack {
            List(routeViewModel.routes) { route in
                NavigationLink {
                    RouteDetailView(route: route)
                } label: {
                    VStack(alignment: .leading) {
                        Text(route.name)
                            .font(.headline)
                        Text("\(route.stops.count) stops")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .overlay {
                if routeViewModel.routes.isEmpty {
                    if isAdmin {
                        Button("Add sample KUET routes") {
                            routeViewModel.addSampleRoutes()
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Text("No routes yet")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Routes")
        }
        .onAppear {
            routeViewModel.startListening()
        }
        .onDisappear {
            routeViewModel.stopListening()
        }
    }
}
