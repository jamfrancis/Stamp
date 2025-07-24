// MapViewModel.swift
// Shared view model for MapKit and ArcGIS map views
// Manages selectedEntry state using ObservableObject pattern

import SwiftUI
import Combine

class MapViewModel: ObservableObject {
    @Published var selectedEntry: JournalEntry? = nil
    
    // Method to select an entry (called from map delegates/handlers)
    func selectEntry(_ entry: JournalEntry?) {
        selectedEntry = entry
    }
    
    // Method to clear selection
    func clearSelection() {
        selectedEntry = nil
    }
    
    // Helper to toggle selection (useful for tap handlers)
    func toggleSelection(for entry: JournalEntry) {
        if selectedEntry?.id == entry.id {
            clearSelection()
        } else {
            selectEntry(entry)
        }
    }
}