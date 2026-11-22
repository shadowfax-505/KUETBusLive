//
//  RouteMapRenderer.swift
//  KUETBusWidget
//
//  Created by Muttakin Rahman Shoscho.
//
//  Widgets can't show a live, moving MapKit map. Instead MKMapSnapshotter takes
//  a still picture of the map, and the route is drawn on top of that picture:
//  a solid line through the stops (black, or white on the dark map), a small dot
//  for each stop, a ring at my stop, and the bus where it was last seen. The map is
//  slightly softened, with no points of interest, so the route stands out. One light and
//  one dark picture are made, so the widget matches the phone's appearance.
//

import MapKit
import UIKit
import CoreImage

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
        let configuration = MKStandardMapConfiguration(emphasisStyle: .default)
        configuration.pointOfInterestFilter = .excludingAll
        options.preferredConfiguration = configuration

        MKMapSnapshotter(options: options).start { snapshot, error in
            guard let snapshot = snapshot else {
                print("Map snapshot failed: \(error?.localizedDescription ?? "unknown")")
                completion(nil)
                return
            }
            completion(draw(on: snapshot, stops: stops, live: live, dark: style == .dark))
        }
    }

    // A map area that fits every stop. The widget fades the bottom of the map
    // into its background and puts its header over the top, so the route is kept
    // between about 18% and 50% of the way down, clear of both.
    private static func region(fitting points: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        let lats = points.map { $0.latitude }
        let lngs = points.map { $0.longitude }
        let routeLat = max(lats.max()! - lats.min()!, 0.004)
        let height = routeLat / 0.32
        let top = lats.max()! + height * 0.18
        let center = CLLocationCoordinate2D(latitude: top - height / 2,
                                            longitude: (lngs.min()! + lngs.max()!) / 2)
        let span = MKCoordinateSpan(latitudeDelta: height,
                                    longitudeDelta: max((lngs.max()! - lngs.min()!) * 1.3, 0.01))
        return MKCoordinateRegion(center: center, span: span)
    }

    private static func draw(on snapshot: MKMapSnapshotter.Snapshot, stops: [SharedStop],
                             live: LiveTripSnapshot?, dark: Bool) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: snapshot.image.size)
        // The line colour, and the colour drawn inside it (map white or dark grey).
        let line = dark ? UIColor.white : WidgetTheme.nearBlack
        let fill = dark ? WidgetTheme.darkSurface : UIColor.white
        return renderer.image { context in
            // Some of the map's colour is taken out, so the route still stands out.
            muted(snapshot.image, saturation: dark ? 0.6 : 0.8).draw(at: .zero)
            let points = stops.map { snapshot.point(for: $0.coordinate) }

            // The route: one solid line.
            let path = UIBezierPath()
            for (index, point) in points.enumerated() {
                index == 0 ? path.move(to: point) : path.addLine(to: point)
            }
            path.lineWidth = 4
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            line.setStroke()
            path.stroke()

            // Stop dots; the first stop is a square and the last one, my stop, a ring.
            for (index, point) in points.enumerated() {
                let isMine = index == points.count - 1
                let radius: CGFloat = isMine ? 6 : 3
                let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
                let dot = index == 0 ? UIBezierPath(rect: rect.insetBy(dx: -1, dy: -1)) : UIBezierPath(ovalIn: rect)
                fill.setFill()
                dot.fill()
                line.setStroke()
                dot.lineWidth = isMine ? 3 : 1.5
                dot.stroke()
            }

            // The bus, if one is running: a white circle with a soft shadow and the bus in black.
            if let live = live {
                let point = snapshot.point(for: CLLocationCoordinate2D(latitude: live.busLat, longitude: live.busLng))
                let circle = UIBezierPath(ovalIn: CGRect(x: point.x - 10, y: point.y - 10, width: 20, height: 20))
                context.cgContext.saveGState()
                context.cgContext.setShadow(offset: CGSize(width: 0, height: 1), blur: 4,
                                            color: UIColor.black.withAlphaComponent(0.35).cgColor)
                UIColor.white.setFill()
                circle.fill()
                context.cgContext.restoreGState()
                if let bus = UIImage(systemName: "bus.fill")?
                    .withTintColor(WidgetTheme.nearBlack, renderingMode: .alwaysOriginal) {
                    bus.draw(in: CGRect(x: point.x - 5.5, y: point.y - 5.5, width: 11, height: 11))
                }
            }
        }
    }

    private static let ciContext = CIContext()

    private static func muted(_ image: UIImage, saturation: Double) -> UIImage {
        guard let input = CIImage(image: image),
              let filter = CIFilter(name: "CIColorControls") else { return image }
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(saturation, forKey: kCIInputSaturationKey)
        guard let output = filter.outputImage,
              let cgImage = ciContext.createCGImage(output, from: input.extent) else { return image }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}
