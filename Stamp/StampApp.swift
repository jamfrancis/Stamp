//
//  StampApp.swift

//  Stamp
//
//  Created by James on 5/26/25.
//

import SwiftUI
import PhotosUI

// main app entry point
@main
struct Stamp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// main content view
struct ContentView: View {
@StateObject private var journalStore = JournalStore()
@State private var showingAddEntry = false

var body: some View {
    NavigationView {
        VStack {
            // show empty state or list of entries
            if journalStore.entries.isEmpty {
                EmptyStateView()
            } else {
                List {
                    // entry list
                    ForEach(journalStore.entries.sorted(by: { $0.date > $1.date })) { entry in
                        NavigationLink(destination: EntryDetailView(journalStore: journalStore, entry: entry)) {
                            JournalEntryRow(entry: entry)
                        }
                    }
                    .onDelete(perform: deleteEntries)
                }
            }
        }
        .navigationTitle("Stamp")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            // add button in navigation bar
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddEntry = true }) {
                    Image(systemName: "plus")
                        .foregroundColor(Color("PrimaryColor"))
                }
            }
        }
        .sheet(isPresented: $showingAddEntry) {
            AddEntryView(journalStore: journalStore)
        }
    }
    .tint(Color("PrimaryColor"))
}

func deleteEntries(offsets: IndexSet) {
    let sortedEntries = journalStore.entries.sorted(by: { $0.date > $1.date })
    let idsToDelete = offsets.map { sortedEntries[$0].id }
    journalStore.entries.removeAll { entry in idsToDelete.contains(entry.id) }
    journalStore.save()
    }

}

// observable store for journal entries
class JournalStore: ObservableObject {
@Published var entries: [Entry] = []

private let saveKey = "TravelJournalEntries"

init() {
    load()
}

func addEntry(_ entry: Entry) {
    entries.insert(entry, at: 0) // Add to beginning for newest first
    save()
}

func save() {
    if let encoded = try? JSONEncoder().encode(entries) {
        UserDefaults.standard.set(encoded, forKey: saveKey)
    }
}

func load() {
    if let data = UserDefaults.standard.data(forKey: saveKey),
       let decoded = try? JSONDecoder().decode([Entry].self, from: data) {
        entries = decoded
        }
    }

}

// view shown when no entries exist
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Entries Yet")
                .font(.title2)
                .fontWeight(.semibold)
        
            Text("Start documenting your travels by adding your first entry")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
            .padding()
    }

}

// row for each journal entry in list
struct JournalEntryRow: View {
let entry: Entry

var body: some View {
    HStack(spacing: 12) {
        // photo display or placeholder
        if let photoData = entry.photoData,
           let uiImage = UIImage(data: photoData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "photo")
                        .foregroundColor(.gray)
                )
        }
        
        // entry details text
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.title)
                .font(.headline)
                .lineLimit(1)
            
            HStack {
                Image(systemName: "location")
                    .foregroundColor(.secondary)
                    .font(.caption)
                Text(entry.location)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Text(entry.formattedDate)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if !entry.notes.isEmpty {
                Text(entry.notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        
        Spacer()
    }
    .padding(.vertical, 4)
}

}

// detail view for a single entry
struct EntryDetailView: View {
@State private var showingEditView = false
@ObservedObject var journalStore: JournalStore
let entry: Entry

var body: some View {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            // photo display
            if let photoData = entry.photoData,
               let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 4)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                // location and date info
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.red)
                    Text(entry.location)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                    Text(entry.formattedDate)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // notes section
                if !entry.notes.isEmpty {
                    Divider()
                    
                    Text("Notes")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(entry.notes)
                        .font(.body)
                        .lineSpacing(4)
                }
            }
            
            Spacer()
        }
        .padding()
    }
    .navigationTitle(entry.title)
    .navigationBarTitleDisplayMode(.large)
    .toolbar {
        // edit button in nav bar
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("Edit") {
                showingEditView = true
            }
            .foregroundColor(Color("PrimaryColor"))
        }
    }
    .sheet(isPresented: $showingEditView) {
        if let index = journalStore.entries.firstIndex(where: { $0.id == entry.id }) {
            EditEntryView(journalStore: journalStore, entry: $journalStore.entries[index])
        }
    }
}

}

// view for adding a new entry
struct AddEntryView: View {
    @ObservedObject var journalStore: JournalStore
    @Environment(\.dismiss) private var dismiss

@State private var title = ""
@State private var location = ""
@State private var date = Date()
@State private var notes = ""
@State private var selectedPhoto: PhotosPickerItem?
@State private var photoData: Data?

var body: some View {
    NavigationView {
        Form {
            // entry details form fields
            Section("Entry Details") {
                TextField("Title", text: $title)
                
                TextField("Location", text: $location)
                
                DatePicker("Date", selection: $date, displayedComponents: .date)
            }
            
            // photo selection section
            Section("Photo") {
                if let photoData = photoData,
                   let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("Add Photo", systemImage: "camera")
                        .foregroundColor(Color("PrimaryColor"))
                }
            }
            
            // notes input
            Section("Notes") {
                TextField("Write about your experience...", text: $notes, axis: .vertical)
                    .lineLimit(5...10)
            }
        }
        .navigationTitle("New Entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // cancel and save buttons in nav bar
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(Color("PrimaryColor"))
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveEntry()
                }
                .disabled(title.isEmpty || location.isEmpty)
            }
        }
        .onChange(of: selectedPhoto) { newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    photoData = data
                }
            }
        }
    }
}

private func saveEntry() {
    let entry = Entry(
        title: title,
        location: location,
        date: date,
        notes: notes,
        photoData: photoData
    )
    
    journalStore.addEntry(entry)
    dismiss()
}

}

// view for editing an existing entry
struct EditEntryView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var journalStore: JournalStore
    @Binding var entry: Entry

    var body: some View {
        NavigationView {
            Form {
                // edit entry form fields
                Section("Edit Entry") {
                    TextField("Title", text: $entry.title)
                    TextField("Location", text: $entry.location)
                    DatePicker("Date", selection: $entry.date, displayedComponents: .date)
                    TextField("Notes", text: $entry.notes, axis: .vertical)
                        .lineLimit(5...10)
                }
            }
            .navigationTitle("Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // cancel and save buttons
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color("PrimaryColor"))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if let index = journalStore.entries.firstIndex(where: { $0.id == entry.id }) {
                            journalStore.entries[index] = entry
                            journalStore.save()
                        }
                        dismiss()
                    }
                    .foregroundColor(Color("PrimaryColor"))
                }
            }
        }
    }
}

// model for each journal entry
struct Entry: Identifiable, Codable {
let id = UUID()
var title: String
var location: String
var date: Date
var notes: String
var photoData: Data?

var formattedDate: String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    return formatter.string(from: date)
    }

}

// preview provider
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
