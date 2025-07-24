// ArcGISMapImplementation.swift
// Core ArcGIS mapping functionality and gesture handling

import SwiftUI
import ArcGIS

// MARK: - Core ArcGIS Map Implementation
struct ArcGISMapViewImplementation: View {
    let journalEntries: [JournalEntry]
    let viewModel: MapViewModel
    @Binding var showPastMonthOnly: Bool
    var onStampTap: ((JournalEntry) -> Void)? = nil
    
    @State private var map: Map = Map(basemapStyle: .arcGISTopographic)
    @State private var graphicsOverlay = GraphicsOverlay()
    @State private var stampMarkers: [ArcGISStampMarker] = []
    
    private var filteredEntries: [JournalEntry] {
        if showPastMonthOnly {
            let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
            return journalEntries.filter { entry in
                guard let date = entry.date else { return false }
                return date >= oneMonthAgo
            }
        }
        return journalEntries
    }
    
    var body: some View {
        ZStack {
            // Light background to distinguish from MapKit
            Color(.systemGray6)
            
            MapView(map: map, graphicsOverlays: [graphicsOverlay])
                .onSingleTapGesture { screenPoint, mapPoint in
                    handleMapTap(at: mapPoint)
                }
                .task {
                    await setupArcGISMap()
                }
                .task(id: filteredEntries.count) {
                    await updateStampMarkers()
                }
            
            // Show bottom sheet popup when pin is selected
            if let selected = viewModel.selectedEntry {
                ArcGISBottomSheetPopup(entry: selected, onTapForFullView: {
                    onStampTap?(selected)
                }) {
                    viewModel.clearSelection()
                }
                .allowsHitTesting(true)
                .zIndex(1000)
            }
        }
    }
    
    // Sets up the ArcGIS map with authentication and initial view
    @MainActor
    private func setupArcGISMap() async {
        // Configure API key for basemap tiles
        ArcGISEnvironment.apiKey = APIKey("AAPTxy8BH1VEsoebNVZXo8HurLP1FjHUkozMRki8vXlhPBpMnz5Xf4LKL4FpI2k5UBNOi4Xek-hD6gPKIxS3l83LesNVs-CdRPWRmNkT8dp-XixmDzlLIjk7wGvpMC2u9NYo2OeS2rsfQGL9Kd9DHnSGrmiHGE2DCxBR1z7YPeKUApHj4zLQxsPE3V1K1RYanCATET3BumHlwTt-bPvIuX9kGtgDIWsBqSSs5CVzvs4AbPA.AT1_blv5QODE")
        
        // Create map with topographic basemap
        map = Map(basemapStyle: .arcGISTopographic)
        
        // Set viewpoint based on stamp locations
        let initialViewpoint = calculateInitialViewpoint()
        map.initialViewpoint = initialViewpoint
        
        await updateStampMarkers()
    }
    
    // Updates stamp markers when entries change
    @MainActor
    private func updateStampMarkers() async {
        graphicsOverlay.removeAllGraphics()
        stampMarkers.removeAll()
        
        var graphics: [Graphic] = []
        
        for entry in filteredEntries {
            guard entry.latitude != 0 && entry.longitude != 0 else { continue }
            
            let point = Point(x: entry.longitude, y: entry.latitude, spatialReference: .wgs84)
            let symbol = ArcGISSymbolRenderer.createSymbol(for: entry)
            
            let graphic = Graphic(geometry: point, symbol: symbol)
            graphics.append(graphic)
            
            stampMarkers.append(ArcGISStampMarker(
                id: entry.id,
                point: point,
                symbol: symbol,
                journalEntry: entry
            ))
        }
        
        graphicsOverlay.addGraphics(graphics)
    }
    
    // Handles tap on map to select stamp markers
    private func handleMapTap(at mapPoint: Point) {
        var closestEntry: JournalEntry?
        var minDistance: Double = Double.infinity
        let tapTolerance: Double = 0.015
        
        for marker in stampMarkers {
            let deltaX = mapPoint.x - marker.point.x
            let deltaY = mapPoint.y - marker.point.y
            let distance = sqrt(deltaX * deltaX + deltaY * deltaY)
            
            if distance < tapTolerance && distance < minDistance {
                minDistance = distance
                closestEntry = marker.journalEntry
            }
        }
        
        DispatchQueue.main.async {
            if let entry = closestEntry {
                // Toggle selection for better UX
                if self.viewModel.selectedEntry?.id == entry.id {
                    self.viewModel.clearSelection()
                } else {
                    self.viewModel.selectEntry(entry)
                }
            } else {
                // Tapped empty area - clear selection
                self.viewModel.clearSelection()
            }
        }
    }
    
    // Calculates optimal initial viewpoint
    private func calculateInitialViewpoint() -> Viewpoint {
        if !filteredEntries.isEmpty {
            let validEntries = filteredEntries.filter { $0.latitude != 0 && $0.longitude != 0 }
            if !validEntries.isEmpty {
                let avgLat = validEntries.map { $0.latitude }.reduce(0, +) / Double(validEntries.count)
                let avgLon = validEntries.map { $0.longitude }.reduce(0, +) / Double(validEntries.count)
                return Viewpoint(
                    center: Point(x: avgLon, y: avgLat, spatialReference: .wgs84),
                    scale: 2000000
                )
            }
        }
        
        // Default to continental United States view
        return Viewpoint(
            center: Point(x: -98.5795, y: 39.8283, spatialReference: .wgs84),
            scale: 15000000
        )
    }
}