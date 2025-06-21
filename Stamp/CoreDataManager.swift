import Foundation
import CoreData

@objc(JournalEntry)
public class JournalEntry: NSManagedObject, Identifiable {

    @NSManaged public var id: UUID
    @NSManaged public var title: String?
    @NSManaged public var content: String?
    @NSManaged public var location: String?
    @NSManaged public var date: Date?
    @NSManaged public var photoData: Data?
    @NSManaged public var editDate: Date?
    @NSManaged public var isArchived: Bool
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double

}
