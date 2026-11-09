//
//  LocationManager.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Delegate pattern, two levels:
//  1. CLLocationManager calls this class through CLLocationManagerDelegate.
//  2. This class calls whoever is its delegate through LocationUpdateDelegate.
//

import Foundation
import CoreLocation

protocol LocationUpdateDelegate: AnyObject {
    func didUpdateLocation(_ location: CLLocation)
    func didFailWithLocationError(_ message: String)
}

class LocationManager: NSObject, CLLocationManagerDelegate {
    weak var delegate: LocationUpdateDelegate?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10   // metres moved before a new update
    }

    func start() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        delegate?.didUpdateLocation(latest)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        delegate?.didFailWithLocationError(error.localizedDescription)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .denied, .restricted:
            delegate?.didFailWithLocationError("Location is off. Turn it on in Settings.")
        case .authorizedWhenInUse, .authorizedAlways, .notDetermined:
            break
        @unknown default:
            break
        }
    }
}
