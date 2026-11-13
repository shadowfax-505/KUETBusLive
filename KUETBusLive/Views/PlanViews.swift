//
//  PlanViews.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  The "best place to wait" and "best place to get off" parts of the trip card,
//  the destination search (Apple Maps search plus My places), and the list that
//  compares today's buses for one destination.
//

import SwiftUI
import MapKit

// MARK: - Text for a plan

enum PlanText {
    static func catchTitle(_ plan: CatchPlan) -> String {
        switch plan.point.kind {
        case .stop:
            return String(localized: "Wait at \(plan.point.name)")
        case .spot:
            return String(localized: "Wait at the usual spot near \(plan.point.name)")
        case .nearest:
            return String(localized: "Wait by the road near \(plan.point.name)")
        }
    }

    static func catchDetail(_ plan: CatchPlan) -> String {
        if plan.leaveInMinutes == 0 {
            return String(localized: "\(plan.walkMinutes) min walk · Leave now")
        }
        return String(localized: "\(plan.walkMinutes) min walk · Leave in \(plan.leaveInMinutes) min")
    }

    static func dropTitle(_ plan: DropPlan) -> String {
        if case .stop = plan.point.kind {
            return String(localized: "Get off at \(plan.point.name)")
        }
        return String(localized: "Get off near \(plan.point.name)")
    }

    static func arrival(_ seconds: Double, from now: Date = Date()) -> String {
        now.addingTimeInterval(seconds).formatted(date: .omitted, time: .shortened)
    }

    static func dropDetail(_ plan: DropPlan, extra: Double = 0) -> String {
        String(localized: "Arrive ~\(arrival(plan.arrivalSeconds + extra)) · \(plan.walkMinutes) min walk")
    }

    // How sure: from past trips, or only from the road distance.
    static func confidence(samples: Int) -> String {
        samples > 0 ? String(localized: "From \(samples) past trips")
                    : String(localized: "Road-distance estimate")
    }
}

// MARK: - In the trip card

struct PlanCard: View {
    let bus: Bus
    @ObservedObject var planner: TripPlanner
    @ObservedObject var busViewModel: BusViewModel
    let canBoard: Bool
    let onWhereTo: () -> Void
    let onCompare: () -> Void
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if canBoard, let plan = planner.catchPlan {
                catchRow(plan)
                Divider().padding(.leading, 56)
            }
            if let plan = planner.dropPlan, let destination = planner.destination {
                dropRow(plan, destination: destination)
            } else {
                Button(action: onWhereTo) {
                    PlanRow(icon: "magnifyingglass", title: String(localized: "Where to?"),
                            detail: String(localized: "Find the best place to get off"))
                }
                .buttonStyle(.plain)
            }
        }
        .background(MapTheme.raised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    func catchRow(_ plan: CatchPlan) -> some View {
        HStack(spacing: 8) {
            PlanRow(icon: "figure.walk", title: PlanText.catchTitle(plan), detail: PlanText.catchDetail(plan),
                    note: PlanText.confidence(samples: plan.samples))
            if let uid = authViewModel.user?.uid {
                let waving = busViewModel.wavingAtBusId == bus.id
                Button(waving ? String(localized: "Waving") : String(localized: "Wave here")) {
                    if !waving {
                        busViewModel.wave(at: bus, uid: uid, label: plan.point.name, point: plan.point.coordinate)
                    }
                }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .tint(MapTheme.primary)
                .disabled(waving)
                .padding(.trailing, 12)
                .accessibilityHint("Tells the driver you wait at this point")
            }
        }
    }

    func dropRow(_ plan: DropPlan, destination: Destination) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            PlanRow(icon: "flag.checkered", title: PlanText.dropTitle(plan), detail: PlanText.dropDetail(plan),
                    note: String(localized: "To \(destination.name)") + " · " + PlanText.confidence(samples: plan.samples))
            HStack(spacing: 8) {
                if let uid = authViewModel.user?.uid, canBoard {
                    if planner.requestedBusId == bus.id {
                        Button("Cancel stop") {
                            planner.cancelStop(uid: uid, busViewModel: busViewModel)
                        }
                        .tint(.orange)
                    } else {
                        Button("Ask to stop here") {
                            planner.requestStop(bus: bus, uid: uid, busViewModel: busViewModel)
                        }
                        .tint(MapTheme.primary)
                        .accessibilityHint("Tells the driver to stop at this point")
                    }
                }
                Button("Compare", action: onCompare)
                    .tint(MapTheme.primary)
                Spacer(minLength: 0)
                Button {
                    planner.destination = nil
                } label: {
                    Image(systemName: "xmark")
                }
                .tint(.secondary)
                .accessibilityLabel("Clear destination")
            }
            .font(.footnote.weight(.semibold))
            .lineLimit(1)
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .padding(.leading, 56)
            .padding(.trailing, 12)
            .padding(.bottom, 12)
        }
    }
}

// Icon in a circle, a title, a detail line and an optional grey note.
struct PlanRow: View {
    let icon: String
    let title: String
    let detail: String
    var note: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(MapTheme.buttonText)
                .frame(width: 32, height: 32)
                .background(MapTheme.buttonFill, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MapTheme.primary)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(MapTheme.primary)
                if let note {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Destination search

struct DestinationSearchView: View {
    let places: [MyPlace]
    let onPick: (Destination) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var search = PlaceSearch()

    var body: some View {
        NavigationStack {
            List {
                if search.query.isEmpty && !places.isEmpty {
                    Section("My places") {
                        ForEach(places) { place in
                            Button {
                                pick(Destination(name: place.label, coordinate: place.coordinate))
                            } label: {
                                Label(place.label, systemImage: place.kind.icon)
                            }
                        }
                    }
                }
                Section {
                    ForEach(search.results, id: \.self) { result in
                        Button {
                            search.resolve(result) { destination in
                                if let destination { pick(destination) }
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.title)
                                    .foregroundStyle(MapTheme.primary)
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Where to?")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search.query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: Text("Search a place in Khulna"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    func pick(_ destination: Destination) {
        onPick(destination)
        dismiss()
    }
}

// Apple Maps search suggestions around Khulna.
final class PlaceSearch: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var query = "" {
        didSet { completer.queryFragment = query }
    }
    @Published private(set) var results: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()

    static let khulna = MKCoordinateRegion(center: LiveMapView.kuetCenter,
                                           span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3))

    override init() {
        super.init()
        completer.delegate = self
        completer.region = Self.khulna
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        results = []
    }

    func resolve(_ completion: MKLocalSearchCompletion, done: @escaping (Destination?) -> Void) {
        let request = MKLocalSearch.Request(completion: completion)
        request.region = Self.khulna
        MKLocalSearch(request: request).start { response, _ in
            guard let item = response?.mapItems.first else {
                done(nil)
                return
            }
            done(Destination(name: completion.title, coordinate: item.placemark.coordinate))
        }
    }
}

// MARK: - Compare buses

struct TripOptionsView: View {
    let destination: Destination
    let options: [TripOption]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if options.isEmpty {
                    ContentUnavailableView("No bus gets you there today",
                                           systemImage: "bus",
                                           description: Text("Running buses you can reach, and trips later today, are compared."))
                }
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(option.title)
                                .font(.headline)
                            if index == 0 {
                                Text("Fastest")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(MapTheme.raised, in: Capsule())
                            }
                            Spacer()
                            Text(PlanText.arrival(option.arrivalSeconds))
                                .font(.headline.monospacedDigit())
                        }
                        if let plan = option.catchPlan {
                            Text(PlanText.catchTitle(plan) + " · " + leaveText(option))
                                .font(.subheadline)
                        }
                        Text(PlanText.dropTitle(option.dropPlan) + " · "
                             + String(localized: "\(option.dropPlan.walkMinutes) min walk"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                }
            }
            .navigationTitle(String(localized: "To \(destination.name)"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    func leaveText(_ option: TripOption) -> String {
        let minutes = Int((option.leaveInSeconds ?? 0) / 60)
        if minutes <= 0 {
            return String(localized: "Leave now")
        }
        if minutes >= 60 {
            return String(localized: "Leave at \(PlanText.arrival(Double(minutes) * 60))")
        }
        return String(localized: "Leave in \(minutes) min")
    }
}
