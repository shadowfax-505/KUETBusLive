//
//  TripCard.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  The sheet at the bottom of the map for the selected bus, like the trip sheet
//  in a ride-hailing app:
//  - a compact header: the route, the bus (with a small "Crowded" tag only when
//    riders on board said so), and the ETA and distance on the right
//  - a thin track from KUET to my stop, with the stops as dots
//  - one small grey line only when the bus has gone quiet
//  - the best place to wait and to get off (PlanCard)
//  - a row of round buttons with captions
//
//  Selecting a bus also shows it on the Lock Screen and in the Dynamic Island
//  (LiveMapView starts the Live Activity), so there is no button for that.
//
//  It has two heights, like a sheet's detents: drag the handle (or tap it) to
//  show less or more. TimelineView redraws it every second, so "last seen"
//  times count up live between GPS updates.
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
                        staleLine
                    }
                    // Kept at the smaller height too: where to wait and get off is the main answer.
                    PlanCard(bus: bus, planner: planner, busViewModel: busViewModel, canBoard: canBoard,
                             onWhereTo: onWhereTo, onCompare: onCompare)
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
            // A small tap on the phone when the card changes height.
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
            TopDownBus(crowd: bus.isCrowded() ? MapTheme.terracotta : MapTheme.sage)
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
                if bus.isCrowded() {
                    CrowdedTag()
                }
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

    // MARK: Signal

    // One small grey line, only when the bus has gone quiet.
    var staleLine: some View {
        Label {
            Text("Last seen \(bus.lastUpdateText) · position may be old")
        } icon: {
            Image(systemName: "wifi.exclamationmark")
                .foregroundStyle(.orange)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.top, -6)
        .accessibilityElement(children: .combine)
    }

    // MARK: Actions

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

            RoundAction(icon: "info", caption: String(localized: "Details"), action: onDetails)

            RoundAction(icon: "location.north.line.fill", caption: String(localized: "Recenter"),
                        isOn: followBus, action: onRecenter)
                .accessibilityLabel("Keep the map on this bus")
                .accessibilityValue(followBus ? String(localized: "On") : String(localized: "Off"))
        }
    }
}

// A small muted "Crowded" tag, shown only while a rider on board says so.
struct CrowdedTag: View {
    var body: some View {
        Label("Crowded", systemImage: "person.3.fill")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(MapTheme.terracotta)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(MapTheme.terracotta.opacity(0.12), in: Capsule())
            .accessibilityLabel("Crowded")
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
