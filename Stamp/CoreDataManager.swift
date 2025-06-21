import Foundation
import CoreData

@objc(JournalEntry)
public class JournalEntry: NSManagedObject {

    @NSManaged public var title: String?
    @NSManaged public var content: String?
    @NSManaged public var date: Date?
    @NSManaged public var isArchived: Bool

}
