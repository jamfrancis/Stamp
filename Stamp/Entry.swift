// Entry.swift
// Contains the Entry model and JournalStore class used by the app

import Foundation
import SwiftUI
import CoreData

// Model for each journal entry
struct Entry: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var location: String
    var date: Date
    var notes: String
    var photoData: Data?
    var edit: Date
    var isDeleted: Bool = false
    var latitude: Double? = nil
    var longitude: Double? = nil

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    // Conversion from JournalEntry (Core Data)
    init(from managed: JournalEntry) {
        self.id = managed.id ?? UUID()
        self.title = managed.title ?? ""
        self.location = managed.location ?? ""
        self.date = managed.date ?? Date()
        self.notes = managed.notes ?? ""
        self.photoData = managed.photoData
        self.edit = managed.edit ?? Date()
        self.isDeleted = managed.isDeleted
        self.latitude = (managed.latitude == 0) ? nil : managed.latitude
        self.longitude = (managed.longitude == 0) ? nil : managed.longitude
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
        managed.id = entry.id
        managed.title = entry.title
        managed.location = entry.location
        managed.date = entry.date
        managed.notes = entry.notes
        managed.photoData = entry.photoData
        managed.edit = entry.edit
        managed.isDeleted = entry.isDeleted
        managed.latitude = entry.latitude ?? 0
        managed.longitude = entry.longitude ?? 0
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
                managed.location = entry.location
                managed.date = entry.date
                managed.notes = entry.notes
                managed.photoData = entry.photoData
                managed.edit = entry.edit
                managed.isDeleted = entry.isDeleted
                managed.latitude = entry.latitude ?? 0
                managed.longitude = entry.longitude ?? 0
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
                managed.id = entry.id
                managed.title = entry.title
                managed.location = entry.location
                managed.date = entry.date
                managed.notes = entry.notes
                managed.photoData = entry.photoData
                managed.edit = entry.edit
                managed.isDeleted = entry.isDeleted
                managed.latitude = entry.latitude ?? 0
                managed.longitude = entry.longitude ?? 0
            }
        }
        CoreDataManager.shared.saveContext()
        UserDefaults.standard.removeObject(forKey: saveKey)
    }
}
