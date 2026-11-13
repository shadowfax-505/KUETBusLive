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
//  Buses glide between GPS points and turn to face the way they drive (see
//  BusGlider and BusMotion). While any bus is gliding, TimelineView redraws the
//  map every frame; when all have arrived it stops redrawing.
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
    @EnvironmentObject var assistant: AssistantViewModel
    @EnvironmentObject var announcementsForAsk: AnnouncementViewModel
    @State private var showAsk = false
    @StateObject private var glider = BusGlider()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !glider.isGliding(at: Date()))) { timeline in
                Map(position: $camera) {
                    // The rider's own blue dot.
                    UserAnnotation()

                    if let bus = selectedBus {
                        // Whole route: the same line, faded, under everything.
                        if let path = busViewModel.routePaths[bus.routeId], !path.isEmpty {
                            MapPolyline(coordinates: path)
                                .stroke(MapTheme.route,
                                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        }
                        // The road from the bus to my stop: one solid line, black (white in dark mode).
                        let toMyStop = busViewModel.remainingPath(for: bus)
                        if !toMyStop.isEmpty {
                            MapPolyline(coordinates: toMyStop)
                                .stroke(MapTheme.routeLine,
                                        style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                        }
                        // Every stop on the route: a small dot with a ring. The first stop,
                        // where the route starts, is a square.
                        if let stops = busViewModel.routeStops[bus.routeId] {
                            ForEach(Array(stops.enumerated()), id: \.element) { index, stop in
                                Annotation(stop.displayName, coordinate: stop.coordinate) {
                                    if index == 0 {
                                        Rectangle()
                                            .fill(MapTheme.primary)
                                            .overlay(Rectangle().fill(MapTheme.surface).padding(4))
                                            .frame(width: 14, height: 14)
                                            .shadow(color: .black.opacity(0.2), radius: 1.5, y: 1)
                                            .accessibilityLabel("Start: \(stop.displayName)")
                                    } else {
                                        Circle()
                                            .fill(MapTheme.stopFill)
                                            .stroke(MapTheme.primary, lineWidth: 2)
                                            .frame(width: 9, height: 9)
                                            .accessibilityLabel("Stop: \(stop.displayName)")
                                    }
                                }
                                .annotationTitles(.hidden)
                            }
                        }
                        // My stop: a ring, with a pill showing how long until the bus gets there.
                        if let point = busViewModel.boardingPoint(for: bus) {
                            Annotation(PlaceNames.display(point.name), coordinate: point.coordinate, anchor: .center) {
                                Circle()
                                    .strokeBorder(MapTheme.primary, lineWidth: 4)
                                    .background(Circle().fill(MapTheme.surface))
                                    .frame(width: 18, height: 18)
                                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                                    // The ring sits on the stop; the pill hangs off to its right.
                                    .overlay(alignment: .leading) {
                                        if let minutes = bus.id.flatMap({ busViewModel.etaInfo[$0]?.minutes }) {
                                            Text("\(minutes) min")
                                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                                .foregroundStyle(MapTheme.primary)
                                                .contentTransition(.numericText())
                                                .mapPill()
                                                .fixedSize()
                                                .offset(x: 26)
                                        }
                                    }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("Your stop: \(PlaceNames.display(point.name))")
                            }
                            .annotationTitles(.hidden)
                        }
                    }

                    // My stop. While a bus is selected it is drawn as the ring with the ETA pill instead.
                    if selectedBus == nil, let stop = authViewModel.profile?.favoriteStop {
                        Marker(stop.displayName, systemImage: "star.fill", coordinate: stop.coordinate)
                            .tint(MapTheme.primary)
                    }

                    // My places, and where the selected bus would pick me up.
                    ForEach(placesViewModel.places) { place in
                        Marker(place.label, systemImage: place.kind.icon, coordinate: place.coordinate)
                            .tint(place.id == boardingPlaceId ? MapTheme.primary : .gray)
                    }
                    if let bus = selectedBus, let place = busViewModel.boardingPlace,
                       let point = busViewModel.boardingPoint(for: bus)?.coordinate {
                        MapPolyline(coordinates: [place.coordinate, point])
                            .stroke(MapTheme.primary, style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                        Annotation(String(localized: "Pick-up point"), coordinate: point) {
                            Circle().fill(MapTheme.primary).stroke(MapTheme.surface, lineWidth: 2).frame(width: 14, height: 14)
                        }
                    }

                    ForEach(busViewModel.buses) { bus in
                        Annotation(PlaceNames.display(bus.number),
                                   coordinate: glider.position(of: bus, at: timeline.date,
                                                               route: busViewModel.routePaths[bus.routeId]),
                                   anchor: .center) {
                            BusMarker(bus: bus,
                                      heading: glider.heading(of: bus, at: timeline.date,
                                                              route: busViewModel.routePaths[bus.routeId]),
                                      isSelected: bus.id == selectedBusId)
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
                // Muted colours with fewer shops and places, so the buses and the route stand out.
                .mapStyle(.standard(elevation: .flat, emphasis: .muted,
                                    pointsOfInterest: .including([.university, .publicTransport])))
                .mapControls {
                    MapCompass()
                    MapScaleView()
                }
            }
            .overlay(alignment: .top) {
                VStack(spacing: 8) {
                    if let bus = selectedBus {
                        SelectedPlaceBar(title: busViewModel.boardingPoint(for: bus).map { PlaceNames.display($0.name) }
                                            ?? PlaceNames.display(bus.routeName),
                                         onBack: { selectedBusId = nil })
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
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
                            .font(.subheadline.weight(.medium))
                            .mapPill()
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
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(alignment: .trailing, spacing: 12) {
                    // With a bus selected, the trip card has its own recenter button.
                    if let bus = selectedBus {
                        TripCard(bus: bus,
                                 busViewModel: busViewModel,
                                 followBus: $followBus,
                                 onDetails: { showDetail = true },
                                 onRecenter: recenter,
                                 onClose: { selectedBusId = nil })
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        Button(action: recenter) {
                            Image(systemName: "location.fill")
                        }
                        .buttonStyle(MapRoundButtonStyle())
                        .accessibilityLabel("Recenter map")
                        .padding(.trailing, 16)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .padding(.bottom, selectedBus == nil ? 12 : 0)
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: selectedBusId)
            .navigationTitle("Live Buses")
            // Riders: ask a question about today's buses.
            .toolbar {
                // Always offered to riders: without the model, the timetable answers.
                if authViewModel.profile?.role != .admin {
                    Button {
                        showAsk = true
                    } label: {
                        Label("Ask", systemImage: "bubble.left.and.text.bubble.right")
                    }
                }
            }
            .sheet(isPresented: $showAsk) {
                AskView(makePrompt: askPrompt, fallback: timetableAnswer)
            }
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
        // New GPS points: start gliding each bus from where it is drawn to its new point.
        .onReceive(busViewModel.$buses) { glider.update(with: $0, reduceMotion: reduceMotion) }
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
        // The camera moves at the same steady pace as the bus glides, so the bus stays centred.
        .onChange(of: selectedBus?.lat) {
            if followBus, let bus = selectedBus {
                let target = BusMotion.snapped(bus.coordinate, to: busViewModel.routePaths[bus.routeId])
                withAnimation(reduceMotion ? nil : .linear(duration: max(glider.duration(of: bus), 1))) {
                    camera = .camera(MapCamera(centerCoordinate: target, distance: 4000))
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

    // The data an answer may use: today's trips, my boarding point, live buses, the news.
    func askPrompt(_ question: String) -> String {
        let live = busViewModel.buses.map { bus in
            (name: bus.number, eta: bus.id.flatMap { busViewModel.etaText[$0] })
        }
        return RiderQuestion.prompt(question: question, now: Date(), schedules: scheduleViewModel.schedules,
                                    role: authViewModel.profile?.role ?? .student,
                                    boarding: busViewModel.boardingKey?.name, liveBuses: live,
                                    announcements: announcementsForAsk.visibleAnnouncements)
    }

    // The same question answered from the timetable alone, when the model can't.
    func timetableAnswer(_ question: String) -> String {
        TimetableAnswerer.answer(question: question, now: Date(), schedules: scheduleViewModel.schedules,
                                 role: authViewModel.profile?.role ?? .student,
                                 liveBuses: busViewModel.buses.map(\.number))
    }

    func updateBoardingPlace() {
        busViewModel.boardingPlace = placesViewModel.places.first { $0.id == boardingPlaceId && !boardingPlaceId.isEmpty }
        for bus in busViewModel.buses {
            busViewModel.refreshETA(for: bus, force: true)
        }
    }

    // Back to the selected bus, or to me when no bus is selected.
    func recenter() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.8)) {
            if let bus = selectedBus {
                followBus = true
                camera = .camera(MapCamera(centerCoordinate: bus.coordinate, distance: 4000))
            } else {
                camera = .userLocation(fallback: .region(
                    MKCoordinateRegion(center: LiveMapView.kuetCenter,
                                       span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12))))
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

// The capsule at the top of the map while a bus is selected: a round back
// button and the name of the stop or place the rider boards at.
struct SelectedPlaceBar: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(MapRoundButtonStyle())
            .accessibilityLabel("Back")

            HStack(spacing: 8) {
                Rectangle()
                    .fill(MapTheme.primary)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MapTheme.primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MapTheme.surface, in: Capsule())
            .shadow(color: .black.opacity(0.16), radius: 8, y: 3)
            .accessibilityElement(children: .combine)
        }
        .padding(.horizontal, 16)
    }
}
