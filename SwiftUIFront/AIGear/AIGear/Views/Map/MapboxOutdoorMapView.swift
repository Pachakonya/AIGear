import SwiftUI
import Combine
import MapboxMaps
import MapboxDirections
import CoreLocation

extension Notification.Name {
    static let centerMapExternally = Notification.Name("centerMapExternally")
    static let drawRouteExternally = Notification.Name("drawRouteExternally")
    static let confirmRouteBuilding = Notification.Name("confirmRouteBuilding")
    static let cancelRouteSelection = Notification.Name("cancelRouteSelection")
}

struct MapboxOutdoorMapView: UIViewRepresentable {
    @ObservedObject var viewModel: MapViewModel
    @Binding var is3D: Bool

    class Coordinator: NSObject {
        var mapView: MapView?
        var polylineManager: PolylineAnnotationManager?
        var circleManager: CircleAnnotationManager?

        let viewModel: MapViewModel
        var hasCenteredOnUser = false


        init(viewModel: MapViewModel) {
            self.viewModel = viewModel
            super.init()
            NotificationCenter.default.addObserver(self, selector: #selector(centerMapNotification(_:)), name: .centerMapExternally, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(drawRouteNotification(_:)), name: .drawRouteExternally, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(confirmRouteBuilding(_:)), name: .confirmRouteBuilding, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(cancelRouteSelection(_:)), name: .cancelRouteSelection, object: nil)
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

        @objc private func confirmRouteBuilding(_ notification: Notification) {
            guard let coordinate = viewModel.selectedLocation,
                  let mapView = mapView else { return }
            
            buildRoute(to: coordinate, on: mapView)
        }
        
        @objc private func cancelRouteSelection(_ notification: Notification) {
            // Clear the pin annotation
            circleManager?.annotations.removeAll()
        }

        @objc func mapTapped(_ sender: UITapGestureRecognizer) {
            // Check if keyboard is open
            if KeyboardObserver.shared.isKeyboardVisible {
                UIApplication.shared.endEditing()
                return // Do not show confirmation on this tap
            }

            guard let mapView = mapView else { return }

            let tapPoint = sender.location(in: mapView)
            let tappedCoordinate = mapView.mapboxMap.coordinate(for: tapPoint)

            // Show pin at tapped location
            showPinAtLocation(tappedCoordinate)
            
            // Show route confirmation dialog
            DispatchQueue.main.async {
                self.viewModel.showRouteConfirmationDialog(for: tappedCoordinate)
            }
        }
        
        private func showPinAtLocation(_ coordinate: CLLocationCoordinate2D) {
            // Clear existing pins
            circleManager?.annotations.removeAll()
            
            // Create a new pin using a circle annotation
            var circleAnnotation = CircleAnnotation(centerCoordinate: coordinate)
            circleAnnotation.circleRadius = 5
            circleAnnotation.circleColor = StyleColor(UIColor.systemBlue)
            circleAnnotation.circleOpacity = 1.0
            circleAnnotation.circleStrokeColor = StyleColor(UIColor.white)
            circleAnnotation.circleStrokeWidth = 2
            circleAnnotation.circleStrokeOpacity = 1.0
            
            circleManager?.annotations = [circleAnnotation]
            
        }
        
        private func buildRoute(to destination: CLLocationCoordinate2D, on mapView: MapView) {
            guard let origin = mapView.location.latestLocation?.coordinate else {
                print("⚠️ No user location")
                return
            }

            // Set loading state
            DispatchQueue.main.async {
                self.viewModel.isLoadingTrail = true
            }

            RouteService().fetchRoute(from: origin, to: destination) { route, conditions in
                guard let route = route else { 
                    // Reset loading state if route fetch fails
                    DispatchQueue.main.async {
                        self.viewModel.isLoadingTrail = false
                    }
                    return 
                }

                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.viewModel.updateDifficulty(from: conditions)
                    self.drawRoute(route: route, on: mapView)
                    
                    // Clear the pin after route is drawn
                    self.circleManager?.annotations.removeAll()
                    
                    // Reset loading state after route is drawn
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.viewModel.isLoadingTrail = false
                    }
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
                polyline.lineWidth = 3
                polyline.lineColor = StyleColor(UIColor.systemBlue)
                self.polylineManager?.annotations = [polyline]
            }
        }
        
        func centerMap(on coordinate: CLLocationCoordinate2D) {
            mapView?.camera.ease(to: CameraOptions(center: coordinate, zoom: 13), duration: 1.5)
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(viewModel: viewModel)
    }

    func makeUIView(context: Context) -> MapView {
        let resourceOptions = ResourceOptions(accessToken: Bundle.main.object(forInfoDictionaryKey: "MBXAccessToken") as! String)
        let mapInitOptions = MapInitOptions(resourceOptions: resourceOptions, styleURI: .satellite)

        let mapView = MapView(frame: .zero, mapInitOptions: mapInitOptions)
        context.coordinator.mapView = mapView
        context.coordinator.polylineManager = mapView.annotations.makePolylineAnnotationManager()
        context.coordinator.circleManager = mapView.annotations.makeCircleAnnotationManager()

        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.mapTapped(_:)))
        mapView.addGestureRecognizer(tapGesture)

        mapView.location.options.puckType = .puck2D()
        mapView.location.options.puckBearingEnabled = true
        mapView.location.options.activityType = .fitness
        
        mapView.ornaments.options.compass.visibility = .hidden
        mapView.ornaments.options.scaleBar.visibility = .hidden
       
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
            }
        }

        // Center on user location only once
        if let userLocation = viewModel.userLocation?.coordinate,
           !context.coordinator.hasCenteredOnUser {
            let camera = CameraOptions(center: userLocation, zoom: 13)
            uiView.mapboxMap.setCamera(to: camera)
            context.coordinator.hasCenteredOnUser = true
        }
    }
}

