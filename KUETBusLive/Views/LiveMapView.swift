//
//  LiveMapView.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  The live map. Tapping a bus works like a ride-hailing app: the bus's whole
//  route is drawn, the road it will take to your stop is highlighted, and a
//  trip card slides up with the ETA, speed and nearest stop.
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
    @State private var followBus = true
    @State private var showDetail = false
    @State private var locationPermission = CLLocationManager()

    var selectedBus: Bus? {
        guard let id = selectedBusId else { return nil }
        return busViewModel.bus(withId: id)
    }

    var body: some View {
        NavigationStack {
            Map(position: $camera) {
                // The rider's own blue dot.
                UserAnnotation()

                if let bus = selectedBus {
                    // Whole route, drawn faintly.
                    if let path = busViewModel.routePaths[bus.routeId], !path.isEmpty {
                        MapPolyline(coordinates: path)
                            .stroke(bus.allocation.color.opacity(0.35), lineWidth: 6)
                    }
                    // The road from the bus to my stop, drawn strongly.
                    let toMyStop = busViewModel.remainingPath(for: bus)
                    if !toMyStop.isEmpty {
                        MapPolyline(coordinates: toMyStop)
                            .stroke(bus.allocation.color,
                                    style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                    }
                    // Every stop on the route.
                    if let stops = busViewModel.routeStops[bus.routeId] {
                        ForEach(stops, id: \.self) { stop in
                            Annotation(stop.name, coordinate: stop.coordinate) {
                                Circle()
                                    .fill(.white)
                                    .stroke(bus.allocation.color, lineWidth: 3)
                                    .frame(width: 12, height: 12)
                            }
                        }
                    }
                }

                if let stop = authViewModel.profile?.favoriteStop {
                    Marker(stop.name, systemImage: "star.fill", coordinate: stop.coordinate)
                        .tint(.orange)
                }

                ForEach(busViewModel.buses) { bus in
                    Annotation(bus.number, coordinate: bus.coordinate) {
                        BusMarker(bus: bus, isSelected: bus.id == selectedBusId)
                            .onTapGesture {
                                select(bus)
                            }
                    }
                    // The trip card already shows the selected bus's name, and the
                    // label would cover the heading arrow when the bus drives south.
                    .annotationTitles(bus.id == selectedBusId ? .hidden : .automatic)
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
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
            .safeAreaInset(edge: .bottom) {
                if let bus = selectedBus {
                    TripCard(bus: bus,
                             busViewModel: busViewModel,
                             followBus: $followBus,
                             onDetails: { showDetail = true },
                             onClose: { selectedBusId = nil })
                        .transition(.move(edge: .bottom))
                }
            }
            .animation(.spring, value: selectedBusId)
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
            locationPermission.requestWhenInUseAuthorization()
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
        // Follow mode: keep the camera on the selected bus as it moves.
        .onChange(of: selectedBus?.lat) {
            if followBus, let bus = selectedBus {
                withAnimation(.easeInOut(duration: 1)) {
                    camera = .camera(MapCamera(centerCoordinate: bus.coordinate, distance: 4000))
                }
            }
        }
        // The selected bus ended its trip.
        .onChange(of: busViewModel.buses.count) {
            if selectedBusId != nil && selectedBus == nil {
                selectedBusId = nil
            }
        }
    }

    func select(_ bus: Bus) {
        selectedBusId = bus.id
        followBus = true
        busViewModel.loadRoute(for: bus)
        busViewModel.refreshETA(for: bus, force: true)
        withAnimation(.easeInOut(duration: 1)) {
            camera = .camera(MapCamera(centerCoordinate: bus.coordinate, distance: 4000))
        }
    }
}

// The bus icon: colour shows the crowd level, the ring shows who may ride it,
// and the small arrow points where the bus is heading.
struct BusMarker: View {
    let bus: Bus
    let isSelected: Bool
    @State private var pulse = false

    var body: some View {
        ZStack {
            // A ring that keeps spreading out, so live buses look "alive".
            if !bus.isStale {
                Circle()
                    .stroke(bus.allocation.color, lineWidth: 2)
                    .frame(width: 36, height: 36)
                    .scaleEffect(pulse ? 2 : 1)
                    .opacity(pulse ? 0 : 0.7)
                    .onAppear {
                        withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                            pulse = true
                        }
                    }
            }
            Image(systemName: "bus.fill")
                .padding(8)
                .foregroundColor(.white)
                .background(bus.crowd.color)
                .clipShape(Circle())
                .overlay(Circle().stroke(bus.allocation.color, lineWidth: 3))
                .opacity(bus.isStale ? 0.5 : 1)
            // Drawn after the icon so it sits on top, just outside the ring.
            if let heading = bus.heading {
                Image(systemName: "arrowtriangle.up.fill")
                    .font(.system(size: 12))
                    .foregroundColor(bus.allocation.color)
                    .offset(y: -27)
                    .rotationEffect(.degrees(heading))
            }
        }
        .scaleEffect(isSelected ? 1.3 : 1)
        .shadow(radius: isSelected ? 4 : 1)
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: isSelected)
    }
}
