// MapView.swift
// Displays a map with annotation pins for each journal entry location.
// Expects an Entry model defined in Entry.swift

import SwiftUI
import MapKit

struct IdentifiablePointAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let title: String
}

struct MapView: View {
    let journalEntries: [Entry]
    @State private var region: MKCoordinateRegion? = nil
    @State private var annotations: [IdentifiablePointAnnotation] = []
    
    var body: some View {
        Group {
            if let region = region, !annotations.isEmpty {
                Map(coordinateRegion: .constant(region), annotationItems: annotations) { annotation in
                    MapMarker(coordinate: annotation.coordinate, tint: .blue)
                }
                .navigationTitle("Map")
                .navigationBarTitleDisplayMode(.inline)
            } else {
                if journalEntries.isEmpty {
                    Text("No locations to show")
                        .navigationTitle("Map")
                        .navigationBarTitleDisplayMode(.inline)
                } else {
                    ProgressView("Loading locations...")
                        .navigationTitle("Map")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
        .onAppear(perform: loadAnnotationsFromCachedCoordinates)
    }

    private func loadAnnotationsFromCachedCoordinates() {
        let foundAnnotations: [IdentifiablePointAnnotation] = journalEntries.compactMap { entry in
            if let lat = entry.latitude, let lon = entry.longitude {
                let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                return IdentifiablePointAnnotation(coordinate: coordinate, title: entry.title)
            }
            return nil
        }

        self.annotations = foundAnnotations

        if foundAnnotations.isEmpty {
            self.region = nil
        } else if foundAnnotations.count == 1 {
            self.region = MKCoordinateRegion(center: foundAnnotations[0].coordinate,
                                             span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))
        } else {
            self.region = regionToFitAllAnnotations(foundAnnotations)
        }
    }

    private func regionToFitAllAnnotations(_ annotations: [IdentifiablePointAnnotation]) -> MKCoordinateRegion {
        guard !annotations.isEmpty else { return MKCoordinateRegion() }
        if annotations.count == 1 {
            return MKCoordinateRegion(center: annotations[0].coordinate, span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))
        }
        let lats = annotations.map { $0.coordinate.latitude }
        let lons = annotations.map { $0.coordinate.longitude }
        let minLat = lats.min()!, maxLat = lats.max()!
        let minLon = lons.min()!, maxLon = lons.max()!
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(latitudeDelta: (maxLat - minLat) * 1.5 + 0.05, longitudeDelta: (maxLon - minLon) * 1.5 + 0.05)
        return MKCoordinateRegion(center: center, span: span)
    }
}
