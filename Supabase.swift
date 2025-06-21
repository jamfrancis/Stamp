// Supabase.swift
// Contains Supabase sync logic for JournalStore/Entry, which are defined in Entry.swift
//
// NOTE: Make sure to add a `deleted` boolean column to your Supabase table!

import Foundation
import UIKit
import Supabase

struct EntryMeta: Decodable, Equatable {
    let id: String
    let edit: String
    let deleted: Bool
}

struct SupabaseJournalEntryPayload: Encodable {
    let id: String
    let title: String
    let location: String
    let date: String
    let notes: String
    let photoData: String?
    let edit: String
    let deleted: Bool
}

// Your Supabase client instance
private let supabase = SupabaseClient(
  supabaseURL: URL(string: "https://mckefcljzijknlqxvszu.supabase.co")!,
  supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ja2VmY2xqemlqa25scXh2c3p1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk2Njc3MDgsImV4cCI6MjA2NTI0MzcwOH0.saBMXU8bDEpeeEvmy1N0AIzyxCdde71YVD6a2VJyHc4"
)

final class SupabaseManager {
    static let shared = SupabaseManager()
    private init() {}

    // Call this to sync all journal entries to Supabase
    func sync(entries: [Entry]) async {
        // Change table name if needed
        let table = "journal_entries"

        // Prepare payload
        let payloads: [SupabaseJournalEntryPayload] = entries.map { entry in
            SupabaseJournalEntryPayload(
                id: entry.id.uuidString,
                title: entry.title,
                location: entry.location,
                date: ISO8601DateFormatter().string(from: entry.date),
                notes: entry.notes,
                photoData: entry.photoData?.compressedJPEGData(quality: 0.7)?.base64EncodedString(),
                edit: ISO8601DateFormatter().string(from: entry.edit),
                deleted: entry.isDeleted
            )
        }

        do {
            // Upsert (insert or update) all journal entries
            let _ = try await supabase.from(table)
                .upsert(payloads)
                .execute()
        } catch {
            print("Supabase sync error: \(error)")
        }
    }

    func syncBothWays(journalStore: JournalStore) async {
        // Upload local entries first
        await sync(entries: journalStore.entries)

        let table = "journal_entries"

        do {
            let response = try await supabase.from(table).select("*").execute()
            print("Raw Supabase response: \(response)")
            print("Type of response.data: ", type(of: response.data))

            guard let data = response.data as? Data else {
                print("Supabase fetch error: expected Data type in response")
                return
            }

            // Optional: Print JSON for debugging
            if let json = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) {
                print("Fetched JSON from Supabase:\n\(json)")
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let remoteEntries: [Entry]
            do {
                remoteEntries = try decoder.decode([Entry].self, from: data)
            } catch {
                print("Supabase fetch error: failed to decode entries: \(error)")
                return
            }

            // Merge remote entries with local entries
            var mergedEntries = journalStore.entries
            let localIDs = Set(journalStore.entries.map { $0.id })

            // Remove entries locally that are marked deleted remotely
            for remoteEntry in remoteEntries {
                if remoteEntry.isDeleted {
                    mergedEntries.removeAll { $0.id == remoteEntry.id }
                }
            }

            // Add remote entries that are not deleted and not present locally
            for remoteEntry in remoteEntries {
                if !remoteEntry.isDeleted && !localIDs.contains(remoteEntry.id) {
                    mergedEntries.append(remoteEntry)
                }
            }

            // Filter out entries locally that are marked deleted locally
            // This ensures soft-deleted entries do not remain in the local list after sync
            mergedEntries.removeAll { $0.isDeleted }

            await MainActor.run {
                journalStore.entries = mergedEntries
                journalStore.save()
            }
        } catch {
            print("Supabase fetch error: \(error)")
            if let postgrestError = error as? PostgrestError {
                print("Detail: \(postgrestError.detail ?? "")")
                print("Hint: \(postgrestError.hint ?? "")")
                print("Code: \(postgrestError.code ?? "")")
                print("Message: \(postgrestError.message)")
            }
        }
    }

    /// Efficient two-way delta sync using entry metadata comparison
    func syncDelta(journalStore: JournalStore) async {
        let table = "journal_entries"
        do {
            // 1. Fetch remote metadata (id, edit, deleted)
            let response = try await supabase.from(table)
                .select("id,edit,deleted")
                .execute()
            guard let data = response.data as? Data else {
                print("Supabase syncDelta error: expected Data type in response")
                return
            }
            let decoder = JSONDecoder()
            let remoteMeta = try decoder.decode([EntryMeta].self, from: data)
            let localMeta = journalStore.entries.map { EntryMeta(id: $0.id.uuidString, edit: ISO8601DateFormatter().string(from: $0.edit), deleted: $0.isDeleted) }

            // 2. Identify entries to upload (local newer or missing remotely)
            let remoteMetaDict = Dictionary(uniqueKeysWithValues: remoteMeta.map { ($0.id, $0) })
            var toUpload: [Entry] = []
            for entry in journalStore.entries {
                let eid = entry.id.uuidString
                if let remote = remoteMetaDict[eid] {
                    if remote.edit < ISO8601DateFormatter().string(from: entry.edit) {
                        toUpload.append(entry)
                    }
                } else {
                    // Not on remote: upload
                    toUpload.append(entry)
                }
            }

            // 3. Upload only changed/new entries
            if !toUpload.isEmpty {
                let payloads: [SupabaseJournalEntryPayload] = toUpload.map { entry in
                    SupabaseJournalEntryPayload(
                        id: entry.id.uuidString,
                        title: entry.title,
                        location: entry.location,
                        date: ISO8601DateFormatter().string(from: entry.date),
                        notes: entry.notes,
                        photoData: entry.photoData?.compressedJPEGData(quality: 0.7)?.base64EncodedString(),
                        edit: ISO8601DateFormatter().string(from: entry.edit),
                        deleted: entry.isDeleted
                    )
                }
                let _ = try await supabase.from(table).upsert(payloads).execute()
            }

            // 4. Identify entries to download (remote newer or missing locally)
            let localMetaDict = Dictionary(uniqueKeysWithValues: localMeta.map { ($0.id, $0) })
            var idsToFetch: [String] = []
            for remote in remoteMeta {
                if let local = localMetaDict[remote.id] {
                    if remote.edit > local.edit {
                        idsToFetch.append(remote.id)
                    }
                } else if !remote.deleted {
                    // Not on local and not deleted: fetch
                    idsToFetch.append(remote.id)
                }
            }

            // 5. Download only changed/new entries
            var remoteChangedEntries: [Entry] = []
            if !idsToFetch.isEmpty {
                let response = try await supabase.from(table)
                    .select()
                    .in("id", value: idsToFetch)
                    .execute()
                if let data = response.data as? Data {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let entries = try decoder.decode([Entry].self, from: data)
                    remoteChangedEntries = entries
                }
            }

            // 6. Merge changes
            var mergedEntries = journalStore.entries
            for remoteEntry in remoteChangedEntries {
                if let idx = mergedEntries.firstIndex(where: { $0.id == remoteEntry.id }) {
                    mergedEntries[idx] = remoteEntry
                } else {
                    mergedEntries.append(remoteEntry)
                }
            }

            // 7. Remove entries locally if marked deleted remotely
            for remote in remoteMeta where remote.deleted {
                if let idx = mergedEntries.firstIndex(where: { $0.id.uuidString == remote.id }) {
                    mergedEntries.remove(at: idx)
                }
            }

            // Remove entries marked deleted locally
            mergedEntries.removeAll { $0.isDeleted }

            await MainActor.run {
                journalStore.entries = mergedEntries
                journalStore.save()
            }
        } catch {
            print("Supabase syncDelta error: \(error)")
        }
    }

    private static func entry(from dict: [String: Any]) -> Entry? {
        guard
            let idString = dict["id"] as? String,
            let id = UUID(uuidString: idString),
            let title = dict["title"] as? String,
            let location = dict["location"] as? String,
            let dateString = dict["date"] as? String,
            let date = ISO8601DateFormatter().date(from: dateString),
            let notes = dict["notes"] as? String,
            let editString = dict["edit"] as? String,
            let editDate = ISO8601DateFormatter().date(from: editString)
        else {
            return nil
        }

        var photoData: Data? = nil
        if let photoBase64 = dict["photoData"] as? String {
            photoData = Data(base64Encoded: photoBase64)
        }

        let deleted = dict["deleted"] as? Bool ?? false

        return Entry(id: id, title: title, location: location, date: date, notes: notes, photoData: photoData, edit: editDate, isDeleted: deleted, latitude: nil, longitude: nil)
    }
}

#if canImport(UIKit)
extension Data {
    /// Attempts to compress image data (JPEG/PNG) to JPEG at the given quality.
    /// Returns nil if the data is not a valid image.
    func compressedJPEGData(quality: CGFloat = 0.5) -> Data? {
        if let image = UIImage(data: self) {
            return image.jpegData(compressionQuality: quality)
        }
        return nil
    }
}
#endif
