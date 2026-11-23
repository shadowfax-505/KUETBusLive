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
    // The public OSRM demo server is fine for a campus pilot but has fair-use limits.
    // For a wide release, run your own OSRM (or another OSRM-compatible server) and put
    // its address in Info.plist under OSRMBaseURL, for example
    // "https://osrm.example.org/route/v1/driving/". No code change is needed.
    static let defaultBaseURL = "https://router.project-osrm.org/route/v1/driving/"
    static var baseURL: String {
        guard let custom = Bundle.main.object(forInfoDictionaryKey: "OSRMBaseURL") as? String,
              custom.hasPrefix("https://") else { return defaultBaseURL }
        return custom.hasSuffix("/") ? custom : custom + "/"
    }

    // A slow network must not hold an ETA forever: give up and let the caller estimate.
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        config.waitsForConnectivity = false
        config.httpAdditionalHeaders = ["User-Agent": "KUETBusLive-iOS"]
        return URLSession(configuration: config)
    }()

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

        Self.session.dataTask(with: url) { data, response, error in
            // Busy or refusing (429, 5xx): no route, so the caller falls back to an estimate.
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard let data = data, error == nil, status == 200 else {
                if status != 0 && status != 200 {
                    Log.network.notice("Routing server answered \(status)")
                }
                DispatchQueue.main.async { completion(nil) }
                return
            }
            do {
                let decoded = try JSONDecoder().decode(RouteResponse.self, from: data)
                DispatchQueue.main.async { completion(decoded.routes.first) }
            } catch {
                Log.network.error("Could not read the route: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(nil) }
            }
        }.resume()
    }
}
