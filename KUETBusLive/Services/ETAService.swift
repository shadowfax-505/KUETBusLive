//
//  ETAService.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Talks to the public OSRM routing API. It answers two questions:
//  - how long the bus needs to reach my stop (and the road it will take)
//  - the full road path of a route through all its stops, to draw on the map
//

import Foundation
import CoreLocation

class ETAService {
    static let baseURL = "https://router.project-osrm.org/route/v1/driving/"

    // Bus -> my stop: travel time, distance and the road path.
    func fetchETA(from start: CLLocationCoordinate2D,
                  to end: CLLocationCoordinate2D,
                  completion: @escaping (RouteInfo?) -> Void) {
        fetchRoute(through: [start, end], completion: completion)
    }

    // A whole bus route: the road path through every stop, in order.
    func fetchPath(through stops: [CLLocationCoordinate2D],
                   completion: @escaping ([CLLocationCoordinate2D]) -> Void) {
        fetchRoute(through: stops) { info in
            completion(info?.path ?? [])
        }
    }

    private func fetchRoute(through points: [CLLocationCoordinate2D],
                            completion: @escaping (RouteInfo?) -> Void) {
        guard points.count >= 2 else {
            completion(nil)
            return
        }
        // OSRM wants longitude first, then latitude, with points separated by ";".
        let path = points
            .map { "\($0.longitude),\($0.latitude)" }
            .joined(separator: ";")
        let options = "?overview=full&geometries=geojson"
        guard let url = URL(string: Self.baseURL + path + options) else {
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            do {
                let decoded = try JSONDecoder().decode(RouteResponse.self, from: data)
                DispatchQueue.main.async { completion(decoded.routes.first) }
            } catch {
                print("JSON error: \(error)")
                DispatchQueue.main.async { completion(nil) }
            }
        }.resume()
    }
}
