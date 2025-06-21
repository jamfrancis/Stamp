import Foundation
import CoreData
import SwiftUI
import Supabase

enum SupabaseError: Error {
    case invalidURL
    case networkError
    case uploadFailed
    case deleteFailed
    case updateFailed
    case decodingError
}

enum SyncStatus: Equatable {
    case idle
    case syncing
    case success
    case error(String)
}

let supabase = SupabaseClient(
  supabaseURL: URL(string: "https://mckefcljzijknlqxvszu.supabase.co")!,
  supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ja2VmY2xqemlqa25scXh2c3p1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk2Njc3MDgsImV4cCI6MjA2NTI0MzcwOH0.saBMXU8bDEpeeEvmy1N0AIzyxCdde71YVD6a2VJyHc4"
)

class Supabase: ObservableObject {
    static let shared = Supabase()
    
    @Published var syncStatus: SyncStatus = .idle
    @Published var hasPendingChanges: Bool = false
    
    private let tableName = "stamps"
    
    private var lastSync: Date {
        get {
            UserDefaults.standard.object(forKey: "lastSyncDate") as? Date ?? Date(timeIntervalSince1970: 0)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "lastSyncDate")
        }
    }
    
    private var pendingChanges: Set<UUID> {
        get {
            let array = UserDefaults.standard.array(forKey: "pendingChanges") as? [String] ?? []
            return Set(array.compactMap { UUID(uuidString: $0) })
        }
        set {
            let array = newValue.map { $0.uuidString }
            UserDefaults.standard.set(array, forKey: "pendingChanges")
            DispatchQueue.main.async {
                self.hasPendingChanges = !newValue.isEmpty
            }
        }
    }
    
    private init() {
        // Initialize the hasPendingChanges state
        hasPendingChanges = !pendingChanges.isEmpty
    }

    private func fetchDelta(since date: Date) async throws -> [SupabaseJournalEntryPayload] {
        let dateFormatter = ISO8601DateFormatter()
        let sinceString = dateFormatter.string(from: date)
        
        do {
            print("📥 Fetching delta from Supabase since: \(sinceString)")
            let response: [SupabaseJournalEntryPayload] = try await supabase
                .from(tableName)
                .select("*")
                .gte("updated_at", value: sinceString)
                .order("updated_at", ascending: false)
                .execute()
                .value
            
            print("📥 Received \(response.count) entries from server")
            return response
        } catch {
            print("❌ Fetch delta failed: \(error)")
            print("❌ Fetch delta error type: \(type(of: error))")
            throw SupabaseError.networkError
        }
    }

    private func fetchLocalChanges() -> [SupabaseJournalEntryPayload] {
        let context = CoreDataManager.shared.viewContext
        let request = NSFetchRequest<JournalEntry>(entityName: "JournalEntry")
        
        print("🔍 Last sync: \(lastSync)")
        print("🔍 Pending changes: \(pendingChanges)")
        
        // Fetch entries that have pending changes or were modified since last sync
        let predicate = NSPredicate(format: "editDate > %@ OR id IN %@", 
                                   lastSync as NSDate, 
                                   Array(pendingChanges))
        request.predicate = predicate
        
        do {
            let entries = try context.fetch(request)
            print("🔍 Found \(entries.count) local entries to sync")
            
            let payloads = entries.compactMap { entry in
                print("🔍 Processing entry: \(entry.title ?? "Untitled") (ID: \(entry.id))")
                return convertToSupabasePayload(entry)
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
    
    private func convertToSupabasePayload(_ entry: JournalEntry) -> SupabaseJournalEntryPayload? {
        let dateFormatter = ISO8601DateFormatter()
        let now = Date()
        
        return SupabaseJournalEntryPayload(
            id: entry.id,
            title: entry.title ?? "",
            content: entry.content ?? "",
            location: entry.location ?? "",
            date: dateFormatter.string(from: entry.date ?? now),
            photoData: entry.photoData,
            editDate: dateFormatter.string(from: entry.editDate ?? now),
            isArchived: entry.isArchived,
            latitude: entry.latitude != 0 ? entry.latitude : nil,
            longitude: entry.longitude != 0 ? entry.longitude : nil,
            createdAt: dateFormatter.string(from: entry.date ?? now),
            updatedAt: dateFormatter.string(from: entry.editDate ?? now)
        )
    }
    
    // MARK: - Public API
    func markForSync(_ entryId: UUID) {
        var current = pendingChanges
        current.insert(entryId)
        pendingChanges = current
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

struct SupabaseJournalEntryPayload: Codable {
    var id: UUID
    var title: String
    var content: String
    var location: String
    var date: String
    var photoData: Data?
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
}

extension SupabaseJournalEntryPayload {
    func entry() -> Entry {
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
        let localChanges = fetchLocalChanges()
        try await uploadLocalChanges(localChanges)
    }

    private func syncDelta(_ delta: [SupabaseJournalEntryPayload]) async throws {
        for payload in delta {
            if payload.isArchived {
                try await deleteLocalEntry(id: payload.id)
            } else {
                try await updateOrCreateLocalEntry(entry: payload.entry())
            }
        }
    }
}
