//
//  TripCard.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  The sheet at the bottom of the map for the selected bus, like the trip sheet
//  in a ride-hailing app: a title, the bus in an outlined card, and one solid
//  main button. TimelineView redraws it every second, so "updated"
//  times count up live between GPS updates.
//

import SwiftUI

struct TripCard: View {
    let bus: Bus
    @ObservedObject var busViewModel: BusViewModel
    @Binding var followBus: Bool
    let onDetails: () -> Void
    let onClose: () -> Void
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject private var liveActivity = LiveActivityManager.shared

    // With very large text (Settings > Accessibility > Larger Text), rows that sit
    // side by side are stacked instead, so nothing gets cut off.
    @Environment(\.dynamicTypeSize) private var typeSize

    var bigText: Bool {
        typeSize.isAccessibilitySize
    }

    // A row normally, a column with large text.
    var rowOrColumn: AnyLayout {
        bigText ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6)) : AnyLayout(HStackLayout())
    }

    var canBoard: Bool {
        bus.allocation.canBoard(authViewModel.profile?.role ?? .student)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            // With large text the card can get tall, so it scrolls instead of covering the map.
            ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // A small handle, like a sheet, so the card reads as something on top of the map.
                Capsule()
                    .fill(.secondary.opacity(0.35))
                    .frame(width: 36, height: 5)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
                // Sheet title, with the close button.
                HStack(alignment: .firstTextBaseline) {
                    Text(PlaceNames.display(bus.routeName))
                        .font(.title3.weight(.bold))
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(MapTheme.primary)
                            .frame(width: 32, height: 32)
                            .background(MapTheme.raised, in: Circle())
                    }
                    .accessibilityLabel("Close trip card")
                }

                // The selected bus in a card with a solid outline, and its ETA on the right.
                rowOrColumn {
                    HStack(spacing: 12) {
                        TopDownBus(crowd: MapTheme.crowd(bus.crowd))
                            .frame(width: 18, height: 36)
                            .rotationEffect(.degrees(90))
                            .frame(width: 40, height: 36)
                            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(PlaceNames.display(bus.number))
                                .font(.headline)
                            AudienceBadge(audience: bus.allocation)
                        }
                    }
                    if !bigText {
                        Spacer()
                    }
                    if let point = busViewModel.boardingPoint(for: bus) {
                        VStack(alignment: bigText ? .leading : .trailing, spacing: 2) {
                            Text(busViewModel.etaText[bus.id ?? ""] ?? String(localized: "Calculating..."))
                                .font(.headline.monospacedDigit())
                                // Digits roll to the new value instead of jumping.
                                .contentTransition(.numericText())
                                .animation(.default, value: busViewModel.etaText[bus.id ?? ""])
                            Text("to \(PlaceNames.display(point.name))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(MapTheme.primary, lineWidth: 2))
                .accessibilityElement(children: .combine)

                if busViewModel.boardingPoint(for: bus) == nil {
                    Text("Set your stop in Routes to see the ETA.")
                        .foregroundColor(.secondary)
                }

                // Where the bus is between KUET and my stop, like a parcel tracker.
                if let track = busViewModel.tripProgress(for: bus),
                   let stopName = busViewModel.boardingPoint(for: bus)?.name {
                    TripProgressView(progress: track, endLabel: PlaceNames.display(stopName), tint: MapTheme.primary,
                                     busGlyphColor: MapTheme.buttonText)
                        .animation(.easeInOut, value: track.fraction)
                } else if let progress = busViewModel.nearestStop(for: bus) {
                    // My stop isn't on this route: show the nearest stop instead.
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Near \(progress.stop.name) · stop \(progress.index + 1) of \(progress.count)")
                            .font(.footnote)
                        ProgressView(value: Double(progress.index),
                                     total: Double(max(progress.count - 1, 1)))
                            .tint(MapTheme.primary)
                            .animation(.easeInOut, value: progress.index)
                    }
                }

                // Live facts, on a faint band so they read as one group.
                rowOrColumn {
                    Label(bus.speedText, systemImage: "speedometer")
                    Spacer()
                    Label(bus.crowd.label, systemImage: "person.3.fill")
                        .foregroundColor(MapTheme.crowd(bus.crowd))
                        .symbolEffect(.bounce, value: bus.crowd)
                    Spacer()
                    Label(bus.lastUpdateText, systemImage: bus.isStale ? "wifi.exclamationmark" : "dot.radiowaves.left.and.right")
                        .accessibilityLabel("Last update \(bus.lastUpdateText)")
                        .foregroundColor(bus.isStale ? MapTheme.terracotta : MapTheme.sage)
                        .symbolEffect(.pulse, isActive: !bus.isStale)
                }
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(MapTheme.raised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                if bus.isStale {
                    Text("No signal from this bus for over a minute. Its position may be out of date.")
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                // Follow on Lock Screen: a Live Activity with the ETA, also in the Dynamic Island.
                if busViewModel.boardingPoint(for: bus) != nil && liveActivity.isAvailable {
                    Button {
                        if liveActivity.isFollowing(bus) {
                            liveActivity.stop()
                        } else {
                            busViewModel.follow(bus)
                        }
                    } label: {
                        Label(liveActivity.isFollowing(bus) ? "Stop following" : "Follow on Lock Screen",
                              systemImage: liveActivity.isFollowing(bus) ? "lock.slash" : "lock.iphone")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }

                // "I'm waiting here": the driver sees where you stand, without a phone call.
                if canBoard, let uid = authViewModel.user?.uid, busViewModel.boardingPoint(for: bus) != nil {
                    if busViewModel.wavingAtBusId == bus.id {
                        Button {
                            busViewModel.cancelWave(uid: uid)
                        } label: {
                            Label("Waiting at \(PlaceNames.display(busViewModel.boardingPoint(for: bus)?.name ?? "")) · Cancel",
                                  systemImage: "hand.raised.slash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                    } else {
                        Button {
                            busViewModel.wave(at: bus, uid: uid)
                        } label: {
                            Label("I'm waiting here", systemImage: "hand.wave.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(MapTheme.primary)
                    }
                }

                // Actions
                rowOrColumn {
                    if canBoard {
                        Button("Seats") {
                            busViewModel.report(.seats, for: bus)
                        }
                        .buttonStyle(.bordered)
                        .tint(.green)

                        Button("Full") {
                            busViewModel.report(.full, for: bus)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }

                    if !bigText {
                        Spacer()
                    }

                    Toggle(isOn: $followBus) {
                        Image(systemName: "location.north.line.fill")
                    }
                    .toggleStyle(.button)
                    .tint(MapTheme.primary)
                    .accessibilityLabel("Keep the map on this bus")

                    Button("Details", action: onDetails)
                        .buttonStyle(.bordered)
                        .tint(MapTheme.primary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: bigText ? 420 : nil)
            .fixedSize(horizontal: false, vertical: !bigText)
            // Rounded at the top only, and flush with the bottom of the screen, like a sheet.
            .background(MapTheme.surface,
                        in: UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24, style: .continuous))
            .background(MapTheme.surface.ignoresSafeArea(edges: .bottom).padding(.top, 40))
            .shadow(color: .black.opacity(0.15), radius: 16, y: -2)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Trip card for \(PlaceNames.display(bus.number))")
            // A small tap on the phone when a crowd report lands.
            .sensoryFeedback(.success, trigger: bus.crowd)
        }
    }
}
