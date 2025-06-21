// Entry.swift

import Foundation
import SwiftUI
import CoreData

class CoreDataManager {
    static let shared = CoreDataManager()
    lazy var viewContext: NSManagedObjectContext = {
        let container = NSPersistentContainer(name: "Stamp")
        container.loadPersistentStores { _, _ in }
        return container.viewContext
    }()
    func saveContext() {
        let context = viewContext
        if context.hasChanges {
            try? context.save()
        }
    }
}

// Model for each journal entry
struct Entry: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var location: String
    var date: Date
    var notes: String
    var photoData: Data?
    var edit: Date
    var isArchived: Bool = false // Changed from isDeleted to isArchived
    var latitude: Double? = nil
    var longitude: Double? = nil

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    // Add proper initializer for all parameters
    init(id: UUID, title: String, location: String, date: Date, notes: String, photoData: Data?, edit: Date, isArchived: Bool = false, latitude: Double? = nil, longitude: Double? = nil) {
        self.id = id
        self.title = title
        self.location = location
        self.date = date
        self.notes = notes
        self.photoData = photoData
        self.edit = edit
        self.isArchived = isArchived
        self.latitude = latitude
        self.longitude = longitude
    }

    // Conversion from JournalEntry (Core Data)
    init(from managed: JournalEntry) {
        self.id = UUID() // JournalEntry does not have 'id'; generate new UUID
        self.title = managed.title ?? ""
        self.location = "" // Not available in JournalEntry model
        self.date = managed.date ?? Date()
        self.notes = managed.content ?? "" // 'content' maps to 'notes'
        self.photoData = nil // Not available in JournalEntry model
        self.edit = managed.date ?? Date() // Fallback to date
        self.isArchived = managed.isArchived
        self.latitude = nil // Not available in JournalEntry model
        self.longitude = nil // Not available in JournalEntry model
    }
}

// Observable store for journal entries
class JournalStore: ObservableObject {
    @Published var entries: [Entry] = []
    private let context = CoreDataManager.shared.viewContext
    private let saveKey = "TravelJournalEntries"

    init() {
        // Migrate data from UserDefaults once if present
        migrateUserDefaultsIfNeeded()
        load()
    }

    func load() {
        let request = JournalEntry.fetchRequest() as! NSFetchRequest<JournalEntry>
        request.sortDescriptors = [NSSortDescriptor(keyPath: \JournalEntry.date, ascending: false)]
        if let objects = try? context.fetch(request) {
            self.entries = objects.map { Entry(from: $0) }
        } else {
            self.entries = []
        }
    }

    func addEntry(_ entry: Entry) {
        let managed = JournalEntry(context: context)
        // Assign only fields existing in JournalEntry model
        managed.title = entry.title
        managed.content = entry.notes // Map notes to content
        managed.date = entry.date
        managed.isArchived = entry.isArchived
        // The following fields do not exist in JournalEntry and are omitted:
        // id, location, photoData, edit, latitude, longitude
        CoreDataManager.shared.saveContext()
        load()
    }

    func save() {
        // Update existing entries in Core Data
        for entry in entries {
            let request = JournalEntry.fetchRequest() as! NSFetchRequest<JournalEntry>
            request.predicate = NSPredicate(format: "id == %@", entry.id as CVarArg)
            if let result = try? context.fetch(request), let managed = result.first {
                managed.title = entry.title
                managed.content = entry.notes // Map notes to content
                managed.date = entry.date
                managed.isArchived = entry.isArchived
                // The following fields do not exist in JournalEntry and are omitted:
                // id, location, photoData, edit, latitude, longitude
            }
        }
        CoreDataManager.shared.saveContext()
        load()
    }

    private func migrateUserDefaultsIfNeeded() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let legacyEntries = try? JSONDecoder().decode([Entry].self, from: data) else { return }
        // Import each legacy entry to Core Data
        for entry in legacyEntries {
            let request = JournalEntry.fetchRequest() as! NSFetchRequest<JournalEntry>
            request.predicate = NSPredicate(format: "id == %@", entry.id as CVarArg)
            if let result = try? context.fetch(request), result.isEmpty {
                let managed = JournalEntry(context: context)
                managed.title = entry.title
                managed.content = entry.notes // Map notes to content
                managed.date = entry.date
                managed.isArchived = entry.isArchived
                // The following fields do not exist in JournalEntry and are omitted:
                // id, location, photoData, edit, latitude, longitude
            }
        }
        CoreDataManager.shared.saveContext()
        UserDefaults.standard.removeObject(forKey: saveKey)
    }
}
