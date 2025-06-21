import SwiftUI

// MARK: - Info View
struct UserProfileView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var supabase = Supabase.shared
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \JournalEntry.date, ascending: false)],
        predicate: NSPredicate(format: "isArchived == false"),
        animation: .default)
    private var activeEntries: FetchedResults<JournalEntry>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \JournalEntry.date, ascending: false)],
        predicate: NSPredicate(format: "isArchived == true"),
        animation: .default)
    private var archivedEntries: FetchedResults<JournalEntry>
    
    var body: some View {
        NavigationStack {
            List {
                Section("Statistics") {
                    HStack {
                        Image(systemName: "book.fill")
                            .foregroundColor(.blue)
                        Text("Active Stamps")
                        Spacer()
                        Text("\(activeEntries.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "archivebox.fill")
                            .foregroundColor(.orange)
                        Text("Archived Stamps")
                        Spacer()
                        Text("\(archivedEntries.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.green)
                        Text("Stamps with Locations")
                        Spacer()
                        Text("\(entriesWithLocationsCount)")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Sync") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Status")
                                Spacer()
                                syncStatusIndicator
                            }
                            
                            if supabase.hasPendingChanges {
                                Text("Pending changes waiting to sync")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            } else {
                                Text("All changes synced")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Button(action: {
                        supabase.syncInBackground()
                    }) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Sync Now")
                            Spacer()
                        }
                        .foregroundColor(.blue)
                    }
                    .disabled(supabase.syncStatus == .syncing)
                }
                
                Section("Archived Stamps") {
                    if archivedEntries.isEmpty {
                        Text("No archived stamps")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(archivedEntries) { entry in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.title ?? "Untitled")
                                    .font(.headline)
                                Text(entry.date ?? Date(), style: .date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .swipeActions(edge: .trailing) {
                                Button("Restore") {
                                    restoreEntry(entry)
                                }
                                .tint(.blue)
                                
                                Button("Delete", role: .destructive) {
                                    deleteEntry(entry)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Info")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private var entriesWithLocationsCount: Int {
        activeEntries.filter { $0.latitude != 0 && $0.longitude != 0 }.count
    }
    
    @ViewBuilder
    private var syncStatusIndicator: some View {
        switch supabase.syncStatus {
        case .idle:
            if supabase.hasPendingChanges {
                HStack(spacing: 4) {
                    Image(systemName: "cloud.fill")
                        .foregroundColor(.orange)
                    Text("Pending")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Synced")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        case .syncing:
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Syncing...")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        case .success:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Success")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        case .error(let message):
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("Error")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
    
    private func restoreEntry(_ entry: JournalEntry) {
        withAnimation {
            entry.isArchived = false
            do {
                try viewContext.save()
                // Mark for sync after restore
                Supabase.shared.markForSync(entry.id)
                Supabase.shared.syncInBackground()
            } catch {
                print("Failed to restore entry: \(error)")
            }
        }
    }
    
    private func deleteEntry(_ entry: JournalEntry) {
        withAnimation {
            let entryId = entry.id
            viewContext.delete(entry)
            do {
                try viewContext.save()
                // Mark for sync after permanent delete
                Supabase.shared.markForSync(entryId)
                Supabase.shared.syncInBackground()
            } catch {
                print("Failed to delete entry: \(error)")
            }
        }
    }
}
