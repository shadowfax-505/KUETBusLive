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
//  While a driver's trip is running, GPS keeps going even when the app is in the
//  background or the screen is locked, so the bus doesn't freeze on riders' maps.
//  iOS shows the blue location pill at the top of the screen the whole time, so the
//  driver can always see that their location is being shared.
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

    // iOS 17 keeps background location alive for as long as this session object exists.
    // Stored as Any? because the type only exists on iOS 17 and later.
    private var backgroundSession: Any?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10   // metres moved before a new update
        // A bus stops at signals and stops; don't let iOS pause GPS when it stands still.
        manager.pausesLocationUpdatesAutomatically = false
        manager.activityType = .automotiveNavigation
    }

    // inBackground: true for a driver's trip, so updates continue with the app closed.
    func start(inBackground: Bool = false) {
        if inBackground {
            // Ask for "Always". If the driver only allows "While Using", tracking still
            // works in the background because it was started while the app was open.
            manager.requestAlwaysAuthorization()
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = true
            if #available(iOS 17.0, *) {
                backgroundSession = CLBackgroundActivitySession()
            }
        } else {
            manager.requestWhenInUseAuthorization()
        }
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
        // Background tracking is only on during a trip.
        manager.allowsBackgroundLocationUpdates = false
        manager.showsBackgroundLocationIndicator = false
        if #available(iOS 17.0, *) {
            (backgroundSession as? CLBackgroundActivitySession)?.invalidate()
        }
        backgroundSession = nil
    }

    // Plain-English description of the current permission, shown on the driver screen.
    var permissionText: String {
        switch manager.authorizationStatus {
        case .authorizedAlways:
            return "Location: Always (keeps sharing when the app is closed)"
        case .authorizedWhenInUse:
            return "Location: While Using (keeps sharing while a trip is running)"
        case .denied, .restricted:
            return "Location: Off"
        default:
            return "Location: not asked yet"
        }
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
