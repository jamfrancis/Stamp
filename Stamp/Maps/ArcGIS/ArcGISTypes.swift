// ArcGISTypes.swift
// ArcGIS-specific data types and utilities

import Foundation
import ArcGIS

// MARK: - ArcGIS Stamp Marker
struct ArcGISStampMarker {
    let id: UUID
    let point: Point
    let symbol: Symbol
    let journalEntry: JournalEntry
}

// MARK: - ArcGIS Availability Check
struct ArcGISAvailability {
    static var isAvailable: Bool {
        // Check if ArcGIS framework is available
        #if canImport(ArcGIS)
        return true
        #else
        return false
        #endif
    }
}