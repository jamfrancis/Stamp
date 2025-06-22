import SwiftUI
import CoreData
import PhotosUI
import CoreLocation

// Main app entry point
@main
struct StampApp: App {
    let persistentContainer = CoreDataManager.shared
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(\.managedObjectContext, persistentContainer.viewContext)
                .onAppear {
                    // Trigger sync when app launches to get latest data
                    Supabase.shared.syncInBackground()
                }
        }
    }
}

// Main tab view containing stamps list and map tabs
struct MainTabView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        TabView {
            // Primary tab showing list of stamps
            StampsTabView()
                .tabItem {
                    Label("Stamps", systemImage: "inset.filled.square.dashed")
                }
            
            // Map tab showing stamp locations
            MapTabView()
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }
        }
    }
}

// Main stamps list view with navigation and sync controls
struct StampsTabView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var supabase = Supabase.shared

    // Fetch non-archived stamps, sorted by date (newest first)
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \JournalEntry.date, ascending: false)],
        predicate: NSPredicate(format: "isArchived == false"),
        animation: .default)
    private var entries: FetchedResults<JournalEntry>

    // State variables for sheet presentations
    @State private var showingAddEntry = false
    @State private var showingProfile = false
    @State private var showingDisplayView = false
    @State private var selectedEntry: JournalEntry?

    var body: some View {
        NavigationStack {
            List {
                ForEach(entries) { entry in
                    HStack(spacing: 12) {
                        // Display photo thumbnail or placeholder
                        if let photoData = entry.photoData, let uiImage = UIImage(data: photoData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            // Placeholder when no photo is available
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray5))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.secondary)
                                )
                        }
                        
                        // Stamp information text
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.title ?? "Untitled")
                                .font(.headline)
                                .lineLimit(1)
                            
                            if let location = entry.location, !location.isEmpty {
                                Text(location)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Text(entry.date ?? Date(), style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Tap to view stamp in DisplayView
                        selectedEntry = entry
                        showingDisplayView = true
                    }
                    .swipeActions(edge: .leading) {
                        // Swipe to edit stamp
                        NavigationLink(destination: EditEntryView(entry: entry)) {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
                .onDelete(perform: deleteEntries)
            }
            .navigationTitle("Stamps")
            .navigationBarItems(
                leading: HStack {
                    Button(action: {
                        showingProfile.toggle()
                    }) {
                        Image(systemName: "person.circle")
                    }
                    
                    // Sync status indicator
                    syncStatusView
                },
                trailing: Button(action: {
                    showingAddEntry.toggle()
                }) {
                    Image(systemName: "plus")
                }
            )
            .sheet(isPresented: $showingAddEntry) {
                AddEntryView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(isPresented: $showingProfile) {
                UserProfileView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(isPresented: $showingDisplayView) {
                if let selectedEntry = selectedEntry {
                    DisplayView(entry: selectedEntry)
                }
            }
        }
    }
    
    @ViewBuilder
    private var syncStatusView: some View {
        switch supabase.syncStatus {
        case .idle:
            if supabase.hasPendingChanges {
                Image(systemName: "cloud.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
            }
        case .syncing:
            ProgressView()
                .scaleEffect(0.7)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(.caption)
        }
    }

    private func deleteEntries(offsets: IndexSet) {
        withAnimation {
            let entriesToArchive = offsets.map { entries[$0] }
            entriesToArchive.forEach { entry in
                entry.isArchived = true
                entry.editDate = Date() // Update editDate so updated_at reflects archival time
                // Mark for sync
                Supabase.shared.markForSync(entry.id)
            }
            do {
                try viewContext.save()
                // Sync after successful archive
                Supabase.shared.syncInBackground()
            } catch {
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
    @State private var location: String = ""
    @State private var date = Date()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var extractedLatitude: Double?
    @State private var extractedLongitude: Double?

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Title")) {
                    TextField("Stamp Title", text: $title)
                }
                
                Section(header: Text("Photo")) {
                    PhotosPicker("Select Photo", selection: $selectedPhoto, matching: .images)
                    
                    if let photoData = photoData, let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                    }
                }
                
                Section(header: Text("Location")) {
                    TextField("Enter location", text: $location)
                }
                
                Section(header: Text("Date")) {
                    DatePicker("Stamp Date", selection: $date, displayedComponents: [.date])
                }
                
                Section(header: Text("Notes")) {
                    TextEditor(text: $content)
                        .frame(minHeight: 200)
                }
            }
            .navigationBarTitle("New Stamp", displayMode: .inline)
            .navigationBarItems(leading: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            }, trailing: Button("Save") {
                addEntry()
                presentationMode.wrappedValue.dismiss()
            }.disabled(title.isEmpty || content.isEmpty))
            .onChange(of: selectedPhoto) { _ in
                Task {
                    if let data = try? await selectedPhoto?.loadTransferable(type: Data.self) {
                        photoData = data
                        await extractPhotoMetadata(from: data)
                    }
                }
            }
        }
    }

    private func addEntry() {
        let newEntry = JournalEntry(context: viewContext)
        newEntry.id = UUID()
        newEntry.title = title
        newEntry.content = content
        newEntry.location = location
        newEntry.date = date
        newEntry.editDate = Date()
        newEntry.photoData = photoData
        newEntry.isArchived = false
        newEntry.latitude = extractedLatitude ?? 0
        newEntry.longitude = extractedLongitude ?? 0

        do {
            try viewContext.save()
            // Mark for sync after successful save
            Supabase.shared.markForSync(newEntry.id)
            Supabase.shared.syncInBackground()
        } catch {
            print("Failed to save new entry: \(error.localizedDescription)")
        }
    }
    
    private func extractPhotoMetadata(from imageData: Data) async {
        guard let image = UIImage(data: imageData),
              let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil),
              let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            return
        }
        
        // Extract GPS data
        if let gpsInfo = imageProperties[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
            if let latitude = gpsInfo[kCGImagePropertyGPSLatitude as String] as? Double,
               let latitudeRef = gpsInfo[kCGImagePropertyGPSLatitudeRef as String] as? String,
               let longitude = gpsInfo[kCGImagePropertyGPSLongitude as String] as? Double,
               let longitudeRef = gpsInfo[kCGImagePropertyGPSLongitudeRef as String] as? String {
                
                let finalLatitude = latitudeRef == "S" ? -latitude : latitude
                let finalLongitude = longitudeRef == "W" ? -longitude : longitude
                
                await MainActor.run {
                    extractedLatitude = finalLatitude
                    extractedLongitude = finalLongitude
                }
                
                // Reverse geocode to get location name
                let geocoder = CLGeocoder()
                let coordinate = CLLocation(latitude: finalLatitude, longitude: finalLongitude)
                
                do {
                    let placemarks = try await geocoder.reverseGeocodeLocation(coordinate)
                    if let placemark = placemarks.first {
                        let locationName = [
                            placemark.name,
                            placemark.locality,
                            placemark.administrativeArea,
                            placemark.country
                        ].compactMap { $0 }.joined(separator: ", ")
                        
                        await MainActor.run {
                            if location.isEmpty {
                                location = locationName
                            }
                        }
                    }
                } catch {
                    print("Reverse geocoding failed: \(error)")
                }
            }
        }
        
        // Extract date
        if let exifInfo = imageProperties[kCGImagePropertyExifDictionary as String] as? [String: Any],
           let dateString = exifInfo[kCGImagePropertyExifDateTimeOriginal as String] as? String {
            
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
            
            if let extractedDate = formatter.date(from: dateString) {
                await MainActor.run {
                    date = extractedDate
                }
            }
        }
    }
}

struct EditEntryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode

    @ObservedObject var entry: JournalEntry

    @State private var title: String = ""
    @State private var content: String = ""
    @State private var location: String = ""
    @State private var date = Date()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var extractedLatitude: Double?
    @State private var extractedLongitude: Double?

    var body: some View {
        Form {
            Section(header: Text("Title")) {
                TextField("Stamp Title", text: $title)
            }
            
            Section(header: Text("Photo")) {
                PhotosPicker("Select Photo", selection: $selectedPhoto, matching: .images)
                
                if let photoData = photoData, let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                }
            }
            
            Section(header: Text("Location")) {
                TextField("Enter location", text: $location)
            }
            
            Section(header: Text("Date")) {
                DatePicker("Stamp Date", selection: $date, displayedComponents: [.date])
            }
            
            Section(header: Text("Notes")) {
                TextEditor(text: $content)
                    .frame(minHeight: 200)
            }
        }
        .navigationBarTitle("Edit Stamp", displayMode: .inline)
        .navigationBarItems(trailing: Button("Save") {
            saveEntry()
            presentationMode.wrappedValue.dismiss()
        }.disabled(title.isEmpty || content.isEmpty))
        .onAppear {
            title = entry.title ?? ""
            content = entry.content ?? ""
            location = entry.location ?? ""
            date = entry.date ?? Date()
            photoData = entry.photoData
            extractedLatitude = entry.latitude != 0 ? entry.latitude : nil
            extractedLongitude = entry.longitude != 0 ? entry.longitude : nil
        }
        .onChange(of: selectedPhoto) { _ in
            Task {
                if let data = try? await selectedPhoto?.loadTransferable(type: Data.self) {
                    photoData = data
                    await extractPhotoMetadata(from: data)
                }
            }
        }
    }

    private func saveEntry() {
        entry.title = title
        entry.content = content
        entry.location = location
        entry.date = date
        entry.photoData = photoData
        entry.editDate = Date()
        entry.latitude = extractedLatitude ?? entry.latitude
        entry.longitude = extractedLongitude ?? entry.longitude

        do {
            try viewContext.save()
            // Mark for sync after successful save
            Supabase.shared.markForSync(entry.id)
            Supabase.shared.syncInBackground()
        } catch {
            print("Failed to save edited entry: \(error.localizedDescription)")
        }
    }
    
    private func extractPhotoMetadata(from imageData: Data) async {
        guard let image = UIImage(data: imageData),
              let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil),
              let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            return
        }
        
        // Extract GPS data
        if let gpsInfo = imageProperties[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
            if let latitude = gpsInfo[kCGImagePropertyGPSLatitude as String] as? Double,
               let latitudeRef = gpsInfo[kCGImagePropertyGPSLatitudeRef as String] as? String,
               let longitude = gpsInfo[kCGImagePropertyGPSLongitude as String] as? Double,
               let longitudeRef = gpsInfo[kCGImagePropertyGPSLongitudeRef as String] as? String {
                
                let finalLatitude = latitudeRef == "S" ? -latitude : latitude
                let finalLongitude = longitudeRef == "W" ? -longitude : longitude
                
                await MainActor.run {
                    extractedLatitude = finalLatitude
                    extractedLongitude = finalLongitude
                }
                
                // Reverse geocode to get location name
                let geocoder = CLGeocoder()
                let coordinate = CLLocation(latitude: finalLatitude, longitude: finalLongitude)
                
                do {
                    let placemarks = try await geocoder.reverseGeocodeLocation(coordinate)
                    if let placemark = placemarks.first {
                        let locationName = [
                            placemark.name,
                            placemark.locality,
                            placemark.administrativeArea,
                            placemark.country
                        ].compactMap { $0 }.joined(separator: ", ")
                        
                        await MainActor.run {
                            if location.isEmpty {
                                location = locationName
                            }
                        }
                    }
                } catch {
                    print("Reverse geocoding failed: \(error)")
                }
            }
        }
        
        // Extract date
        if let exifInfo = imageProperties[kCGImagePropertyExifDictionary as String] as? [String: Any],
           let dateString = exifInfo[kCGImagePropertyExifDateTimeOriginal as String] as? String {
            
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
            
            if let extractedDate = formatter.date(from: dateString) {
                await MainActor.run {
                    date = extractedDate
                }
            }
        }
    }
}

// MARK: - Display View
// Full-screen view for displaying a stamp with large photo and details
struct DisplayView: View {
    @Environment(\.presentationMode) var presentationMode
    let entry: JournalEntry
    @State private var showingEditView = false
    @State private var isFavorite = false
    @State private var isLoadingFavorite = true
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .center, spacing: 20) {
                    // Title
                    Text(entry.title ?? "Untitled")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Photo
                    if let photoData = entry.photoData, let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 400)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(radius: 8)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray5))
                            .frame(height: 200)
                            .overlay(
                                VStack {
                                    Image(systemName: "photo")
                                        .font(.system(size: 50))
                                        .foregroundColor(.secondary)
                                    Text("No Photo")
                                        .foregroundColor(.secondary)
                                }
                            )
                    }
                    
                    // Information
                    VStack(alignment: .leading, spacing: 16) {
                        if let location = entry.location, !location.isEmpty {
                            InfoRow(icon: "location.fill", title: "Location", content: location)
                        }
                        
                        if let date = entry.date {
                            InfoRow(icon: "calendar", title: "Date", content: DateFormatter.displayFormatter.string(from: date))
                        }
                        
                        if let content = entry.content, !content.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "text.alignleft")
                                        .foregroundColor(.blue)
                                        .frame(width: 20)
                                    Text("Notes")
                                        .font(.headline)
                                    Spacer()
                                }
                                
                                Text(content)
                                    .font(.body)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        
                        if let editDate = entry.editDate {
                            InfoRow(icon: "clock", title: "Last Updated", content: DateFormatter.displayFormatter.string(from: editDate))
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 50)
                }
                .padding(.vertical)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button(action: {
                    Task {
                        do {
                            let newFavoriteStatus = try await Supabase.shared.toggleFavorite(stampId: entry.id)
                            await MainActor.run {
                                isFavorite = newFavoriteStatus
                            }
                        } catch {
                            print("Failed to toggle favorite: \(error)")
                        }
                    }
                }) {
                    if isLoadingFavorite {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .foregroundColor(isFavorite ? .yellow : .gray)
                            .font(.title2)
                    }
                }
            )
            .sheet(isPresented: $showingEditView) {
                EditEntryView(entry: entry)
                    .environment(\.managedObjectContext, CoreDataManager.shared.viewContext)
            }
            .onAppear {
                Task {
                    do {
                        let favoriteStatus = try await Supabase.shared.getFavoriteStatus(stampId: entry.id)
                        await MainActor.run {
                            isFavorite = favoriteStatus
                            isLoadingFavorite = false
                        }
                    } catch {
                        await MainActor.run {
                            isLoadingFavorite = false
                        }
                        print("Failed to load favorite status: \(error)")
                    }
                }
            }
        }
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let content: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(content)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

extension DateFormatter {
    static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()
}

// Sync logic example, updating field name from isDeleted to isArchived and Entry to JournalEntry
class SyncManager {
    let viewContext: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.viewContext = context
    }

    func syncEntriesFromServer(_ serverEntries: [ServerEntry]) {
        let fetchRequest = NSFetchRequest<JournalEntry>(entityName: "JournalEntry")

        do {
            let localEntries = try viewContext.fetch(fetchRequest)
            for serverEntry in serverEntries {
                if let localEntry = localEntries.first(where: { $0.id == serverEntry.id }) {
                    // Update existing entry
                    localEntry.title = serverEntry.title
                    localEntry.content = serverEntry.content
                    localEntry.location = serverEntry.location
                    localEntry.date = serverEntry.date
                    localEntry.photoData = serverEntry.photoData
                    localEntry.editDate = serverEntry.editDate
                    localEntry.isArchived = serverEntry.isArchived
                    localEntry.latitude = serverEntry.latitude ?? 0
                    localEntry.longitude = serverEntry.longitude ?? 0
                } else {
                    // Insert new entry
                    let newEntry = JournalEntry(context: viewContext)
                    newEntry.id = serverEntry.id
                    newEntry.title = serverEntry.title
                    newEntry.content = serverEntry.content
                    newEntry.location = serverEntry.location
                    newEntry.date = serverEntry.date
                    newEntry.photoData = serverEntry.photoData
                    newEntry.editDate = serverEntry.editDate
                    newEntry.isArchived = serverEntry.isArchived
                    newEntry.latitude = serverEntry.latitude ?? 0
                    newEntry.longitude = serverEntry.longitude ?? 0
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
    let content: String
    let location: String
    let date: Date
    let photoData: Data?
    let editDate: Date
    let isArchived: Bool
    let latitude: Double?
    let longitude: Double?
}

// MARK: - Map Tab View
struct MapTabView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \JournalEntry.date, ascending: false)],
        predicate: NSPredicate(format: "isArchived == false AND latitude != 0 AND longitude != 0"),
        animation: .default)
    private var entriesWithLocations: FetchedResults<JournalEntry>
    
    var body: some View {
        NavigationStack {
            JournalMapView(journalEntries: Array(entriesWithLocations))
                .navigationTitle("Map")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}
