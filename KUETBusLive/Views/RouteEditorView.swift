//
//  RouteEditorView.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Transport admin: create or edit a bus route.
//  - Tap the map to add a stop there. MapReader turns the tap's screen point
//    into a map coordinate.
//  - Rename stops in the list, drag them to change the order, swipe to delete.
//  - Save writes the whole route to the Firestore "routes" collection.
//

import SwiftUI
import MapKit

struct RouteEditorView: View {
    @ObservedObject var routeViewModel: RouteViewModel
    @Environment(\.dismiss) private var dismiss

    // A copy of the route that is only saved when the admin taps Save.
    @State private var route: BusRoute
    @State private var camera: MapCameraPosition
    @State private var isSaving = false
    @State private var errorMessage = ""

    init(route: BusRoute?, routeViewModel: RouteViewModel) {
        self.routeViewModel = routeViewModel
        let start = route ?? BusRoute(name: "", stops: [])
        _route = State(initialValue: start)
        // Start the map on the route's first stop, or on KUET for a new route.
        let center = start.stops.first?.coordinate ?? LiveMapView.kuetCenter
        _camera = State(initialValue: .region(MKCoordinateRegion(
            center: center, span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12))))
    }

    var isNew: Bool {
        route.id == nil
    }

    var canSave: Bool {
        !route.name.trimmingCharacters(in: .whitespaces).isEmpty && route.stops.count >= 2 && !isSaving
    }

    var body: some View {
        List {
            Section {
                TextField("Route name, e.g. KUET to Sonadanga", text: $route.name)
                // Optional. Shown to people using the app in Bangla.
                TextField("Bangla name (optional)", text: banglaBinding($route.nameBn))
            } header: {
                Text("Name")
            }

            Section {
                MapReader { proxy in
                    Map(position: $camera) {
                        if route.stops.count >= 2 {
                            MapPolyline(coordinates: route.stops.map { $0.coordinate })
                                .stroke(.blue.opacity(0.6), lineWidth: 4)
                        }
                        ForEach(Array(route.stops.enumerated()), id: \.offset) { index, stop in
                            Annotation(stop.name, coordinate: stop.coordinate) {
                                Text("\(index + 1)")
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                    .frame(width: 24, height: 24)
                                    .background(Circle().fill(.blue))
                                    .accessibilityLabel("Stop \(index + 1), \(stop.name)")
                            }
                        }
                    }
                    // Convert where the finger touched on screen into latitude and longitude.
                    .onTapGesture { screenPoint in
                        if let coordinate = proxy.convert(screenPoint, from: .local) {
                            addStop(at: coordinate)
                        }
                    }
                }
                .frame(height: 280)
                .listRowInsets(EdgeInsets())
            } header: {
                Text("Map")
            } footer: {
                Text("Tap the map to add a stop at that spot. The line joins the stops in order.")
            }

            Section {
                if route.stops.isEmpty {
                    Text("No stops yet")
                        .foregroundColor(.secondary)
                }
                // Identified by position, so typing a new name doesn't reset the text field.
                ForEach(route.stops.indices, id: \.self) { index in
                    HStack {
                        Text("\(index + 1)")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(.blue))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading) {
                            TextField("Stop name", text: $route.stops[index].name)
                            TextField("Bangla name (optional)", text: banglaBinding($route.stops[index].nameBn))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onMove { from, to in
                    route.stops.move(fromOffsets: from, toOffset: to)
                }
                .onDelete { offsets in
                    route.stops.remove(atOffsets: offsets)
                }
            } header: {
                HStack {
                    Text("Stops (\(route.stops.count))")
                    Spacer()
                    EditButton()
                        .font(.caption)
                }
            } footer: {
                Text("Tap Edit to drag stops into the right order. Swipe a stop to delete it. A route needs at least two stops.")
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
        }
        .navigationTitle(isNew ? "New route" : "Edit route")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(!canSave)
            }
        }
    }

    func addStop(at coordinate: CLLocationCoordinate2D) {
        let stop = Stop(name: "Stop \(route.stops.count + 1)",
                        lat: coordinate.latitude,
                        lng: coordinate.longitude)
        withAnimation {
            route.stops.append(stop)
        }
    }

    // A text field for an optional Bangla name: an empty field saves no Bangla name,
    // so the app falls back to its built-in list or the English name.
    func banglaBinding(_ value: Binding<String?>) -> Binding<String> {
        Binding(
            get: { value.wrappedValue ?? "" },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                value.wrappedValue = trimmed.isEmpty ? nil : newValue
            }
        )
    }

    func save() {
        isSaving = true
        errorMessage = ""
        route.name = route.name.trimmingCharacters(in: .whitespaces)
        routeViewModel.save(route) { error in
            isSaving = false
            if let error = error {
                errorMessage = String(localized: "Could not save: \(error)")
            } else {
                dismiss()
            }
        }
    }
}
