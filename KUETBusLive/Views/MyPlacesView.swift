//
//  MyPlacesView.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Profile > My places. Riders save up to five spots between official stops
//  (home, tuition) and choose where they get on the bus: their official stop
//  or one of these places. ETAs, the progress track, arrival alerts, the widget
//  and the Live Activity then all use that boarding point.
//

import SwiftUI
import MapKit

struct MyPlacesView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var placesViewModel = PlacesViewModel()
    @AppStorage(PlacesViewModel.boardingPlaceKey) private var boardingPlaceId = ""
    @State private var showAdd = false

    var body: some View {
        List {
            Section(header: Text("I get on the bus at"),
                    footer: Text("Riders often get on between stops by asking the driver or waving. Pick where you usually wait.")) {
                Picker("Boarding point", selection: $boardingPlaceId) {
                    Text(officialStopTitle).tag("")
                    ForEach(placesViewModel.places) { place in
                        Label(place.label, systemImage: place.kind.icon).tag(place.id ?? "")
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Section(header: Text("My places (\(placesViewModel.places.count) of \(MyPlace.maxCount))")) {
                ForEach(placesViewModel.places) { place in
                    PlaceRow(place: place, placesViewModel: placesViewModel)
                }
                .onDelete { offsets in
                    guard let uid = authViewModel.user?.uid else { return }
                    for index in offsets {
                        placesViewModel.delete(placesViewModel.places[index], uid: uid)
                    }
                }
                if placesViewModel.canAddMore {
                    Button {
                        showAdd = true
                    } label: {
                        Label("Add a place", systemImage: "plus.circle")
                    }
                }
            }
        }
        .navigationTitle("My places")
        .sheet(isPresented: $showAdd) {
            AddPlaceView(placesViewModel: placesViewModel)
        }
        .onAppear {
            if let uid = authViewModel.user?.uid {
                placesViewModel.startListening(uid: uid)
            }
        }
        .onDisappear { placesViewModel.stopListening() }
    }

    var officialStopTitle: String {
        if let stop = authViewModel.profile?.favoriteStopName {
            return String(localized: "My stop: \(PlaceNames.display(stop))")
        }
        return String(localized: "My stop (not set yet)")
    }
}

// One place: its icon, label, and how close the nearest route passes.
struct PlaceRow: View {
    let place: MyPlace
    @ObservedObject var placesViewModel: PlacesViewModel

    var body: some View {
        HStack {
            Image(systemName: place.kind.icon)
                .foregroundColor(.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(place.label)
                    .font(.headline)
                RouteDistanceText(coordinate: place.coordinate, placesViewModel: placesViewModel)
            }
        }
    }
}

// "120 m from KUET to Sonadanga", in orange with a warning when it is over 300 m.
struct RouteDistanceText: View {
    let coordinate: CLLocationCoordinate2D
    @ObservedObject var placesViewModel: PlacesViewModel

    var body: some View {
        if let closest = placesViewModel.closestRoute(to: coordinate) {
            let metres = Int(closest.snap.distanceFromRoute.rounded())
            let far = closest.snap.distanceFromRoute > PathMath.farFromRouteMetres
            Label(far ? String(localized: "\(metres) m from \(closest.route.displayName). The bus may not pass close enough.")
                      : String(localized: "\(metres) m from \(closest.route.displayName)"),
                  systemImage: far ? "exclamationmark.triangle.fill" : "point.topleft.down.to.point.bottomright.curvepath")
                .font(.caption)
                .foregroundColor(far ? .orange : .secondary)
        } else {
            Text("Loading routes...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// Drop a pin: move the map until the pin in the middle is on the spot, then save.
struct AddPlaceView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject var placesViewModel: PlacesViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var camera: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 22.8456, longitude: 89.5403),
        span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)))
    @State private var center = CLLocationCoordinate2D(latitude: 22.8456, longitude: 89.5403)
    @State private var label = ""
    @State private var kind = PlaceKind.home
    @State private var errorMessage = ""
    @State private var isSaving = false

    var snapped: PathMath.Snap? {
        placesViewModel.closestRoute(to: center)?.snap
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Map(position: $camera) {
                    UserAnnotation()
                    // Every route's road, so the rider can see where buses pass.
                    ForEach(placesViewModel.routes) { route in
                        if let id = route.id, let path = placesViewModel.routePaths[id] {
                            MapPolyline(coordinates: path)
                                .stroke(.blue.opacity(0.5), lineWidth: 4)
                        }
                    }
                    // Where the bus would pick you up, joined to your pin.
                    if let snap = snapped {
                        MapPolyline(coordinates: [center, snap.point])
                            .stroke(.orange, style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                        Annotation("", coordinate: snap.point) {
                            Circle().fill(.orange).frame(width: 12, height: 12)
                        }
                    }
                }
                .onMapCameraChange { context in
                    center = context.region.center
                }
                .overlay {
                    Image(systemName: "mappin")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                        .offset(y: -18)
                        .accessibilityHidden(true)
                }

                Form {
                    TextField("Name, e.g. Home", text: $label)
                    Picker("Type", selection: $kind) {
                        ForEach(PlaceKind.allCases) { kind in
                            Label(kind.title, systemImage: kind.icon).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    RouteDistanceText(coordinate: center, placesViewModel: placesViewModel)
                    if !errorMessage.isEmpty {
                        Text(errorMessage).foregroundColor(.red)
                    }
                }
                .frame(height: 230)
            }
            .navigationTitle("Add a place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
    }

    func save() {
        guard let uid = authViewModel.user?.uid else { return }
        isSaving = true
        placesViewModel.add(label: label, kind: kind, coordinate: center, uid: uid) { error in
            isSaving = false
            if let error = error {
                errorMessage = error
            } else {
                dismiss()
            }
        }
    }
}
