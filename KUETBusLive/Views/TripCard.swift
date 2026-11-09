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

    var canBoard: Bool {
        bus.allocation.canBoard(authViewModel.profile?.role ?? .student)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            VStack(alignment: .leading, spacing: 10) {
                // Title row
                HStack {
                    VStack(alignment: .leading) {
                        Text(bus.number)
                            .font(.headline)
                        Text(bus.routeName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    AudienceBadge(audience: bus.allocation)
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }

                // ETA, the big number riders care about
                if let stop = authViewModel.profile?.favoriteStop {
                    HStack(alignment: .firstTextBaseline) {
                        Text(busViewModel.etaText[bus.id ?? ""] ?? "Calculating...")
                            .font(.title2)
                            .fontWeight(.bold)
                            // Digits roll to the new value instead of jumping.
                            .contentTransition(.numericText())
                            .animation(.default, value: busViewModel.etaText[bus.id ?? ""])
                        Text("to \(stop.name)")
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Set your stop in Routes to see the ETA.")
                        .foregroundColor(.secondary)
                }

                // Where the bus is along its route
                if let progress = busViewModel.nearestStop(for: bus) {
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
                HStack {
                    Label(bus.speedText, systemImage: "speedometer")
                    Spacer()
                    Label(bus.crowd.label, systemImage: "person.3.fill")
                        .foregroundColor(bus.crowd.color)
                        .symbolEffect(.bounce, value: bus.crowd)
                    Spacer()
                    Label(bus.lastUpdateText, systemImage: bus.isStale ? "wifi.exclamationmark" : "dot.radiowaves.left.and.right")
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
                if authViewModel.profile?.favoriteStop != nil && liveActivity.isAvailable {
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

                // Actions
                HStack {
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

                    Spacer()

                    Toggle(isOn: $followBus) {
                        Image(systemName: "location.north.line.fill")
                    }
                    .toggleStyle(.button)

                    Button("Details", action: onDetails)
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal)
            .padding(.bottom, 8)
            // A small tap on the phone when a crowd report lands.
            .sensoryFeedback(.success, trigger: bus.crowd)
        }
    }
}
