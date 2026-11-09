//
//  BusTripAttributes.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  The data behind the Live Activity (Lock Screen card and Dynamic Island).
//  Compiled into both the app, which starts and updates it, and the widget
//  extension, which draws it.
//
//  - The attributes never change during the activity: which bus and which stop.
//  - ContentState is what the app sends on every update: ETA, distance, crowd.
//

import Foundation
import ActivityKit

struct BusTripAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var etaMinutes: Int        // minutes until the bus reaches the stop
        var distanceKm: Double     // road distance from the bus to the stop
        var crowd: String          // "unknown", "seats" or "full", same as CrowdLevel
        var isStale: Bool          // no GPS from the bus for over a minute
        var hasArrived: Bool = false
        var progress: TripProgress = .empty   // for the track on the Lock Screen

        var etaText: String {
            hasArrived ? "Here" : "\(etaMinutes) min"
        }

        var distanceText: String {
            String(format: "%.1f km", distanceKm)
        }

        var crowdText: String {
            switch crowd {
            case "seats": return "Seats available"
            case "full": return "Full"
            default: return "No crowd report"
            }
        }
    }

    var busNumber: String    // "Normal-2 · Rupsha"
    var stopName: String     // "Fulbarigate"
}
