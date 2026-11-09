//
//  ETAService.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  REST API + JSON parsing: asks the free OSRM routing server how long the
//  drive is from the bus to a stop. No API key is needed.
//

import Foundation
import CoreLocation

class ETAService {
    static let baseURL = "https://router.project-osrm.org/route/v1/driving/"

    func fetchETA(from start: CLLocationCoordinate2D,
                  to end: CLLocationCoordinate2D,
                  completion: @escaping (RouteInfo?) -> Void) {
        // OSRM wants longitude first, then latitude.
        let path = "\(start.longitude),\(start.latitude);\(end.longitude),\(end.latitude)"
        guard let url = URL(string: Self.baseURL + path + "?overview=false") else {
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
