import Foundation
import CoreData

// Reminder: Please update your Supabase table column from 'deleted' or 'isDeleted' to 'isArchived'.

class Supabase {
    // MARK: - Sync Support Stubs

    private var lastSync: Date {
        // TODO: Replace with real last sync tracking
        return Date(timeIntervalSince1970: 0)
    }

    private func fetchDelta(since date: Date) async throws -> [SupabaseJournalEntryPayload] {
        // TODO: Implement fetching changed entries from Supabase
        return []
    }

    private func fetchLocalChanges() -> [SupabaseJournalEntryPayload] {
        // TODO: Implement fetching local changes to be uploaded
        return []
    }

    private func uploadLocalChanges(_ changes: [SupabaseJournalEntryPayload]) async throws {
        // TODO: Implement upload to Supabase
    }

    private func iso8601Date(from string: String) -> Date {
        // TODO: Replace with robust ISO 8601 parsing as needed
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: string) ?? Date()
    }

    private func deleteLocalEntry(id: UUID) async throws {
        // TODO: Implement deleting a local entry
    }

    private func updateOrCreateLocalEntry(entry: Entry) async throws {
        // TODO: Implement local create/update logic
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
    var createdAt: String
    var updatedAt: String
    var isArchived: Bool
    var content: String
}

extension SupabaseJournalEntryPayload {
    func entry(from meta: EntryMeta) -> Entry {
        return Entry(
            id: meta.id,
            title: "",
            location: "",
            date: meta.createdAt,
            notes: content,
            photoData: nil,
            edit: meta.updatedAt,
            isArchived: meta.isArchived
        )
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
            let meta = EntryMeta(
                id: payload.id,
                createdAt: iso8601Date(from: payload.createdAt),
                updatedAt: iso8601Date(from: payload.updatedAt),
                isArchived: payload.isArchived
            )
            if payload.isArchived {
                try await deleteLocalEntry(id: meta.id)
            } else {
                try await updateOrCreateLocalEntry(entry: payload.entry(from: meta))
            }
        }
    }
}
