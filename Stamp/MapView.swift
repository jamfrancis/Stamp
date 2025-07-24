// MapView.swift
// Displays a map with annotation pins for each stamp location.
// Updated to work with JournalEntry Core Data model

import SwiftUI
import MapKit

struct IdentifiablePointAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let title: String
}

struct JournalMapView: View {
    let journalEntries: [JournalEntry]
    @State private var region: MKCoordinateRegion? = nil
    @State private var annotations: [IdentifiablePointAnnotation] = []
    
    var body: some View {
        ZStack {
            if let region = region, !annotations.isEmpty {
                Map(coordinateRegion: .constant(region), annotationItems: annotations) { annotation in
                    MapMarker(coordinate: annotation.coordinate, tint: .blue)
                }
                .ignoresSafeArea(.all)
            } else {
                if journalEntries.isEmpty {
                    VStack {
                        Spacer()
                        Text("No stamp locations to show")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                    .ignoresSafeArea(.all)
                } else {
                    VStack {
                        Spacer()
                        ProgressView("Loading stamp locations...")
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                    .ignoresSafeArea(.all)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear(perform: loadAnnotationsFromCachedCoordinates)
    }

    private func loadAnnotationsFromCachedCoordinates() {
        let foundAnnotations: [IdentifiablePointAnnotation] = journalEntries.compactMap { entry in
            if entry.latitude != 0 && entry.longitude != 0 {
                let coordinate = CLLocationCoordinate2D(latitude: entry.latitude, longitude: entry.longitude)
                return IdentifiablePointAnnotation(coordinate: coordinate, title: entry.title ?? "Untitled")
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
