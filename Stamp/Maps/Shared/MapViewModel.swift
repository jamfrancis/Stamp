// MapViewModel.swift
// shared state management for both map implementations

import SwiftUI
import Combine

class MapViewModel: ObservableObject {
    @Published var selectedEntry: JournalEntry? = nil
    
    // select an entry from map tap
    func selectEntry(_ entry: JournalEntry?) {
        selectedEntry = entry
    }
    
    // clear current selection
    func clearSelection() {
        selectedEntry = nil
    }
    
    // toggle selection on/off
    func toggleSelection(for entry: JournalEntry) {
        if selectedEntry?.id == entry.id {
            clearSelection()
        } else {
            selectEntry(entry)
        }
    }
}