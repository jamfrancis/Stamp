//
//  StampApp.swift
//
//  Stamp
//
//  Created by James on 5/26/25.
//
//  This file now contains the app entry and main views only.
//  Entry model and JournalStore class have been moved to Entry.swift.
//

import SwiftUI
import PhotosUI
import Foundation  // For completeness, helps resolve types from Entry.swift
import CoreLocation

// MARK: - App Settings ObservableObject

class AppSettings: ObservableObject {
    @Published var isCardView: Bool {
        didSet {
            UserDefaults.standard.set(isCardView, forKey: "journalCardView")
        }
    }
    init() {
        self.isCardView = UserDefaults.standard.object(forKey: "journalCardView") as? Bool ?? true
    }
}

// MARK: - Geocoding Helper

func geocodeAddress(_ address: String) async -> (Double?, Double?) {
    let geocoder = CLGeocoder()
    do {
        let placemarks = try await geocoder.geocodeAddressString(address)
        if let coordinate = placemarks.first?.location?.coordinate {
            return (coordinate.latitude, coordinate.longitude)
        }
    } catch {}
    return (nil, nil)
}

// MARK: - App Entry Point

@main
struct Stamp: App {
    @StateObject var appSettings = AppSettings()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appSettings)
        }
    }
}

// MARK: - Main Content View

struct ContentView: View {
    @StateObject private var journalStore = JournalStore()
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        if #available(iOS 26.0, *) {
            TabView {
                // Pass appSettings.isCardView to JournalTabView removed; now it reads from environmentObject
                JournalTabView(journalStore: journalStore)
                    .tabItem {
                        Label("Stamps", systemImage: "book.closed")
                    }
                
                MapView(journalEntries: journalStore.entries)
                    .tabItem {
                        Label("Map", systemImage: "map")
                    }
                
                UserView(journalStore: journalStore)
                    .tabItem {
                        Label("User", systemImage: "person.circle")
                    }
                
            }
            .tint(Color("PrimaryColor"))
            .tabBarMinimizeBehavior(.onScrollDown)
            .task {
                await SupabaseManager.shared.syncDelta(journalStore: journalStore)
            }
            .task {
                await backfillMissingCoordinates()
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    Task {
                        await SupabaseManager.shared.syncDelta(journalStore: journalStore)
                    }
                }
            }
        } else {
            TabView {
                // Pass appSettings.isCardView to JournalTabView removed; now it reads from environmentObject
                JournalTabView(journalStore: journalStore)
                    .tabItem {
                        Label("Journal", systemImage: "book.closed")
                    }
                
                MapView(journalEntries: journalStore.entries)
                    .tabItem {
                        Label("Map", systemImage: "map")
                    }
                
                UserView(journalStore: journalStore)
                    .tabItem {
                        Label("User", systemImage: "person.circle")
                    }
            }
            .tint(Color("PrimaryColor"))
            // No .tabBarMinimizeBehavior for earlier iOS versions
            .task {
                await SupabaseManager.shared.syncDelta(journalStore: journalStore)
            }
            .task {
                await backfillMissingCoordinates()
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    Task {
                        await SupabaseManager.shared.syncDelta(journalStore: journalStore)
                    }
                }
            }
        }
    }
    
    func backfillMissingCoordinates() async {
        var updated = false
        for idx in journalStore.entries.indices {
            if journalStore.entries[idx].latitude == nil || journalStore.entries[idx].longitude == nil {
                let (lat, lon) = await geocodeAddress(journalStore.entries[idx].location)
                if let lat = lat, let lon = lon {
                    journalStore.entries[idx].latitude = lat
                    journalStore.entries[idx].longitude = lon
                    updated = true
                }
            }
        }
        if updated {
            journalStore.save()
        }
    }
        
}

// MARK: - Journal Tab View

struct JournalTabView: View {
    @ObservedObject var journalStore: JournalStore
    @State private var showingAddEntry = false
    
    @EnvironmentObject var appSettings: AppSettings

    var body: some View {
        NavigationView {
            VStack {
                // filtered and sorted entries
                let entries = journalStore.entries.filter { !$0.deleted }.sorted(by: { $0.date > $1.date })
                
                if entries.isEmpty {
                    EmptyStateView()
                } else {
                    if appSettings.isCardView {
                        // Card (grid) view
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                                ForEach(entries) { entry in
                                    NavigationLink(destination: EntryDetailView(journalStore: journalStore, entry: entry)) {
                                        // Pass cardMode: true here
                                        JournalEntryRow(entry: entry, cardMode: true)
                                    }
                                }
                            }
                            .padding()
                        }
                    } else {
                        // List view for classic journal entries
                        List {
                            ForEach(entries) { entry in
                                NavigationLink(destination: EntryDetailView(journalStore: journalStore, entry: entry)) {
                                    // Pass cardMode: false here
                                    JournalEntryRow(entry: entry, cardMode: false)
                                }
                            }
                            .onDelete(perform: deleteEntries)
                        }
                        .listStyle(.insetGrouped)
                    }
                }
            }
            .navigationTitle("Stamp")
            .navigationBarTitleDisplayMode(.large)
            
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddEntry = true }) {
                        Image(systemName: "plus")
                            
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { appSettings.isCardView.toggle() }) {
                        Image(systemName: appSettings.isCardView ? "rectangle.grid.2x2" : "list.bullet")
                    }
                    .accessibilityLabel(appSettings.isCardView ? "Switch to list view" : "Switch to card view")
                }
            }
            
            .sheet(isPresented: $showingAddEntry) {
                AddEntryView(journalStore: journalStore)
            }
        }
    }

    func deleteEntries(offsets: IndexSet) {
        let sortedEntries = journalStore.entries.filter { !$0.deleted }.sorted(by: { $0.date > $1.date })
        let idsToDelete = offsets.map { sortedEntries[$0].id }
        for index in journalStore.entries.indices {
            if idsToDelete.contains(journalStore.entries[index].id) {
                journalStore.entries[index].deleted = true
            }
        }
        journalStore.save()
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
                .accessibilityLabel("Closed book icon representing empty journal") // New: Accessibility label.

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

// MARK: - Journal Entry Row View

struct JournalEntryRow: View {
    let entry: Entry
    // New parameter to toggle card vs list UI; default false for backward compatibility
    var cardMode: Bool = false

    var body: some View {
        if cardMode {
            // Card mode with decorative stamp background image behind content
            ZStack {
                // Custom stamp background image (PDF) behind content
                Image("stamp_bg")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 160, height: 80)
                    .clipped()
                    .opacity(0.25)
                    .cornerRadius(8)
                
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
                                    .accessibilityLabel("No photo available") // New: Accessibility label.
                            )
                    }
                    
                    // When in card mode, show only location text next to image
                    Text(entry.location)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 10)
            }
            .cornerRadius(8)
            .padding(.vertical, 4)
            .transition(.move(edge: .bottom).combined(with: .opacity)) // Smooth transition
        } else {
            // List mode (unchanged)
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
                                .accessibilityLabel("No photo available") // New: Accessibility label.
                        )
                }
                
                // entry details text for list mode
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
            .transition(.move(edge: .bottom).combined(with: .opacity)) // New: Smooth transition for row appearance and removal.
        }
    }

}

// MARK: - Entry Detail View

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

// MARK: - Add Entry View

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
                // Title field
                TextField("Title", text: $title)

                // Photo picker and preview
                VStack(alignment: .leading, spacing: 8) {
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

                // Location and date fields
                TextField("Location", text: $location)
                DatePicker("Date", selection: $date, displayedComponents: .date)

                // Notes
                TextField("Write about your experience...", text: $notes, axis: .vertical)
                    .lineLimit(5...10)
            }
            .navigationTitle("New Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color("PrimaryColor"))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            let (lat, lon) = await geocodeAddress(location)
                            let entry = Entry(
                                id: UUID(),
                                title: title,
                                location: location,
                                date: date,
                                notes: notes,
                                photoData: photoData,
                                edit: Date(),
                                deleted: false,
                                latitude: lat,
                                longitude: lon
                            )
                            journalStore.addEntry(entry)
                            await SupabaseManager.shared.syncDelta(journalStore: journalStore)
                            dismiss()
                        }
                    }
                    .disabled(title.isEmpty || location.isEmpty)
                }
            }
            .onChange(of: selectedPhoto) {
                Task {
                    guard let photoItem = selectedPhoto else { return }
                    
                    // Load image data just once
                    if let data = try? await photoItem.loadTransferable(type: Data.self) {
                        photoData = data
                        
                        // Extract metadata directly from data
                        if let source = CGImageSourceCreateWithData(data as CFData, nil),
                           let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
                            
                            // Date extraction
                            if let tiffDict = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any],
                               let dateString = tiffDict[kCGImagePropertyTIFFDateTime] as? String,
                               let metaDate = Self.parseExifDate(from: dateString) {
                                date = metaDate
                            }
                            
                            // GPS extraction
                            if let gps = props[kCGImagePropertyGPSDictionary] as? [CFString: Any],
                               let lat = gps[kCGImagePropertyGPSLatitude] as? Double,
                               let latRef = gps[kCGImagePropertyGPSLatitudeRef] as? String,
                               let lon = gps[kCGImagePropertyGPSLongitude] as? Double,
                               let lonRef = gps[kCGImagePropertyGPSLongitudeRef] as? String {
                                let signedLat = (latRef == "S") ? -lat : lat
                                let signedLon = (lonRef == "W") ? -lon : lon
                                let placemark = await Self.reverseGeocode(latitude: signedLat, longitude: signedLon)
                                if let place = placemark {
                                    location = place
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    static func parseExifDate(from string: String) -> Date? {
        // TIFF/EXIF date: "yyyy:MM:dd HH:mm:ss"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.timeZone = .current
        return formatter.date(from: string)
    }

    static func reverseGeocode(latitude: Double, longitude: Double) async -> String? {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                let parts = [placemark.locality, placemark.administrativeArea, placemark.country].compactMap { $0 }
                return parts.joined(separator: ", ")
            }
        } catch {}
        return nil
    }
}

// MARK: - Edit Entry View

struct EditEntryView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var journalStore: JournalStore
    @Binding var entry: Entry

    @State private var originalLocation: String = ""

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
            .onAppear {
                originalLocation = entry.location
            }
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
                        Task {
                            if entry.location != originalLocation {
                                let (lat, lon) = await geocodeAddress(entry.location)
                                entry.latitude = lat
                                entry.longitude = lon
                            }
                            if let index = journalStore.entries.firstIndex(where: { $0.id == entry.id }) {
                                entry.edit = Date()
                                journalStore.entries[index] = entry
                                journalStore.save()
                                await SupabaseManager.shared.syncDelta(journalStore: journalStore)
                            }
                            dismiss()
                        }
                    }
                    .foregroundColor(Color("PrimaryColor"))
                }
            }
        }
    }
}


// MARK: - Preview

#Preview("ContentView Main") {
    ContentView()
}

