//
//  ArcGISPinApp.swift
//  Stamp
//
//  Created by James on 7/24/25.
//


import SwiftUI
import ArcGIS
import ArcGISToolkit

@main
struct ArcGISPinApp: App {
    var body: some Scene {
        WindowGroup {
            MapViewScreen()
        }
    }
}

struct MapViewScreen: View {
    let map = Map(basemapStyle: .arcGISTopographic)

    // Create a graphics overlay to hold pins
    let graphicsOverlay = GraphicsOverlay()

    // Pin coordinates
    let pinLocations = [
        ("BYU-Idaho", Point(x: -111.783, y: 43.822, spatialReference: .wgs84)),
        ("Apple HQ", Point(x: -122.0308, y: 37.3318, spatialReference: .wgs84))
    ]

    @State private var selectedPinTitle: String?
    @State private var selectedPoint: Point?

    var body: some View {
        MapViewReader { mapViewProxy in
            MapView(map: map)
                .graphicsOverlays([graphicsOverlay])
                .onSingleTapGesture { screenPoint, mapPoint in
                    handleTap(on: screenPoint, mapPoint: mapPoint, mapViewProxy: mapViewProxy)
                }
                .onAppear {
                    addPins()
                    mapViewProxy.setViewpointCenter(pinLocations.first!.1, scale: 1e5)
                }
                .callout(
                    isPresented: Binding<Bool>(
                        get: { selectedPoint != nil },
                        set: { if !$0 { selectedPoint = nil } }
                    ),
                    location: selectedPoint ?? Point(x: 0, y: 0, spatialReference: .wgs84)
                ) {
                    VStack {
                        Text(selectedPinTitle ?? "Unknown Location")
                            .font(.headline)
                        Button("Dismiss") {
                            selectedPoint = nil
                        }
                    }
                    .padding()
                }
        }
    }

    func addPins() {
        pinLocations.forEach { name, point in
            let symbol = SimpleMarkerSymbol(style: .circle, color: .red, size: 12)
            let graphic = Graphic(geometry: point, symbol: symbol, attributes: ["title": name])
            graphicsOverlay.graphics.add(graphic)
        }
    }

    func handleTap(on screenPoint: CGPoint, mapPoint: Point, mapViewProxy: MapViewProxy) {
        Task {
            let identifyResult = try? await mapViewProxy.identify(graphicsOverlay: graphicsOverlay, screenPoint: screenPoint, tolerance: 12, returnPopupsOnly: false, maximumResults: 1)

            if let graphic = identifyResult?.graphics.first,
               let title = graphic.attributes["title"] as? String,
               let tappedPoint = graphic.geometry as? Point {
                selectedPinTitle = title
                selectedPoint = tappedPoint
            } else {
                selectedPoint = nil
            }
        }
    }
}