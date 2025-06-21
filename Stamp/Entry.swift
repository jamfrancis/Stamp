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
        self.id = managed.id
        self.title = managed.title ?? ""
        self.location = managed.location ?? ""
        self.date = managed.date ?? Date()
        self.notes = managed.content ?? ""
        self.photoData = managed.photoData
        self.edit = managed.editDate ?? Date()
        self.isArchived = managed.isArchived
        self.latitude = managed.latitude == 0 ? nil : managed.latitude
        self.longitude = managed.longitude == 0 ? nil : managed.longitude
    }
}

// MARK: - Core Data Utilities
extension JournalEntry {
    static func create(from entry: Entry, in context: NSManagedObjectContext) {
        let managed = JournalEntry(context: context)
        managed.id = entry.id
        managed.title = entry.title
        managed.content = entry.notes
        managed.location = entry.location
        managed.date = entry.date
        managed.photoData = entry.photoData
        managed.editDate = entry.edit
        managed.isArchived = entry.isArchived
        managed.latitude = entry.latitude ?? 0
        managed.longitude = entry.longitude ?? 0
    }
    
    func update(with entry: Entry) {
        self.title = entry.title
        self.content = entry.notes
        self.location = entry.location
        self.date = entry.date
        self.photoData = entry.photoData
        self.editDate = entry.edit
        self.isArchived = entry.isArchived
        self.latitude = entry.latitude ?? 0
        self.longitude = entry.longitude ?? 0
    }
}
