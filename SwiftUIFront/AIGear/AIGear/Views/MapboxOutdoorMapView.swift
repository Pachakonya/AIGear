import SwiftUI
import MapboxMaps
import MapboxDirections
import CoreLocation

extension Notification.Name {
    static let centerMapExternally = Notification.Name("centerMapExternally")
}

struct MapboxOutdoorMapView: UIViewRepresentable {
    @ObservedObject var viewModel: MapViewModel

    class Coordinator: NSObject {
        var mapView: MapView?
        var polylineManager: PolylineAnnotationManager?

        override init() {
            super.init()
            NotificationCenter.default.addObserver(self, selector: #selector(centerMapNotification(_:)), name: .centerMapExternally, object: nil)
        }

        @objc private func centerMapNotification(_ notification: Notification) {
            guard let coordinate = notification.object as? CLLocationCoordinate2D else { return }
            centerMap(on: coordinate)
        }

        @objc func mapTapped(_ sender: UITapGestureRecognizer) {
            guard let mapView = mapView else { return }

            let tapPoint = sender.location(in: mapView)
            let destination = mapView.mapboxMap.coordinate(for: tapPoint)

            guard let origin = mapView.location.latestLocation?.coordinate else {
                print("⚠️ No user location")
                return
            }

            RouteService().fetchRoute(from: origin, to: destination) { route in
                guard let route = route else { return }

                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.drawRoute(route: route, on: mapView)
                }
            }
        }

        func drawRoute(route: Route, on mapView: MapView) {
            guard let shape = route.shape else { return }
            let coordinates = shape.coordinates

            polylineManager?.annotations.removeAll()
            var polyline = PolylineAnnotation(lineCoordinates: coordinates)
            polyline.lineWidth = 4
            polyline.lineColor = StyleColor(UIColor.systemBlue)
            polylineManager?.annotations = [polyline]

            let camera = mapView.mapboxMap.camera(
                for: coordinates,
                padding: .init(top: 60, left: 40, bottom: 60, right: 40),
                bearing: 0,
                pitch: 0
            )
            mapView.mapboxMap.setCamera(to: camera)
        }

        func centerMap(on coordinate: CLLocationCoordinate2D) {
            mapView?.camera.ease(to: CameraOptions(center: coordinate, zoom: 13), duration: 1.5)
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }

    func makeUIView(context: Context) -> MapView {
        let resourceOptions = ResourceOptions(accessToken: Bundle.main.object(forInfoDictionaryKey: "MBXAccessToken") as! String)
        let mapInitOptions = MapInitOptions(resourceOptions: resourceOptions, styleURI: .outdoors)

        let mapView = MapView(frame: .zero, mapInitOptions: mapInitOptions)
        context.coordinator.mapView = mapView
        context.coordinator.polylineManager = mapView.annotations.makePolylineAnnotationManager()

        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.mapTapped(_:)))
        mapView.addGestureRecognizer(tapGesture)

        mapView.location.options.puckType = .puck2D()
        mapView.location.options.puckBearingEnabled = true
        mapView.location.options.activityType = .fitness

        return mapView
    }

    func updateUIView(_ uiView: MapView, context: Context) {
        // No automatic centering to allow manual control via button
    }
}

