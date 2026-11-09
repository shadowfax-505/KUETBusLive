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
            List {
                ForEach(routeViewModel.routes) { route in
                    NavigationLink {
                        // The admin edits the route. Riders see its stops and pick theirs.
                        if isAdmin {
                            RouteEditorView(route: route, routeViewModel: routeViewModel)
                        } else {
                            RouteDetailView(route: route)
                        }
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
                .onDelete { offsets in
                    guard isAdmin else { return }
                    for index in offsets {
                        routeViewModel.delete(routeViewModel.routes[index])
                    }
                }
                .deleteDisabled(!isAdmin)
            }
            .toolbar {
                if isAdmin {
                    NavigationLink {
                        RouteEditorView(route: nil, routeViewModel: routeViewModel)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New route")
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
