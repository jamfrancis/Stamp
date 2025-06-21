import SwiftUI
import CoreData

struct JournalTabView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \JournalEntry.date, ascending: false)],
        predicate: NSPredicate(format: "isArchived == false"),
        animation: .default)
    private var entries: FetchedResults<JournalEntry>

    @State private var showingAddEntry = false

    var body: some View {
        NavigationView {
            List {
                ForEach(entries) { entry in
                    NavigationLink(destination: EditEntryView(entry: entry)) {
                        VStack(alignment: .leading) {
                            Text(entry.title ?? "Untitled")
                                .font(.headline)
                            Text(entry.date ?? Date(), style: .date)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteEntries)
            }
            .navigationTitle("Journal")
            .navigationBarItems(trailing: Button(action: {
                showingAddEntry.toggle()
            }) {
                Image(systemName: "plus")
            })
            .sheet(isPresented: $showingAddEntry) {
                AddEntryView()
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }

    private func deleteEntries(offsets: IndexSet) {
        withAnimation {
            offsets.map { entries[$0] }.forEach { entry in
                entry.isArchived = true
            }
            do {
                try viewContext.save()
            } catch {
                // Handle the error appropriately in a real app
                print("Failed to archive entry: \(error.localizedDescription)")
            }
        }
    }
}

struct AddEntryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode

    @State private var title: String = ""
    @State private var content: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Title")) {
                    TextField("Entry Title", text: $title)
                }
                Section(header: Text("Text")) {
                    TextEditor(text: $content)
                        .frame(minHeight: 200)
                }
            }
            .navigationBarTitle("New Entry", displayMode: .inline)
            .navigationBarItems(leading: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            }, trailing: Button("Save") {
                addEntry()
                presentationMode.wrappedValue.dismiss()
            }.disabled(title.isEmpty || content.isEmpty))
        }
    }

    private func addEntry() {
        let newEntry = JournalEntry(context: viewContext)
        newEntry.id = UUID()
        newEntry.title = title
        newEntry.content = content
        newEntry.date = Date()
        newEntry.isArchived = false

        do {
            try viewContext.save()
        } catch {
            // Handle the error appropriately in a real app
            print("Failed to save new entry: \(error.localizedDescription)")
        }
    }
}

struct EditEntryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode

    @ObservedObject var entry: JournalEntry

    @State private var title: String = ""
    @State private var content: String = ""

    var body: some View {
        Form {
            Section(header: Text("Title")) {
                TextField("Entry Title", text: $title)
            }
            Section(header: Text("Text")) {
                TextEditor(text: $content)
                    .frame(minHeight: 200)
            }
        }
        .navigationBarTitle("Edit Entry", displayMode: .inline)
        .navigationBarItems(trailing: Button("Save") {
            saveEntry()
            presentationMode.wrappedValue.dismiss()
        }.disabled(title.isEmpty || content.isEmpty))
        .onAppear {
            title = entry.title ?? ""
            content = entry.content ?? ""
        }
    }

    private func saveEntry() {
        entry.title = title
        entry.content = content
        entry.date = Date()
        // Preserve isArchived status during editing
        // No changes to isArchived here unless explicitly archived/unarchived

        do {
            try viewContext.save()
        } catch {
            // Handle the error appropriately in a real app
            print("Failed to save edited entry: \(error.localizedDescription)")
        }
    }
}

// Sync logic example, updating field name from isDeleted to isArchived and Entry to JournalEntry
class SyncManager {
    let viewContext: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.viewContext = context
    }

    func syncEntriesFromServer(_ serverEntries: [ServerEntry]) {
        let fetchRequest: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()

        do {
            let localEntries = try viewContext.fetch(fetchRequest)
            for serverEntry in serverEntries {
                if let localEntry = localEntries.first(where: { $0.id == serverEntry.id }) {
                    // Update existing entry
                    localEntry.title = serverEntry.title
                    localEntry.content = serverEntry.text
                    localEntry.date = serverEntry.date
                    localEntry.isArchived = serverEntry.isArchived
                } else {
                    // Insert new entry
                    let newEntry = JournalEntry(context: viewContext)
                    newEntry.id = serverEntry.id
                    newEntry.title = serverEntry.title
                    newEntry.content = serverEntry.text
                    newEntry.date = serverEntry.date
                    newEntry.isArchived = serverEntry.isArchived
                }
            }
            try viewContext.save()
        } catch {
            print("Failed to sync entries: \(error.localizedDescription)")
        }
    }
}

// ServerEntry model example
struct ServerEntry {
    let id: UUID
    let title: String
    let text: String
    let date: Date
    let isArchived: Bool
}
