import Foundation
import CoreData
import SwiftUI
import Supabase

// Loads Supabase credentials from Secrets.plist
private func loadSupabaseCredentials() -> (url: URL, key: String)? {
    guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
          let dict = NSDictionary(contentsOfFile: path),
          let urlString = dict["SUPABASE_URL"] as? String,
          let key = dict["SUPABASE_KEY"] as? String,
          let url = URL(string: urlString) else {
        print("❌ Failed to load Supabase credentials from Secrets.plist")
        return nil
    }
    return (url: url, key: key)
}

// Global Supabase client instance with project credentials
let supabase: SupabaseClient = {
    guard let creds = loadSupabaseCredentials() else {
        fatalError("Supabase credentials missing or invalid. Please provide a valid Secrets.plist file.")
    }
    return SupabaseClient(
        supabaseURL: creds.url,
        supabaseKey: creds.key
    )
}()

// Custom error types for Supabase operations
enum SupabaseError: Error {
    case invalidURL
    case networkError
    case uploadFailed
    case deleteFailed
    case updateFailed
    case decodingError
}

// Sync status states for UI feedback
enum SyncStatus: Equatable {
    case idle
    case syncing
    case success
    case error(String)
}

// Main Supabase manager class for syncing stamps and handling storage
class Supabase: ObservableObject {
    static let shared = Supabase()
    
    // Published properties for UI binding
    @Published var syncStatus: SyncStatus = .idle
    @Published var hasPendingChanges: Bool = false
    
    // Database and storage configuration
    private let tableName = "stamps"
    private let storageBucket = "photos"
    
    // Tracks the last successful sync timestamp for delta syncing
    private var lastSync: Date {
        get {
            UserDefaults.standard.object(forKey: "lastSyncDate") as? Date ?? Date(timeIntervalSince1970: 0)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "lastSyncDate")
        }
    }
    
    // Tracks entry IDs that have local changes waiting to be synced
    private var pendingChanges: Set<UUID> {
        get {
            let array = UserDefaults.standard.array(forKey: "pendingChanges") as? [String] ?? []
            return Set(array.compactMap { UUID(uuidString: $0) })
        }
        set {
            let array = newValue.map { $0.uuidString }
            UserDefaults.standard.set(array, forKey: "pendingChanges")
            // Update UI state on main thread
            DispatchQueue.main.async {
                self.hasPendingChanges = !newValue.isEmpty
            }
        }
    }
    
    private init() {
        // Initialize pending changes state from UserDefaults
        hasPendingChanges = !pendingChanges.isEmpty
    }

    // Fetches entries from Supabase that were updated since the last sync
    private func fetchDelta(since date: Date) async throws -> [SupabaseJournalEntryPayload] {
        let dateFormatter = ISO8601DateFormatter()
        let sinceString = dateFormatter.string(from: date)
        
        do {
            print("📥 Fetching delta from Supabase since: \(sinceString)")
            // Query Supabase for entries with updated_at >= lastSync
            let response: [SupabaseJournalEntryPayload] = try await supabase
                .from(tableName)
                .select("*")
                .gte("updated_at", value: sinceString)
                .order("updated_at", ascending: false)
                .execute()
                .value
            
            // Log sync results for debugging
            print("📥 Received \(response.count) entries from server")
            for entry in response {
                print("📥 Entry: \(entry.title) - archived: \(entry.isArchived) - updated: \(entry.updatedAt)")
            }
            return response
        } catch {
            print("❌ Fetch delta failed: \(error)")
            print("❌ Fetch delta error type: \(type(of: error))")
            throw SupabaseError.networkError
        }
    }

    // Finds local Core Data entries that need to be synced to Supabase
    private func fetchLocalChanges() async -> [SupabaseJournalEntryPayload] {
        let context = CoreDataManager.shared.viewContext
        let request = NSFetchRequest<JournalEntry>(entityName: "JournalEntry")
        
        print("🔍 Last sync: \(lastSync)")
        print("🔍 Pending changes: \(pendingChanges)")
        
        // Find entries modified since last sync or marked for sync
        let predicate = NSPredicate(format: "editDate > %@ OR id IN %@", 
                                   lastSync as NSDate, 
                                   Array(pendingChanges))
        request.predicate = predicate
        
        do {
            let entries = try context.fetch(request)
            print("🔍 Found \(entries.count) local entries to sync")
            
            // Convert Core Data entries to Supabase payload format
            var payloads: [SupabaseJournalEntryPayload] = []
            for entry in entries {
                print("🔍 Processing entry: \(entry.title ?? "Untitled") (ID: \(entry.id))")
                if let payload = await convertToSupabasePayload(entry) {
                    payloads.append(payload)
                }
            }
            
            // Clean up pending changes for entries that no longer exist
            let existingIds = Set(entries.map { $0.id })
            let pendingIds = pendingChanges
            let orphanedIds = pendingIds.subtracting(existingIds)
            
            if !orphanedIds.isEmpty {
                print("🧹 Cleaning up \(orphanedIds.count) orphaned pending changes")
                var cleanedPending = pendingIds
                for orphanedId in orphanedIds {
                    cleanedPending.remove(orphanedId)
                }
                pendingChanges = cleanedPending
            }
            
            print("🔍 Created \(payloads.count) payloads for upload")
            return payloads
        } catch {
            print("❌ Failed to fetch local changes: \(error)")
            return []
        }
    }

    private func uploadLocalChanges(_ changes: [SupabaseJournalEntryPayload]) async throws {
        guard !changes.isEmpty else { 
            print("📤 No local changes to upload")
            return 
        }
        
        print("📤 Uploading \(changes.count) local changes...")
        
        for change in changes {
            print("📤 Uploading entry: \(change.title) (ID: \(change.id))")
            try await uploadSingleEntry(change)
            print("✅ Successfully uploaded: \(change.title)")
        }
        
        // Clear pending changes for successfully uploaded entries
        var currentPending = pendingChanges
        for change in changes {
            currentPending.remove(change.id)
        }
        pendingChanges = currentPending
        print("✅ Cleared \(changes.count) entries from pending changes")
    }
    
    private func uploadSingleEntry(_ entry: SupabaseJournalEntryPayload) async throws {
        do {
            print("🔗 Uploading to table: \(tableName)")
            print("📋 Entry data: \(entry)")
            
            try await supabase
                .from(tableName)
                .upsert(entry)
                .execute()
        } catch {
            print("❌ Upload failed for \(entry.title): \(error)")
            print("❌ Upload error type: \(type(of: error))")
            if let supabaseError = error as? any Error {
                print("❌ Detailed error: \(supabaseError)")
            }
            throw SupabaseError.uploadFailed
        }
    }

    private func iso8601Date(from string: String) -> Date {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: string) ?? Date()
    }

    private func deleteLocalEntry(id: UUID) async throws {
        let context = CoreDataManager.shared.viewContext
        let request = NSFetchRequest<JournalEntry>(entityName: "JournalEntry")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let entries = try context.fetch(request)
            entries.forEach { context.delete($0) }
            try context.save()
        } catch {
            throw SupabaseError.deleteFailed
        }
    }

    private func updateOrCreateLocalEntry(entry: Entry) async throws {
        let context = CoreDataManager.shared.viewContext
        let request = NSFetchRequest<JournalEntry>(entityName: "JournalEntry")
        request.predicate = NSPredicate(format: "id == %@", entry.id as CVarArg)
        
        do {
            let existingEntries = try context.fetch(request)
            let managedEntry: JournalEntry
            
            if let existing = existingEntries.first {
                managedEntry = existing
            } else {
                managedEntry = JournalEntry(context: context)
                managedEntry.id = entry.id
            }
            
            managedEntry.update(with: entry)
            try context.save()
        } catch {
            throw SupabaseError.updateFailed
        }
    }
    
    private func convertToSupabasePayload(_ entry: JournalEntry) async -> SupabaseJournalEntryPayload? {
        let dateFormatter = ISO8601DateFormatter()
        let now = Date()
        
        // Handle photo upload to Storage if we have photo data
        var photoUrl: String? = nil
        if let photoData = entry.photoData {
            do {
                photoUrl = try await uploadPhoto(photoData, entryId: entry.id)
                print("📸 Photo uploaded, URL: \(photoUrl ?? "nil")")
            } catch {
                print("❌ Failed to upload photo for entry \(entry.id): \(error)")
                // Continue without photo rather than failing the entire sync
            }
        }
        
        var payload = SupabaseJournalEntryPayload(
            id: entry.id,
            title: entry.title ?? "",
            content: entry.content ?? "",
            location: entry.location ?? "",
            date: dateFormatter.string(from: entry.date ?? now),
            photoData: photoUrl,
            editDate: dateFormatter.string(from: entry.editDate ?? now),
            isArchived: entry.isArchived,
            latitude: entry.latitude != 0 ? entry.latitude : nil,
            longitude: entry.longitude != 0 ? entry.longitude : nil,
            createdAt: dateFormatter.string(from: entry.date ?? now),
            updatedAt: dateFormatter.string(from: entry.editDate ?? now)
        )
        return payload
    }
    
    // MARK: - Storage Functions
    func uploadPhoto(_ photoData: Data, entryId: UUID) async throws -> String {
        let fileName = "\(entryId.uuidString).jpg"
        let filePath = fileName
        
        do {
            print("📸 Uploading photo to Storage: \(fileName)")
            
            try await supabase.storage
                .from(storageBucket)
                .upload(path: filePath, file: photoData, options: FileOptions(upsert: true))
            
            // Get public URL
            let publicURL = try supabase.storage
                .from(storageBucket)
                .getPublicURL(path: filePath)
            
            print("✅ Photo uploaded successfully: \(publicURL)")
            return publicURL.absoluteString
        } catch {
            print("❌ Photo upload failed: \(error)")
            throw SupabaseError.uploadFailed
        }
    }
    
    func downloadPhoto(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw SupabaseError.invalidURL
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return data
        } catch {
            print("❌ Photo download failed: \(error)")
            throw SupabaseError.networkError
        }
    }
    
    // MARK: - Favorites API
    func toggleFavorite(stampId: UUID) async throws -> Bool {
        do {
            // Check if favorite exists
            let existingFavorites: [FavoriteRecord] = try await supabase
                .from("favorites")
                .select("*")
                .eq("stamp_id", value: stampId.uuidString)
                .execute()
                .value
            
            if let existingFavorite = existingFavorites.first {
                // Toggle existing favorite
                let newFavoriteStatus = !existingFavorite.isFavorite
                
                try await supabase
                    .from("favorites")
                    .update(["is_favorite": newFavoriteStatus])
                    .eq("stamp_id", value: stampId.uuidString)
                    .execute()
                
                print("✅ Toggled favorite for stamp \(stampId): \(newFavoriteStatus)")
                return newFavoriteStatus
            } else {
                // Create new favorite record
                let newFavorite = FavoriteRecord(
                    id: UUID(),
                    stampId: stampId,
                    isFavorite: true,
                    createdAt: Date(),
                    updatedAt: Date()
                )
                
                try await supabase
                    .from("favorites")
                    .insert(newFavorite)
                    .execute()
                
                print("✅ Created favorite for stamp \(stampId)")
                return true
            }
        } catch {
            print("❌ Failed to toggle favorite: \(error)")
            throw SupabaseError.updateFailed
        }
    }
    
    func getFavoriteStatus(stampId: UUID) async throws -> Bool {
        do {
            let favorites: [FavoriteRecord] = try await supabase
                .from("favorites")
                .select("*")
                .eq("stamp_id", value: stampId.uuidString)
                .execute()
                .value
            
            return favorites.first?.isFavorite ?? false
        } catch {
            print("❌ Failed to get favorite status: \(error)")
            return false
        }
    }
    
    func getFavoriteStamps() async throws -> [UUID] {
        do {
            let favorites: [FavoriteRecord] = try await supabase
                .from("favorites")
                .select("*")
                .eq("is_favorite", value: true)
                .execute()
                .value
            
            print("📊 Found \(favorites.count) favorite stamps")
            return favorites.map { $0.stampId }
        } catch {
            print("❌ Failed to fetch favorite stamps: \(error)")
            throw SupabaseError.networkError
        }
    }
    
    // MARK: - Public API
    // Marks an entry ID as needing sync
    func markForSync(_ entryId: UUID) {
        var current = pendingChanges
        current.insert(entryId)
        pendingChanges = current
    }
    
    // Removes an entry from pending changes (used when permanently deleted)
    func removeFromPendingSync(_ entryId: UUID) {
        var current = pendingChanges
        current.remove(entryId)
        pendingChanges = current
    }
    
    // Clears all pending changes (use for fixing sync issues)
    func clearPendingChanges() {
        pendingChanges = Set<UUID>()
        print("🧹 Cleared all pending changes")
    }
    
    // Handles permanent deletion by removing from Supabase
    func deletePermanently(_ entryId: UUID) async throws {
        do {
            print("🗑️ Permanently deleting entry from Supabase: \(entryId)")
            try await supabase
                .from(tableName)
                .delete()
                .eq("id", value: entryId.uuidString)
                .execute()
            
            // Remove from pending changes since it's now deleted
            removeFromPendingSync(entryId)
            print("✅ Successfully deleted entry from Supabase")
        } catch {
            print("❌ Failed to delete entry from Supabase: \(error)")
            throw SupabaseError.deleteFailed
        }
    }
    
    func testConnection() async {
        print("🧪 Testing Supabase connection...")
        print("🔗 Connecting to table: \(tableName)")
        
        do {
            // Simple read test - just try to read any data from the table
            let response = try await supabase
                .from(tableName)
                .select("id")
                .limit(1)
                .execute()
            
            print("✅ Supabase connection successful!")
            print("📊 Response data size: \(response.data.count) bytes")
            
        } catch {
            print("❌ Supabase connection failed: \(error)")
            
            // Check if it's a table not found error
            if let errorString = error.localizedDescription.lowercased() as String? {
                if errorString.contains("relation") && errorString.contains("does not exist") {
                    print("💡 Suggestion: Create a 'stamps' table in your Supabase database")
                } else if errorString.contains("permission") || errorString.contains("policy") {
                    print("💡 Suggestion: Check RLS policies - enable read/write for authenticated users")
                } else {
                    print("💡 Raw error: \(error)")
                }
            }
        }
    }
    
    func syncInBackground() {
        Task {
            await performSync()
        }
    }
    
    private func performSync() async {
        await MainActor.run {
            syncStatus = .syncing
        }
        
        do {
            try await sync()
            lastSync = Date()
            await MainActor.run {
                syncStatus = .success
            }
            
            // Reset to idle after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.syncStatus = .idle
            }
        } catch {
            await MainActor.run {
                syncStatus = .error(error.localizedDescription)
            }
            
            // Reset to idle after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.syncStatus = .idle
            }
        }
    }
}

struct EntryMeta: Codable, Equatable, Hashable {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var isArchived: Bool
}

struct FavoriteRecord: Codable {
    var id: UUID
    var stampId: UUID
    var isFavorite: Bool
    var createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case stampId = "stamp_id"
        case isFavorite = "is_favorite"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct SupabaseJournalEntryPayload: Codable {
    var id: UUID
    var title: String
    var content: String
    var location: String
    var date: String
    var photoData: String? // Changed from Data? to String? for URLs
    var editDate: String
    var isArchived: Bool
    var latitude: Double?
    var longitude: Double?
    var createdAt: String
    var updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case content
        case location
        case date
        case photoData = "photo_data"
        case editDate = "edit_date"
        case isArchived = "is_archived"
        case latitude
        case longitude
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(id: UUID, title: String, content: String, location: String, date: String, photoData: String?, editDate: String, isArchived: Bool, latitude: Double?, longitude: Double?, createdAt: String, updatedAt: String) {
        self.id = id
        self.title = title
        self.content = content
        self.location = location
        self.date = date
        self.photoData = photoData
        self.editDate = editDate
        self.isArchived = isArchived
        self.latitude = latitude
        self.longitude = longitude
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        location = try container.decode(String.self, forKey: .location)
        date = try container.decode(String.self, forKey: .date)
        editDate = try container.decode(String.self, forKey: .editDate)
        isArchived = try container.decode(Bool.self, forKey: .isArchived)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
        
        // Handle photo_data with error recovery (supports both URLs and Base64)
        do {
            photoData = try container.decodeIfPresent(String.self, forKey: .photoData)
        } catch {
            print("⚠️ Failed to decode photo_data for entry \(id): \(error)")
            print("⚠️ Setting photoData to nil and continuing...")
            photoData = nil
        }
    }
}

extension SupabaseJournalEntryPayload {
    func entry() async -> Entry {
        // Handle photo download if we have a URL
        var photoData: Data? = nil
        if let photoUrlString = self.photoData, !photoUrlString.isEmpty {
            // Check if it's a URL (starts with http) or Base64 data
            if photoUrlString.hasPrefix("http") {
                // It's a Storage URL - download the photo
                do {
                    photoData = try await Supabase.shared.downloadPhoto(from: photoUrlString)
                } catch {
                    print("⚠️ Failed to download photo from \(photoUrlString): \(error)")
                    photoData = nil
                }
            } else {
                // It's Base64 data - decode it
                photoData = Data(base64Encoded: photoUrlString)
                if photoData == nil {
                    print("⚠️ Failed to decode Base64 photo data")
                }
            }
        }
        
        return Entry(
            id: id,
            title: title,
            location: location,
            date: iso8601Date(from: date),
            notes: content,
            photoData: photoData,
            edit: iso8601Date(from: editDate),
            isArchived: isArchived,
            latitude: latitude,
            longitude: longitude
        )
    }
    
    private func iso8601Date(from string: String) -> Date {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: string) ?? Date()
    }
}

extension Supabase {
    func sync() async throws {
        try await syncBothWays()
    }

    private func syncBothWays() async throws {
        // Fetch entries delta from Supabase
        let delta = try await fetchDelta(since: lastSync)
        try await syncDelta(delta)
        
        // Upload local changes
        let localChanges = await fetchLocalChanges()
        try await uploadLocalChanges(localChanges)
    }

    private func syncDelta(_ delta: [SupabaseJournalEntryPayload]) async throws {
        for payload in delta {
            // Always update/create the entry, don't delete based on isArchived
            // The isArchived flag should be preserved in the local entry
            let entry = await payload.entry()
            try await updateOrCreateLocalEntry(entry: entry)
        }
    }
}
