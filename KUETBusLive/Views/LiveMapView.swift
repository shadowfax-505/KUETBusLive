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
    @EnvironmentObject var announcementViewModel: AnnouncementViewModel
    @StateObject private var busViewModel = BusViewModel()
    // The rider's own places, and which one they board at ("" = their official stop).
    @StateObject private var placesViewModel = PlacesViewModel()
    @AppStorage(PlacesViewModel.boardingPlaceKey) private var boardingPlaceId = ""
    // Smart suggestions: today's timetable and what the app has learned.
    @StateObject private var scheduleViewModel = ScheduleViewModel()
    @ObservedObject private var rideHistory = RideHistory.shared
    @AppStorage(RideHistory.suggestionsOnKey) private var suggestionsOn = true
    @State private var hideSuggestion = false

    static let kuetCenter = CLLocationCoordinate2D(latitude: 22.8700, longitude: 89.5250)

    @State private var camera: MapCameraPosition = .region(
        MKCoordinateRegion(center: LiveMapView.kuetCenter,
                           span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12))
    )
    @State private var selectedBusId: String?
    @State private var followBus = true
    @State private var showDetail = false
    @State private var locationPermission = CLLocationManager()
    @State private var showAnnouncements = false
    @AppStorage(AnnouncementViewModel.showNewsKey) private var showNews = true

    // Riders see the newest announcement as a banner until they close or read it,
    // unless they turned news off in Profile.
    var bannerAnnouncement: Announcement? {
        guard showNews, authViewModel.profile?.role != .admin,
              let latest = announcementViewModel.latest,
              latest.createdAt > announcementViewModel.lastSeen else {
            return nil
        }
        return latest
    }

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
                                    .accessibilityLabel("Stop: \(stop.name)")
                            }
                        }
                    }
                }

                if let stop = authViewModel.profile?.favoriteStop {
                    Marker(stop.displayName, systemImage: "star.fill", coordinate: stop.coordinate)
                        .tint(.orange)
                }

                // My places, and where the selected bus would pick me up.
                ForEach(placesViewModel.places) { place in
                    Marker(place.label, systemImage: place.kind.icon, coordinate: place.coordinate)
                        .tint(place.id == boardingPlaceId ? .orange : .gray)
                }
                if let bus = selectedBus, let place = busViewModel.boardingPlace,
                   let point = busViewModel.boardingPoint(for: bus)?.coordinate {
                    MapPolyline(coordinates: [place.coordinate, point])
                        .stroke(.orange, style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                    Annotation(String(localized: "Pick-up point"), coordinate: point) {
                        Circle().fill(.orange).stroke(.white, lineWidth: 2).frame(width: 14, height: 14)
                    }
                }

                ForEach(busViewModel.buses) { bus in
                    Annotation(PlaceNames.display(bus.number), coordinate: bus.coordinate) {
                        BusMarker(bus: bus, isSelected: bus.id == selectedBusId)
                            .onTapGesture {
                                select(bus)
                            }
                            // VoiceOver: "Normal-1 · Rupsha, Student bus, Seats available"
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(PlaceNames.display(bus.number)), \(bus.allocation.title), \(bus.crowd.label)")
                            .accessibilityHint("Shows the trip card with the ETA")
                            .accessibilityAddTraits(.isButton)
                            .accessibilityAction {
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
                VStack(spacing: 8) {
                    if let announcement = bannerAnnouncement {
                        AnnouncementBanner(announcement: announcement,
                                           onOpen: { showAnnouncements = true },
                                           onClose: {
                                               withAnimation {
                                                   announcementViewModel.markAllRead()
                                               }
                                           })
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    if let usual = usualBus, !hideSuggestion, selectedBus == nil {
                        UsualBusCard(suggestion: usual.suggestion, schedule: usual.schedule,
                                     liveBus: usual.liveBus,
                                     usualDelay: rideHistory.usualDelay(trip: usual.schedule.title),
                                     onFollow: { followUsual(usual) },
                                     onClose: { withAnimation { hideSuggestion = true } })
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    if busViewModel.buses.isEmpty {
                        Text("No buses are running right now")
                            .padding()
                            .background(.thinMaterial)
                            .cornerRadius(10)
                    }
                }
                .padding(.top, 8)
                .animation(.spring, value: bannerAnnouncement?.id)
            }
            .sheet(isPresented: $showAnnouncements) {
                NavigationStack {
                    AnnouncementsView()
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
            scheduleViewModel.startListening()
            if let uid = authViewModel.user?.uid {
                placesViewModel.startListening(uid: uid)
            }
            locationPermission.requestWhenInUseAuthorization()
        }
        .onDisappear {
            busViewModel.stopListening()
            placesViewModel.stopListening()
            scheduleViewModel.stopListening()
        }
        .onReceive(scheduleViewModel.$schedules) { busViewModel.schedules = $0 }
        // The boarding point changed (a place was chosen, added or removed): new ETAs.
        .onChange(of: placesViewModel.places) { updateBoardingPlace() }
        .onChange(of: boardingPlaceId) { updateBoardingPlace() }
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

    // The trip the scorer thinks this rider will take next, if any.
    var usualBus: (suggestion: Suggestion, schedule: BusSchedule, liveBus: Bus?)? {
        guard suggestionsOn, let role = authViewModel.profile?.role else { return nil }
        let candidates = UsualBusFinder.candidates(from: scheduleViewModel.schedules, role: role)
        let near = UsualBusFinder.nearbyKey(me: locationPermission.location,
                                            stop: authViewModel.profile?.favoriteStop,
                                            places: placesViewModel.places)
        guard let suggestion = rideHistory.suggestion(trips: candidates.map(\.0),
                                                      currentBoardingKey: busViewModel.boardingKey?.key,
                                                      nearBoardingKey: near),
              let schedule = candidates.first(where: { $0.0 == suggestion.trip })?.1 else { return nil }
        let live = busViewModel.buses.first { $0.number == schedule.title }
        return (suggestion, schedule, live)
    }

    // One tap: board where I usually do, and follow the bus if it is already running.
    func followUsual(_ usual: (suggestion: Suggestion, schedule: BusSchedule, liveBus: Bus?)) {
        if usual.suggestion.boardingKey.hasPrefix("place:") {
            boardingPlaceId = String(usual.suggestion.boardingKey.dropFirst("place:".count))
        } else if usual.suggestion.boardingKey.hasPrefix("stop:") {
            boardingPlaceId = ""
        }
        if let bus = usual.liveBus {
            select(bus)
            busViewModel.follow(bus)
        }
    }

    func updateBoardingPlace() {
        busViewModel.boardingPlace = placesViewModel.places.first { $0.id == boardingPlaceId && !boardingPlaceId.isEmpty }
        for bus in busViewModel.buses {
            busViewModel.refreshETA(for: bus, force: true)
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
