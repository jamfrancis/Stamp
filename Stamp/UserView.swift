import SwiftUI

// MARK: - Info View
// User profile/settings view showing app statistics, sync status, and favorites
struct UserProfileView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var supabase = Supabase.shared
    @StateObject private var mapSettings = MapSettings.shared
    @State private var showingFavorites = false
    
    // Fetch active (non-archived) stamps for statistics
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \JournalEntry.date, ascending: false)],
        predicate: NSPredicate(format: "isArchived == false"),
        animation: .default)
    private var activeEntries: FetchedResults<JournalEntry>
    
    // Fetch archived stamps for the archived section
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \JournalEntry.date, ascending: false)],
        predicate: NSPredicate(format: "isArchived == true"),
        animation: .default)
    private var archivedEntries: FetchedResults<JournalEntry>
    
    var body: some View {
        NavigationStack {
            List {
                Section("Favorites") {
                    Button(action: {
                        showingFavorites = true
                    }) {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text("View Favorite Stamps")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
                
                Section("Map Settings") {
                    HStack {
                        Image(systemName: "map.fill")
                            .foregroundColor(.blue)
                        Text("Map Implementation")
                        Spacer()
                        Picker("Map Implementation", selection: $mapSettings.selectedImplementation) {
                            ForEach(MapImplementation.allCases, id: \.self) { implementation in
                                Text(implementation.displayName).tag(implementation)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 120)
                    }
                }
                
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
                    
                    // Temporary button to fix orphaned pending changes
                    if supabase.hasPendingChanges {
                        Button(action: {
                            supabase.clearPendingChanges()
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Clear Pending Changes")
                                Spacer()
                            }
                            .foregroundColor(.red)
                        }
                    }
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
            .sheet(isPresented: $showingFavorites) {
                FavoritesListView()
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }
    
    // Counts stamps that have GPS coordinates
    private var entriesWithLocationsCount: Int {
        activeEntries.filter { $0.latitude != 0 && $0.longitude != 0 }.count
    }
    
    // Displays appropriate sync status icon and text
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
            entry.editDate = Date() // Update editDate so updated_at reflects restore time
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
    
    // Permanently deletes an entry from both local and Supabase
    private func deleteEntry(_ entry: JournalEntry) {
        withAnimation {
            let entryId = entry.id
            viewContext.delete(entry)
            do {
                try viewContext.save()
                // Handle permanent deletion in Supabase
                Task {
                    do {
                        try await Supabase.shared.deletePermanently(entryId)
                    } catch {
                        print("Failed to delete from Supabase: \(error)")
                    }
                }
            } catch {
                print("Failed to delete entry locally: \(error)")
            }
        }
    }
}

// MARK: - Favorites List View
// Shows all stamps marked as favorites in a dedicated list
struct FavoritesListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    @State private var favoriteStampIds: [UUID] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    // Fetch all non-archived stamps for filtering
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \JournalEntry.date, ascending: false)],
        predicate: NSPredicate(format: "isArchived == false"),
        animation: .default)
    private var allEntries: FetchedResults<JournalEntry>
    
    // Filter entries to only show favorites
    private var favoriteEntries: [JournalEntry] {
        allEntries.filter { favoriteStampIds.contains($0.id) }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack {
                        ProgressView("Loading favorites...")
                        Spacer()
                    }
                } else if let errorMessage = errorMessage {
                    VStack {
                        Text("Error loading favorites")
                            .font(.headline)
                        Text(errorMessage)
                            .foregroundColor(.secondary)
                        Button("Retry") {
                            loadFavorites()
                        }
                        .buttonStyle(.bordered)
                        Spacer()
                    }
                    .padding()
                } else if favoriteEntries.isEmpty {
                    VStack {
                        Image(systemName: "star")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("No Favorite Stamps")
                            .font(.headline)
                        Text("Tap the star in any stamp to add it to favorites")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .padding()
                } else {
                    List {
                        ForEach(favoriteEntries) { entry in
                            NavigationLink(destination: DisplayView(entry: entry)) {
                                HStack(spacing: 12) {
                                    // Photo thumbnail
                                    if let photoData = entry.photoData, let uiImage = UIImage(data: photoData) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 60, height: 60)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    } else {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(.systemGray5))
                                            .frame(width: 60, height: 60)
                                            .overlay(
                                                Image(systemName: "photo")
                                                    .foregroundColor(.secondary)
                                            )
                                    }
                                    
                                    // Text content
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.title ?? "Untitled")
                                            .font(.headline)
                                            .lineLimit(1)
                                        
                                        if let location = entry.location, !location.isEmpty {
                                            Text(location)
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                        
                                        Text(entry.date ?? Date(), style: .date)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    // Star indicator
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                        .font(.caption)
                                }
                                .contentShape(Rectangle())
                            }
                        }
                    }
                }
            }
            .navigationTitle("Favorite Stamps")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .onAppear {
                loadFavorites()
            }
        }
    }
    
    // Fetches favorite stamp IDs from Supabase
    private func loadFavorites() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Get list of favorited stamp IDs from Supabase
                let favorites = try await Supabase.shared.getFavoriteStamps()
                await MainActor.run {
                    favoriteStampIds = favorites
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}
