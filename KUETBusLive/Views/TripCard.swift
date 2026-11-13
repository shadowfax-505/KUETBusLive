//
//  TripCard.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  The sheet at the bottom of the map for the selected bus, like the trip sheet
//  in a ride-hailing app:
//  - a compact header: the route, the bus, and the ETA and distance on the right
//  - a thin track from KUET to my stop, with the stops as dots
//  - three small tiles: speed, crowd and the last update
//  - a one-line banner only when the bus has gone quiet
//  - the best place to wait and to get off (PlanCard)
//  - one main button, then a row of round buttons with captions
//
//  It has two heights, like a sheet's detents: drag the handle (or tap it) to
//  show less or more. Showing less keeps the header, the track and the main
//  button, so more of the map is visible. TimelineView redraws it every second,
//  so "updated" times count up live between GPS updates.
//

import SwiftUI

struct TripCard: View {
    let bus: Bus
    @ObservedObject var busViewModel: BusViewModel
    @Binding var followBus: Bool
    @ObservedObject var planner: TripPlanner
    let onDetails: () -> Void
    let onRecenter: () -> Void
    let onWhereTo: () -> Void
    let onCompare: () -> Void
    let onClose: () -> Void
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject private var liveActivity = LiveActivityManager.shared

    // Remembered between buses, like a sheet left at its smaller height.
    @AppStorage("tripCardExpanded") private var expanded = true
    @GestureState private var dragOffset: CGFloat = 0

    // With very large text (Settings > Accessibility > Larger Text), rows that sit
    // side by side are stacked instead, so nothing gets cut off.
    @Environment(\.dynamicTypeSize) private var typeSize

    static let spacing: CGFloat = 16

    var bigText: Bool {
        typeSize.isAccessibilitySize
    }

    var canBoard: Bool {
        bus.allocation.canBoard(authViewModel.profile?.role ?? .student)
    }

    var boardingName: String? {
        busViewModel.boardingPoint(for: bus).map { PlaceNames.display($0.name) }
    }

    var eta: RouteInfo? {
        bus.id.flatMap { busViewModel.etaInfo[$0] }
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            // With large text the card can get tall, so it scrolls instead of covering the map.
            ScrollView {
                VStack(alignment: .leading, spacing: Self.spacing) {
                    grabber
                    header
                    progress
                    if bus.isStale {
                        staleBanner
                    }
                    // Kept at the smaller height too: where to wait and get off is the main answer.
                    PlanCard(bus: bus, planner: planner, busViewModel: busViewModel, canBoard: canBoard,
                             onWhereTo: onWhereTo, onCompare: onCompare)
                    if expanded {
                        statTiles
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    primaryAction
                    if expanded {
                        secondaryActions
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.horizontal, Self.spacing)
                .padding(.bottom, Self.spacing)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDisabled(!bigText)
            .frame(maxHeight: bigText ? 460 : nil)
            .fixedSize(horizontal: false, vertical: !bigText)
            // Rounded at the top only, and flush with the bottom of the screen, like a sheet.
            .background(MapTheme.surface,
                        in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous))
            .background(MapTheme.surface.ignoresSafeArea(edges: .bottom).padding(.top, 40))
            .shadow(color: .black.opacity(0.12), radius: 20, y: -4)
            .offset(y: max(dragOffset, 0) * 0.4)
            .gesture(bigText ? nil : resizeGesture)
            .animation(.spring(response: 0.4, dampingFraction: 0.86), value: expanded)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Trip card for \(PlaceNames.display(bus.number))")
            // A small tap on the phone when a crowd report lands, and when the card changes height.
            .sensoryFeedback(.success, trigger: bus.crowd)
            .sensoryFeedback(.selection, trigger: expanded)
        }
    }

    // Drag up for more, down for less. Dragging down from the smaller height closes the card.
    var resizeGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($dragOffset) { value, state, _ in
                state = value.translation.height
            }
            .onEnded { value in
                let dy = value.predictedEndTranslation.height
                if dy < -60 {
                    expanded = true
                } else if dy > 60 {
                    if expanded {
                        expanded = false
                    } else {
                        onClose()
                    }
                }
            }
    }

    // MARK: Header

    // The handle, which also works as a button for VoiceOver, and the close button.
    var grabber: some View {
        ZStack {
            Capsule()
                .fill(.secondary.opacity(0.35))
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity, minHeight: 20)
                .contentShape(Rectangle())
                .onTapGesture { expanded.toggle() }
                .accessibilityElement()
                .accessibilityLabel(expanded ? "Show less" : "Show more")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { expanded.toggle() }
            HStack {
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .background(MapTheme.raised, in: Circle())
                }
                .accessibilityLabel("Close trip card")
            }
        }
        .padding(.top, 8)
        .padding(.bottom, -8)
    }

    var header: some View {
        HStack(alignment: .center, spacing: 12) {
            TopDownBus(crowd: MapTheme.crowd(bus.crowd))
                .frame(width: 14, height: 28)
                .rotationEffect(.degrees(90))
                .frame(width: 48, height: 48)
                .background(MapTheme.raised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(PlaceNames.display(bus.routeName))
                    .font(.headline)
                    .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)
                Text("\(PlaceNames.display(bus.number)) · \(bus.allocation.title)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            etaBlock
        }
        .accessibilityElement(children: .combine)
    }

    // "7 min" big, the road distance under it. Without a stop, a hint instead.
    @ViewBuilder
    var etaBlock: some View {
        if boardingName != nil {
            VStack(alignment: .trailing, spacing: 0) {
                if let eta {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(eta.minutes)")
                            .font(.system(.title, design: .rounded).weight(.bold).monospacedDigit())
                            .contentTransition(.numericText())
                            .animation(.default, value: eta.minutes)
                        Text("min")
                            .font(.subheadline.weight(.semibold))
                    }
                    Text(String(format: "%.1f km", eta.kilometres))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    Text(busViewModel.etaText[bus.id ?? ""] ?? String(localized: "Calculating..."))
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.trailing)
                }
            }
            .fixedSize()
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: Progress

    @ViewBuilder
    var progress: some View {
        if let track = busViewModel.tripProgress(for: bus), let boardingName {
            TripProgressView(progress: track, endLabel: boardingName, tint: MapTheme.primary,
                             trackColor: MapTheme.raised, refined: true,
                             stopColor: .secondary.opacity(0.6), busGlyphColor: MapTheme.buttonText)
                .animation(.easeInOut, value: track.fraction)
        } else if let near = busViewModel.nearestStop(for: bus) {
            // My stop isn't on this route: show the nearest stop instead.
            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: Double(near.index), total: Double(max(near.count - 1, 1)))
                    .tint(MapTheme.primary)
                    .animation(.easeInOut, value: near.index)
                Text("Near \(near.stop.name) · stop \(near.index + 1) of \(near.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else if boardingName == nil {
            Text("Set your stop in Routes to see the ETA.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Live facts

    var statTiles: some View {
        let layout = bigText ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            StatTile(icon: "speedometer", value: bus.speedText, caption: String(localized: "Speed"))
            StatTile(icon: "person.3.fill", value: bus.crowd.shortLabel, caption: String(localized: "Crowd"),
                     iconColor: MapTheme.crowd(bus.crowd))
                .symbolEffect(.bounce, value: bus.crowd)
            StatTile(icon: bus.isStale ? "wifi.exclamationmark" : "dot.radiowaves.left.and.right",
                     value: bus.lastUpdateText, caption: String(localized: "Updated"),
                     iconColor: bus.isStale ? MapTheme.terracotta : MapTheme.sage)
        }
    }

    // One short line, only when the bus has gone quiet.
    var staleBanner: some View {
        Label {
            Text("Last seen \(bus.lastUpdateText) · position may be old")
                .font(.footnote.weight(.medium))
                .foregroundStyle(MapTheme.primary)
        } icon: {
            Image(systemName: "wifi.exclamationmark")
                .foregroundStyle(MapTheme.terracotta)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MapTheme.terracotta.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // MARK: Actions

    // Follow on Lock Screen: a Live Activity with the ETA, also in the Dynamic Island.
    @ViewBuilder
    var primaryAction: some View {
        if boardingName != nil && liveActivity.isAvailable {
            let following = liveActivity.isFollowing(bus)
            Button {
                if following {
                    liveActivity.stop()
                } else {
                    busViewModel.follow(bus)
                }
            } label: {
                Label(following ? "Stop following" : "Follow on Lock Screen",
                      systemImage: following ? "lock.slash" : "lock.iphone")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    var secondaryActions: some View {
        let layout = bigText ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                             : AnyLayout(HStackLayout(alignment: .top, spacing: 8))
        return layout {
            // "I'm waiting here": the driver sees where you stand, without a phone call.
            if canBoard, let uid = authViewModel.user?.uid, let boardingName {
                if busViewModel.wavingAtBusId == bus.id {
                    RoundAction(icon: "hand.raised.slash.fill", caption: String(localized: "Stop waiting"),
                                isOn: true) {
                        busViewModel.cancelWave(uid: uid)
                    }
                    .accessibilityLabel("Waiting at \(boardingName) · Cancel")
                } else {
                    RoundAction(icon: "hand.wave.fill", caption: String(localized: "I'm waiting")) {
                        busViewModel.wave(at: bus, uid: uid)
                    }
                    .accessibilityLabel("I'm waiting here")
                }
            }

            // Tell other riders how full the bus is.
            if canBoard {
                Menu {
                    Button {
                        busViewModel.report(.seats, for: bus)
                    } label: {
                        Label("Seats available", systemImage: "chair")
                    }
                    Button {
                        busViewModel.report(.full, for: bus)
                    } label: {
                        Label("Full", systemImage: "person.3.fill")
                    }
                } label: {
                    RoundActionLabel(icon: "person.3", caption: String(localized: "Report crowd"))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Report crowd")
            }

            RoundAction(icon: "info", caption: String(localized: "Details"), action: onDetails)

            RoundAction(icon: "location.north.line.fill", caption: String(localized: "Recenter"),
                        isOn: followBus, action: onRecenter)
                .accessibilityLabel("Keep the map on this bus")
                .accessibilityValue(followBus ? String(localized: "On") : String(localized: "Off"))
        }
    }
}

// A small tile: icon on top, the value, and a grey caption.
struct StatTile: View {
    let icon: String
    let value: String
    let caption: String
    var iconColor: Color = MapTheme.primary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(iconColor)
                .frame(height: 18)
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(MapTheme.raised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(caption): \(value)")
    }
}

// A round icon button with a caption under it, like a phone's call screen.
struct RoundAction: View {
    let icon: String
    let caption: String
    var isOn = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundActionLabel(icon: icon, caption: caption, isOn: isOn)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

struct RoundActionLabel: View {
    let icon: String
    let caption: String
    var isOn = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let circle = Image(systemName: icon)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(isOn ? MapTheme.buttonText : MapTheme.primary)
            .frame(width: 52, height: 52)
            .background(isOn ? MapTheme.buttonFill : MapTheme.raised, in: Circle())
        let text = Text(caption)
            .font(.caption.weight(.medium))
            .foregroundStyle(MapTheme.primary)
            .multilineTextAlignment(.center)
            .lineLimit(2)
        Group {
            if typeSize.isAccessibilitySize {
                HStack(spacing: 12) { circle; text }
            } else {
                VStack(spacing: 6) { circle; text }
            }
        }
        .contentShape(Rectangle())
    }
}
