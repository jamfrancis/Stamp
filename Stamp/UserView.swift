// UserView.swift
// User / Account tab for managing user preferences and manual sync with backend.
// Uses JournalStore and Entry models defined in Entry.swift.

import SwiftUI
import Foundation

struct UserView: View {
    @ObservedObject var journalStore: JournalStore
    @AppStorage("journalCardView") private var isCardView: Bool = true // persist user's selected layout

    var body: some View {
        Form {
            Section(header: Text("Journal Display")) {
                Picker("Display Mode", selection: $isCardView) {
                    Label("Card View", systemImage: "rectangle.grid.2x2").tag(true)
                    Label("List View", systemImage: "list.bullet").tag(false)
                }
                .pickerStyle(.segmented)
            }
            Section {
                Text("UserView Placeholder")
                    .font(.title)
                    .foregroundColor(.gray)
                Button("Sync Now (Delta Upload & Download)") {
                    Task {
                        await SupabaseManager.shared.syncDelta(journalStore: journalStore)
                    }
                }
            }
        }
        .navigationTitle("User / Sync")
        .navigationBarTitleDisplayMode(.inline)
        // Note: pass isCardView to JournalTabView in StampApp.swift as needed
    }
}
