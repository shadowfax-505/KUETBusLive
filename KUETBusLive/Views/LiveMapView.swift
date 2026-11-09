//
//  LiveMapView.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//

import SwiftUI
import MapKit

struct LiveMapView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var busViewModel = BusViewModel()

    static let kuetCenter = CLLocationCoordinate2D(latitude: 22.8700, longitude: 89.5250)

    @State private var camera: MapCameraPosition = .region(
        MKCoordinateRegion(center: LiveMapView.kuetCenter,
                           span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12))
    )
    @State private var selectedBusId: String?
    @State private var showDetail = false

    var body: some View {
        NavigationStack {
            Map(position: $camera) {
                if let stop = authViewModel.profile?.favoriteStop {
                    Marker(stop.name, systemImage: "star.fill", coordinate: stop.coordinate)
                        .tint(.blue)
                }

                ForEach(busViewModel.buses) { bus in
                    Annotation(bus.number, coordinate: bus.coordinate) {
                        Button {
                            selectedBusId = bus.id
                            showDetail = true
                        } label: {
                            Image(systemName: "bus.fill")
                                .padding(8)
                                .foregroundColor(.white)
                                .background(bus.crowd.color)
                                .clipShape(Circle())
                                // A purple ring marks teacher buses.
                                .overlay(Circle().stroke(bus.allocation.color, lineWidth: 3))
                        }
                    }
                }
            }
            .overlay(alignment: .top) {
                if busViewModel.buses.isEmpty {
                    Text("No buses are running right now")
                        .padding()
                        .background(.thinMaterial)
                        .cornerRadius(10)
                        .padding()
                }
            }
            .navigationTitle("Live Buses")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showDetail) {
                if let busId = selectedBusId {
                    BusDetailView(busId: busId, busViewModel: busViewModel)
                }
            }
        }
        // On the NavigationStack, not the Map, so opening Bus Detail keeps the listener running.
        // Switching to another tab removes it.
        .onAppear {
            busViewModel.favoriteStop = authViewModel.profile?.favoriteStop
            busViewModel.viewerRole = authViewModel.profile?.role ?? .student
            busViewModel.startListening()
        }
        .onDisappear {
            busViewModel.stopListening()
        }
        // Saving a stop finishes in the background, so pick up the new stop when it arrives.
        .onChange(of: authViewModel.profile?.favoriteStop) {
            busViewModel.favoriteStop = authViewModel.profile?.favoriteStop
            for bus in busViewModel.buses {
                busViewModel.refreshETA(for: bus, force: true)
            }
        }
    }
}
