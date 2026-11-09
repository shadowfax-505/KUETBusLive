//
//  RouteMapRenderer.swift
//  KUETBusWidget
//
//  Created by Muttakin Rahman Shoscho.
//
//  Widgets can't show a live, moving MapKit map. Instead MKMapSnapshotter takes
//  a still picture of the map, and the route is drawn on top of that picture:
//  the line through the stops, a dot for each stop, my stop in orange, and the
//  bus where it was last seen. One light and one dark picture are made, so the
//  widget matches the phone's appearance.
//

import MapKit
import UIKit

enum RouteMapRenderer {

    static func render(route: SharedRoute, live: LiveTripSnapshot?, size: CGSize,
                       completion: @escaping (UIImage?, UIImage?) -> Void) {
        // Only the part of the route from KUET to my stop.
        let lastIndex = min(max(route.riderStopIndex, 1), route.stops.count - 1)
        guard lastIndex >= 1 else {
            completion(nil, nil)
            return
        }
        let stops = Array(route.stops[0...lastIndex])

        snapshot(stops: stops, live: live, size: size, style: .light) { light in
            snapshot(stops: stops, live: live, size: size, style: .dark) { dark in
                completion(light, dark)
            }
        }
    }

    private static func snapshot(stops: [SharedStop], live: LiveTripSnapshot?, size: CGSize,
                                 style: UIUserInterfaceStyle, completion: @escaping (UIImage?) -> Void) {
        let options = MKMapSnapshotter.Options()
        options.region = region(fitting: stops.map { $0.coordinate })
        options.size = size
        options.scale = 2   // sharp on the screen, but small enough for the widget's memory limit
        options.traitCollection = UITraitCollection(userInterfaceStyle: style)
        options.pointOfInterestFilter = .excludingAll

        MKMapSnapshotter(options: options).start { snapshot, error in
            guard let snapshot = snapshot else {
                print("Map snapshot failed: \(error?.localizedDescription ?? "unknown")")
                completion(nil)
                return
            }
            completion(draw(on: snapshot, stops: stops, live: live))
        }
    }

    // A map area that fits every stop with a little space around it.
    private static func region(fitting points: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        let lats = points.map { $0.latitude }
        let lngs = points.map { $0.longitude }
        let center = CLLocationCoordinate2D(latitude: (lats.min()! + lats.max()!) / 2,
                                            longitude: (lngs.min()! + lngs.max()!) / 2)
        let span = MKCoordinateSpan(latitudeDelta: max((lats.max()! - lats.min()!) * 1.4, 0.01),
                                    longitudeDelta: max((lngs.max()! - lngs.min()!) * 1.4, 0.01))
        return MKCoordinateRegion(center: center, span: span)
    }

    private static func draw(on snapshot: MKMapSnapshotter.Snapshot, stops: [SharedStop],
                             live: LiveTripSnapshot?) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: snapshot.image.size)
        let blue = UIColor(red: 0.12, green: 0.40, blue: 0.75, alpha: 1)
        return renderer.image { context in
            snapshot.image.draw(at: .zero)
            let points = stops.map { snapshot.point(for: $0.coordinate) }

            // The route line
            let line = UIBezierPath()
            for (index, point) in points.enumerated() {
                index == 0 ? line.move(to: point) : line.addLine(to: point)
            }
            line.lineWidth = 4
            line.lineCapStyle = .round
            line.lineJoinStyle = .round
            blue.setStroke()
            line.stroke()

            // Stop dots; the last one is my stop, bigger and orange.
            for (index, point) in points.enumerated() {
                let isMine = index == points.count - 1
                let radius: CGFloat = isMine ? 7 : 4
                let dot = UIBezierPath(ovalIn: CGRect(x: point.x - radius, y: point.y - radius,
                                                      width: radius * 2, height: radius * 2))
                (isMine ? UIColor.systemOrange : UIColor.white).setFill()
                dot.fill()
                blue.setStroke()
                dot.lineWidth = 2
                dot.stroke()
            }

            // The bus, if one is running
            if let live = live {
                let point = snapshot.point(for: CLLocationCoordinate2D(latitude: live.busLat, longitude: live.busLng))
                let circle = UIBezierPath(ovalIn: CGRect(x: point.x - 11, y: point.y - 11, width: 22, height: 22))
                blue.setFill()
                circle.fill()
                UIColor.white.setStroke()
                circle.lineWidth = 2
                circle.stroke()
                if let bus = UIImage(systemName: "bus.fill")?
                    .withTintColor(.white, renderingMode: .alwaysOriginal) {
                    bus.draw(in: CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12))
                }
            }
        }
    }
}
