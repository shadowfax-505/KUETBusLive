//
//  RouteMapRenderer.swift
//  KUETBusWidget
//
//  Created by Muttakin Rahman Shoscho.
//
//  Widgets can't show a live, moving MapKit map. Instead MKMapSnapshotter takes
//  a still picture of the map, and the route is drawn on top of that picture:
//  a thin brass line through the stops, a small ivory dot for each stop, my stop
//  as a filled brass dot, and the bus where it was last seen. The map itself is
//  muted, with no points of interest, so the route stands out. One light and
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
        let configuration = MKStandardMapConfiguration(emphasisStyle: .muted)
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
                             live: LiveTripSnapshot?, dark: Bool) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: snapshot.image.size)
        let brass = dark ? WidgetTheme.brass : WidgetTheme.brassDeep
        let ivory = WidgetTheme.ivory
        let ink = WidgetTheme.inkNavy
        return renderer.image { context in
            // Most of the map's colour is taken out, so only the brass route stands out.
            muted(snapshot.image, saturation: dark ? 0.2 : 0.35).draw(at: .zero)
            let points = stops.map { snapshot.point(for: $0.coordinate) }

            // The route line, with a soft glow under it
            let line = UIBezierPath()
            for (index, point) in points.enumerated() {
                index == 0 ? line.move(to: point) : line.addLine(to: point)
            }
            line.lineWidth = 3
            line.lineCapStyle = .round
            line.lineJoinStyle = .round
            context.cgContext.saveGState()
            context.cgContext.setShadow(offset: .zero, blur: 4, color: brass.withAlphaComponent(0.5).cgColor)
            brass.setStroke()
            line.stroke()
            context.cgContext.restoreGState()

            // Stop dots; the last one is my stop, a filled brass dot.
            for (index, point) in points.enumerated() {
                let isMine = index == points.count - 1
                let radius: CGFloat = isMine ? 7 : 3.5
                let dot = UIBezierPath(ovalIn: CGRect(x: point.x - radius, y: point.y - radius,
                                                      width: radius * 2, height: radius * 2))
                (isMine ? brass : ivory).setFill()
                dot.fill()
                (isMine ? ivory : brass).setStroke()
                dot.lineWidth = 1.5
                dot.stroke()
            }

            // The bus, if one is running: a brass circle with the bus in ink
            if let live = live {
                let point = snapshot.point(for: CLLocationCoordinate2D(latitude: live.busLat, longitude: live.busLng))
                let circle = UIBezierPath(ovalIn: CGRect(x: point.x - 10, y: point.y - 10, width: 20, height: 20))
                context.cgContext.saveGState()
                context.cgContext.setShadow(offset: .zero, blur: 4, color: brass.withAlphaComponent(0.5).cgColor)
                brass.setFill()
                circle.fill()
                context.cgContext.restoreGState()
                ivory.setStroke()
                circle.lineWidth = 1.5
                circle.stroke()
                if let bus = UIImage(systemName: "bus.fill")?
                    .withTintColor(ink, renderingMode: .alwaysOriginal) {
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
