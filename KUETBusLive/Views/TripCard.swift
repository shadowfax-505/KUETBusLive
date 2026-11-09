//
//  TripCard.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  The card at the bottom of the map for the selected bus, like the trip card
//  in a ride-hailing app. TimelineView redraws it every second, so "updated"
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
            VStack(alignment: .leading, spacing: 10) {
                // Title row
                HStack(alignment: .top) {
                    rowOrColumn {
                        VStack(alignment: .leading) {
                            Text(PlaceNames.display(bus.number))
                                .font(.headline)
                            Text(PlaceNames.display(bus.routeName))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        if !bigText {
                            Spacer()
                        }
                        AudienceBadge(audience: bus.allocation)
                    }
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel("Close trip card")
                }

                // ETA, the big number riders care about: to my stop, or to the place I board at.
                if let point = busViewModel.boardingPoint(for: bus) {
                    rowOrColumn {
                        Text(busViewModel.etaText[bus.id ?? ""] ?? String(localized: "Calculating..."))
                            .font(.title2)
                            .fontWeight(.bold)
                            // Digits roll to the new value instead of jumping.
                            .contentTransition(.numericText())
                            .animation(.default, value: busViewModel.etaText[bus.id ?? ""])
                        Text("to \(PlaceNames.display(point.name))")
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Set your stop in Routes to see the ETA.")
                        .foregroundColor(.secondary)
                }

                // Where the bus is between KUET and my stop, like a parcel tracker.
                if let track = busViewModel.tripProgress(for: bus),
                   let stopName = busViewModel.boardingPoint(for: bus)?.name {
                    TripProgressView(progress: track, endLabel: PlaceNames.display(stopName), tint: bus.allocation.color)
                        .animation(.easeInOut, value: track.fraction)
                } else if let progress = busViewModel.nearestStop(for: bus) {
                    // My stop isn't on this route: show the nearest stop instead.
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Near \(progress.stop.name) · stop \(progress.index + 1) of \(progress.count)")
                            .font(.footnote)
                        ProgressView(value: Double(progress.index),
                                     total: Double(max(progress.count - 1, 1)))
                            .tint(bus.allocation.color)
                            .animation(.easeInOut, value: progress.index)
                    }
                }

                // Live facts
                rowOrColumn {
                    Label(bus.speedText, systemImage: "speedometer")
                    Spacer()
                    Label(bus.crowd.label, systemImage: "person.3.fill")
                        .foregroundColor(bus.crowd.color)
                        .symbolEffect(.bounce, value: bus.crowd)
                    Spacer()
                    Label(bus.lastUpdateText, systemImage: bus.isStale ? "wifi.exclamationmark" : "dot.radiowaves.left.and.right")
                        .accessibilityLabel("Last update \(bus.lastUpdateText)")
                        .foregroundColor(bus.isStale ? .orange : .green)
                        .symbolEffect(.pulse, isActive: !bus.isStale)
                }
                .font(.caption)

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
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(bus.allocation.color)
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
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
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
                    .accessibilityLabel("Keep the map on this bus")

                    Button("Details", action: onDetails)
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: bigText ? 420 : nil)
            .fixedSize(horizontal: false, vertical: !bigText)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Trip card for \(PlaceNames.display(bus.number))")
            .padding(.horizontal)
            .padding(.bottom, 8)
            // A small tap on the phone when a crowd report lands.
            .sensoryFeedback(.success, trigger: bus.crowd)
        }
    }
}
