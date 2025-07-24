// MapInterface.swift
// Unified interface for both MapKit and ArcGIS implementations
// This file provides clean public API for the rest of the app

import SwiftUI

// MARK: - Public Map Interface

/// Enhanced MapKit implementation with photo pins and custom popups
struct EnhancedMapKitView: View {
    let journalEntries: [JournalEntry]
    @Binding var selectedEntry: JournalEntry?
    var onStampTap: ((JournalEntry) -> Void)? = nil
    
    var body: some View {
        MapKitView(
            journalEntries: journalEntries,
            selectedEntry: $selectedEntry,
            onStampTap: onStampTap
        )
    }
}

/// Professional ArcGIS implementation with enterprise-grade cartography
struct EnhancedArcGISView: View {
    let journalEntries: [JournalEntry]
    @Binding var selectedEntry: JournalEntry?
    @Binding var showPastMonthOnly: Bool
    var onStampTap: ((JournalEntry) -> Void)? = nil
    
    var body: some View {
        ArcGISView(
            journalEntries: journalEntries,
            selectedEntry: $selectedEntry,
            showPastMonthOnly: $showPastMonthOnly,
            onStampTap: onStampTap
        )
    }
}

// MARK: - Legacy Support
// Note: JournalMapView already exists in MapView.swift - no alias needed