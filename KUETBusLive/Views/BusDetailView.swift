//
//  BusDetailView.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//

import SwiftUI

struct BusDetailView: View {
    let busId: String
    @ObservedObject var busViewModel: BusViewModel
    @EnvironmentObject var authViewModel: AuthViewModel

    // Looked up each time, so the screen follows live updates.
    var bus: Bus? {
        busViewModel.bus(withId: busId)
    }

    // Teachers can ride any bus, students only student buses.
    func canBoard(_ bus: Bus) -> Bool {
        bus.allocation.canBoard(authViewModel.profile?.role ?? .student)
    }

    var body: some View {
        Group {
            if let bus = bus {
                List {
                    Section(header: Text("Bus")) {
                        HStack {
                            Text("Allocated to")
                            Spacer()
                            AudienceBadge(audience: bus.allocation)
                        }
                        LabeledContent("Route", value: bus.routeName)
                        LabeledContent("Last update", value: bus.lastUpdateText)
                        LabeledContent("Crowd", value: bus.crowd.label)
                    }

                    Section(header: Text("Arrival")) {
                        if let stop = authViewModel.profile?.favoriteStop {
                            Text("To \(stop.name)")
                                .foregroundColor(.secondary)
                            Text(busViewModel.etaText[busId] ?? "Calculating...")
                                .font(.title2)
                                .fontWeight(.bold)
                        } else {
                            Text("Set your stop in the Routes tab to see the ETA.")
                        }
                    }

                    if canBoard(bus) {
                    Section(header: Text("How crowded is it?")) {
                        HStack {
                            Button("Seats available") {
                                busViewModel.report(.seats, for: bus)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)

                            Spacer()

                            Button("Full") {
                                busViewModel.report(.full, for: bus)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        }
                    }
                    } else {
                        Section {
                            Label("Students can't ride a \(bus.allocation.title.lowercased()).",
                                  systemImage: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                        }
                    }
                }
                .onAppear {
                    busViewModel.refreshETA(for: bus, force: true)
                }
            } else {
                Text("This bus has ended its trip.")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle(bus?.number ?? "Bus")
    }
}
