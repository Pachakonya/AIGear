import SwiftUI
import MapboxMaps
import MapboxDirections
import CoreLocation

extension Notification.Name {
    static let centerMapExternally = Notification.Name("centerMapExternally")
    static let drawRouteExternally = Notification.Name("drawRouteExternally")
}

struct MapboxOutdoorMapView: UIViewRepresentable {
    @ObservedObject var viewModel: MapViewModel
    @Binding var is3D: Bool

    class Coordinator: NSObject {
        var mapView: MapView?
        var polylineManager: PolylineAnnotationManager?

        override init() {
            super.init()
            NotificationCenter.default.addObserver(self, selector: #selector(centerMapNotification(_:)), name: .centerMapExternally, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(drawRouteNotification(_:)), name: .drawRouteExternally, object: nil)
        }

        @objc private func centerMapNotification(_ notification: Notification) {
            guard let coordinate = notification.object as? CLLocationCoordinate2D else { return }
            centerMap(on: coordinate)
        }

        @objc private func drawRouteNotification(_ notification: Notification) {
            guard let route = notification.object as? Route,
                  let mapView = mapView else { return }
            drawRoute(route: route, on: mapView)
        }

        @objc func mapTapped(_ sender: UITapGestureRecognizer) {
            guard let mapView = mapView else { return }

            let tapPoint = sender.location(in: mapView)
            let destination = mapView.mapboxMap.coordinate(for: tapPoint)

            guard let origin = mapView.location.latestLocation?.coordinate else {
                print("⚠️ No user location")
                return
            }

            RouteService().fetchRoute(from: origin, to: destination) { route, conditions in
                guard let route = route else { return }
                
                if !conditions.isEmpty {
                    for (i, c) in conditions.enumerated() {
                        print("""
                        ✅ Condition \(i + 1):
                          surface=\(c.surface ?? "nil"),
                          sac=\(c.sacScale ?? "nil"),
                          visibility=\(c.trailVisibility ?? "nil"),
                          incline=\(c.incline ?? "nil"),
                          smoothness=\(c.smoothness ?? "nil"),
                          bridge=\(c.bridge ?? "nil"),
                          tunnel=\(c.tunnel ?? "nil"),
                          ford=\(c.ford ?? "nil")
                        """)
                    }
                } else {
                    print("❌ No trail conditions found.")
                }

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

            // Optional: Animate camera first to the route path smoothly
            let camera = mapView.mapboxMap.camera(
                for: coordinates,
                padding: .init(top: 150, left: 80, bottom: 150, right: 80),
                bearing: 0,
                pitch: 0
            )

            // Smooth camera transition
            mapView.camera.ease(
                to: camera,
                duration: 1.3,  // Slower animation for smoother feel
                curve: .easeInOut
            )

            // Delay drawing until camera settles (optional)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                var polyline = PolylineAnnotation(lineCoordinates: coordinates)
                polyline.lineWidth = 4
                polyline.lineColor = StyleColor(UIColor.systemBlue)
                self.polylineManager?.annotations = [polyline]
            }
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
        let mapInitOptions = MapInitOptions(resourceOptions: resourceOptions, styleURI: .satellite)

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
        let desiredStyle: StyleURI = is3D ? .satelliteStreets : .outdoors
        let currentStyle = uiView.mapboxMap.style.uri

            // Switch style if needed
        if currentStyle != desiredStyle {
            uiView.mapboxMap.loadStyleURI(desiredStyle)

            uiView.mapboxMap.onNext(event: .styleLoaded) { _ in

                let sourceDict: [String: Any] = [
                    "type": "raster-dem",
                    "url": "mapbox://mapbox.terrain-rgb",
                    "tileSize": 512
                ]
                try? uiView.mapboxMap.style.addSource(withId: "mapbox-dem", properties: sourceDict)

                let terrain = Terrain(sourceId: "mapbox-dem")
                try? uiView.mapboxMap.style.setTerrain(terrain)

                // Optional: Sky layer
//              var skyLayer = SkyLayer(id: "sky-layer")
//              skyLayer.paint?.skyType = .atmosphere
//              try? uiView.mapboxMap.style.addLayer(skyLayer)
            }
        }

            // Set camera pitch
        let pitch: CGFloat = is3D ? 65.0 : 0.0
        let currentCamera = uiView.mapboxMap.cameraState
        let updatedCamera = CameraOptions(
            center: currentCamera.center,
            zoom: currentCamera.zoom,
            bearing: currentCamera.bearing,
            pitch: pitch
        )
        uiView.mapboxMap.setCamera(to: updatedCamera)
    }
}

