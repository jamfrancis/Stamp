// CoreDataManager.swift
// Handles Core Data setup and convenience methods for the Stamp app.

import Foundation
import CoreData

final class CoreDataManager {
    static let shared = CoreDataManager()
    let container: NSPersistentContainer
    var viewContext: NSManagedObjectContext { container.viewContext }

    private init() {
        container = NSPersistentContainer(name: "StampModel")
        // For simple projects, use in-memory store if desired:
        // let description = NSPersistentStoreDescription()
        // description.type = NSInMemoryStoreType
        // container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { desc, error in
            if let error = error {
                fatalError("Failed to load Core Data: \(error)")
            }
        }
    }
    
    func saveContext() {
        let context = viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Core Data save error: \(error)")
            }
        }
    }
}

// MARK: - JournalEntry Core Data NSManagedObject

@objc(JournalEntry)
class JournalEntry: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var title: String
    @NSManaged var location: String
    @NSManaged var date: Date
    @NSManaged var notes: String
    @NSManaged var photoData: Data?
    @NSManaged var edit: Date
    @NSManaged override var isDeleted: Bool
    @NSManaged var latitude: Double
    @NSManaged var longitude: Double
}

extension JournalEntry {
    static func fetchRequestAll() -> NSFetchRequest<JournalEntry> {
        let request = NSFetchRequest<JournalEntry>(entityName: "JournalEntry")
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        return request
    }
}
