// MapKitAnnotation.swift
// MapKit-specific annotation classes

import MapKit
import Foundation

// MARK: - Custom Stamp Annotation
class StampAnnotation: NSObject, MKAnnotation {
    let entry: JournalEntry
    var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?
    
    init(entry: JournalEntry) {
        self.entry = entry
        self.coordinate = CLLocationCoordinate2D(latitude: entry.latitude, longitude: entry.longitude)
        self.title = entry.title ?? "Untitled Stamp"
        
        // Create subtitle with location and date
        var subtitleParts: [String] = []
        if let location = entry.location, !location.isEmpty {
            subtitleParts.append(location)
        }
        if let date = entry.date {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            subtitleParts.append(formatter.string(from: date))
        }
        self.subtitle = subtitleParts.joined(separator: " • ")
        
        super.init()
    }
}