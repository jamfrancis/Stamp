import Foundation

struct Note {
    var content: String
    var isArchived: Bool // Changed from isDeleted to isArchived to represent archived notes instead of deleted ones
}

class NotesManager {
    private var notes: [Note] = []
    
    func addNote(_ content: String) {
        let note = Note(content: content, isArchived: false)
        notes.append(note)
    }
    
    func archiveNote(at index: Int) {
        guard notes.indices.contains(index) else { return }
        notes[index].isArchived = true // Updated from isDeleted to isArchived
    }
    
    func activeNotes() -> [Note] {
        // Return notes that are not archived (previously not deleted)
        return notes.filter { !$0.isArchived }
    }
    
    func archivedNotes() -> [Note] {
        // Return notes that are archived (previously deleted)
        return notes.filter { $0.isArchived }
    }
    
    func countActiveNotes() -> Int {
        // Count of notes that are not archived
        return notes.filter { !$0.isArchived }.count
    }
    
    func countArchivedNotes() -> Int {
        // Count of notes that are archived
        return notes.filter { $0.isArchived }.count
    }
}
