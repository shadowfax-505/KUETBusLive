//
//  LiveActivityManager.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Starts, updates and ends the Live Activity for the bus a rider is following.
//  The Live Activity shows the ETA on the Lock Screen and in the Dynamic Island,
//  so the rider doesn't have to keep the app open while waiting at the stop.
//
//  Only one bus can be followed at a time.
//

import Foundation
import ActivityKit

class LiveActivityManager: ObservableObject {
    static let shared = LiveActivityManager()

    // The bus being followed, so the trip card can show "Stop following".
    @Published var followedBusId: String?

    private var activity: Activity<BusTripAttributes>?
    private var lastState: BusTripAttributes.ContentState?

    // Within this distance (in km) the bus counts as "at your stop".
    static let arrivalDistanceKm = 0.15

    private init() {}

    // The rider can turn Live Activities off in Settings, so check first.
    var isAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func isFollowing(_ bus: Bus) -> Bool {
        bus.id != nil && bus.id == followedBusId
    }

    func start(bus: Bus, stopName: String, etaMinutes: Int?, distanceKm: Double?, progress: TripProgress) {
        guard isAvailable, let busId = bus.id else { return }
        stop()   // only one followed bus at a time

        let attributes = BusTripAttributes(busNumber: bus.number, stopName: stopName)
        let state = BusTripAttributes.ContentState(etaMinutes: etaMinutes ?? 0,
                                                   distanceKm: distanceKm ?? 0,
                                                   crowd: bus.crowd.rawValue,
                                                   isStale: bus.isStale,
                                                   progress: progress)
        do {
            // pushType nil: the app updates the activity itself while it is running.
            activity = try Activity.request(attributes: attributes,
                                            content: ActivityContent(state: state, staleDate: nil),
                                            pushType: nil)
            lastState = state
            followedBusId = busId
        } catch {
            print("Could not start Live Activity: \(error)")
        }
    }

    // A new ETA arrived for this bus. Called by BusViewModel.
    func update(bus: Bus, etaMinutes: Int, distanceKm: Double, progress: TripProgress) {
        guard isFollowing(bus), activity != nil else { return }
        var state = BusTripAttributes.ContentState(etaMinutes: etaMinutes,
                                                   distanceKm: distanceKm,
                                                   crowd: bus.crowd.rawValue,
                                                   isStale: bus.isStale,
                                                   progress: progress)
        if distanceKm <= Self.arrivalDistanceKm {
            state.progress.fraction = 1
            // The bus reached the stop: show "Here" for a short while, then remove it.
            state.hasArrived = true
            end(with: state, after: 120)
            return
        }
        send(state)
    }

    // The bus moved or got a crowd report, but no new ETA yet.
    func refresh(bus: Bus) {
        guard isFollowing(bus), var state = lastState else { return }
        state.crowd = bus.crowd.rawValue
        state.isStale = bus.isStale
        guard state != lastState else { return }
        send(state)
    }

    // The rider tapped "Stop following", or the driver ended the trip.
    func stop() {
        guard let state = lastState else {
            followedBusId = nil
            return
        }
        end(with: state, after: 0)
    }

    private func send(_ state: BusTripAttributes.ContentState) {
        lastState = state
        let current = activity
        Task {
            await current?.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    private func end(with state: BusTripAttributes.ContentState, after seconds: TimeInterval) {
        let current = activity
        activity = nil
        lastState = nil
        followedBusId = nil
        let policy: ActivityUIDismissalPolicy = seconds > 0
            ? .after(Date().addingTimeInterval(seconds))
            : .immediate
        Task {
            await current?.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: policy)
        }
    }
}
