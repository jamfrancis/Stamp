// Entry.swift - Core Data manager and Entry model

import Foundation
import SwiftUI
import CoreData

// Singleton Core Data manager for app-wide database access
class CoreDataManager {
    static let shared = CoreDataManager()
    
    // Main context for UI operations
    lazy var viewContext: NSManagedObjectContext = {
        let container = NSPersistentContainer(name: "Stamp")
        container.loadPersistentStores { _, _ in }
        return container.viewContext
    }()
    
    // Saves any pending changes
    func saveContext() {
        let context = viewContext
        if context.hasChanges {
            try? context.save()
        }
    }
}

// Model of a Stamp/ Journal Entry
struct Entry: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var location: String
    var date: Date
    var notes: String
    var photoData: Data?
    var edit: Date
    var isArchived: Bool = false // Soft delete flag - archived vs active
    var latitude: Double? = nil
    var longitude: Double? = nil

    // Computed property for displaying formatted date
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    // Full initializer for creating new entries
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

    // Convenience initializer for converting from Core Data object
    init(from managed: JournalEntry) {
        self.id = managed.id
        self.title = managed.title ?? ""
        self.location = managed.location ?? ""
        self.date = managed.date ?? Date()
        self.notes = managed.content ?? ""
        self.photoData = managed.photoData
        self.edit = managed.editDate ?? Date()
        self.isArchived = managed.isArchived
        // Convert 0 coordinates to nil (no location data)
        self.latitude = managed.latitude == 0 ? nil : managed.latitude
        self.longitude = managed.longitude == 0 ? nil : managed.longitude
    }
}

// MARK: - Core Data Utilities
extension JournalEntry {
    // Creates a new Core Data object from an Entry struct
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
        // Store 0 for nil coordinates (Core Data doesn't support optionals for primitives)
        managed.latitude = entry.latitude ?? 0
        managed.longitude = entry.longitude ?? 0
    }
    
    // Updates an existing Core Data object with Entry data
    func update(with entry: Entry) {
        self.title = entry.title
        self.content = entry.notes
        self.location = entry.location
        self.date = entry.date
        self.photoData = entry.photoData
        self.editDate = entry.edit
        self.isArchived = entry.isArchived
        // Store 0 for nil coordinates
        self.latitude = entry.latitude ?? 0
        self.longitude = entry.longitude ?? 0
    }
}
