// ArcGISImplementation.swift
// complete arcgis implementation with professional cartography

import SwiftUI
import ArcGIS

// main arcgis view
struct ArcGISView: View {
    let journalEntries: [JournalEntry]
    @Binding var selectedEntry: JournalEntry?
    @StateObject private var viewModel = MapViewModel()
    @Binding var showPastMonthOnly: Bool
    var onStampTap: ((JournalEntry) -> Void)? = nil
    
    var body: some View {
        if ArcGISChecker.isAvailable {
            VStack(spacing: 0) {
                // arcgis header
                HStack {
                    VStack(alignment: .leading) {
                        Text("ArcGIS Maps")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("Professional cartography")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                    Spacer()
                    Image(systemName: "globe.americas.fill")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color(.systemGray6))
                
                // arcgis map
                ArcGISMapImplementation(
                    journalEntries: journalEntries,
                    viewModel: viewModel,
                    showPastMonthOnly: $showPastMonthOnly,
                    onStampTap: onStampTap
                )
            }
            .onChange(of: viewModel.selectedEntry) { newValue in
                selectedEntry = newValue
            }
            .onChange(of: selectedEntry) { newValue in
                if viewModel.selectedEntry?.id != newValue?.id {
                    viewModel.selectEntry(newValue)
                }
            }
        } else {
            // fallback when arcgis unavailable
            VStack {
                Text("ArcGIS Unavailable")
                    .font(.title2)
                    .foregroundColor(.orange)
                    .padding()
                
                Text("ArcGIS SDK not available")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                Spacer()
            }
            .background(Color(.systemGray6))
        }
    }
}

// core arcgis map implementation
struct ArcGISMapImplementation: View {
    let journalEntries: [JournalEntry]
    let viewModel: MapViewModel
    @Binding var showPastMonthOnly: Bool
    var onStampTap: ((JournalEntry) -> Void)? = nil
    
    @State private var map: Map = Map(basemapStyle: .arcGISTopographic)
    @State private var graphicsOverlay = GraphicsOverlay()
    @State private var stampMarkers: [ArcGISStampMarker] = []
    
    // filter entries by date if needed
    private var filteredEntries: [JournalEntry] {
        if showPastMonthOnly {
            let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
            return journalEntries.filter { entry in
                guard let date = entry.date else { return false }
                return date >= oneMonthAgo
            }
        }
        return journalEntries
    }
    
    var body: some View {
        ZStack {
            Color(.systemGray6)
            
            MapView(map: map, graphicsOverlays: [graphicsOverlay])
                .onSingleTapGesture { screenPoint, mapPoint in
                    handleMapTap(at: mapPoint)
                }
                .task {
                    await setupMap()
                }
                .task(id: filteredEntries.count) {
                    await updateMarkers()
                }
            
            // bottom sheet popup
            if let selected = viewModel.selectedEntry {
                ArcGISPopup(entry: selected, onTapForFullView: {
                    onStampTap?(selected)
                }) {
                    viewModel.clearSelection()
                }
                .allowsHitTesting(true)
                .zIndex(1000)
            }
        }
    }
    
    // setup arcgis map
    @MainActor
    private func setupMap() async {
        // api key for basemap
        ArcGISEnvironment.apiKey = APIKey("AAPTxy8BH1VEsoebNVZXo8HurLP1FjHUkozMRki8vXlhPBpMnz5Xf4LKL4FpI2k5UBNOi4Xek-hD6gPKIxS3l83LesNVs-CdRPWRmNkT8dp-XixmDzlLIjk7wGvpMC2u9NYo2OeS2rsfQGL9Kd9DHnSGrmiHGE2DCxBR1z7YPeKUApHj4zLQxsPE3V1K1RYanCATET3BumHlwTt-bPvIuX9kGtgDIWsBqSSs5CVzvs4AbPA.AT1_blv5QODE")
        
        map = Map(basemapStyle: .arcGISTopographic)
        map.initialViewpoint = calculateViewpoint()
        
        await updateMarkers()
    }
    
    // update stamp markers
    @MainActor
    private func updateMarkers() async {
        graphicsOverlay.removeAllGraphics()
        stampMarkers.removeAll()
        
        var graphics: [Graphic] = []
        
        for entry in filteredEntries {
            guard entry.latitude != 0 && entry.longitude != 0 else { continue }
            
            let point = Point(x: entry.longitude, y: entry.latitude, spatialReference: .wgs84)
            let symbol = createSymbol(for: entry)
            let graphic = Graphic(geometry: point, symbol: symbol)
            graphics.append(graphic)
            
            stampMarkers.append(ArcGISStampMarker(
                id: entry.id,
                point: point,
                symbol: symbol,
                journalEntry: entry
            ))
        }
        
        graphicsOverlay.addGraphics(graphics)
    }
    
    // handle map tap
    private func handleMapTap(at mapPoint: Point) {
        var closestEntry: JournalEntry?
        var minDistance: Double = Double.infinity
        let tapTolerance: Double = 0.015
        
        for marker in stampMarkers {
            let deltaX = mapPoint.x - marker.point.x
            let deltaY = mapPoint.y - marker.point.y
            let distance = sqrt(deltaX * deltaX + deltaY * deltaY)
            
            if distance < tapTolerance && distance < minDistance {
                minDistance = distance
                closestEntry = marker.journalEntry
            }
        }
        
        // update selection on main thread
        DispatchQueue.main.async {
            if let entry = closestEntry {
                if self.viewModel.selectedEntry?.id == entry.id {
                    self.viewModel.clearSelection()
                } else {
                    self.viewModel.selectEntry(entry)
                }
            } else {
                self.viewModel.clearSelection()
            }
        }
    }
    
    // calculate initial viewpoint
    private func calculateViewpoint() -> Viewpoint {
        if !filteredEntries.isEmpty {
            let validEntries = filteredEntries.filter { $0.latitude != 0 && $0.longitude != 0 }
            if !validEntries.isEmpty {
                let avgLat = validEntries.map { $0.latitude }.reduce(0, +) / Double(validEntries.count)
                let avgLon = validEntries.map { $0.longitude }.reduce(0, +) / Double(validEntries.count)
                return Viewpoint(
                    center: Point(x: avgLon, y: avgLat, spatialReference: .wgs84),
                    scale: 2000000
                )
            }
        }
        
        // default to us view
        return Viewpoint(
            center: Point(x: -98.5795, y: 39.8283, spatialReference: .wgs84),
            scale: 15000000
        )
    }
    
    // create symbol for entry
    private func createSymbol(for entry: JournalEntry) -> Symbol {
        if let photoData = entry.photoData, let originalImage = UIImage(data: photoData) {
            let pinImage = createPinImage(from: originalImage)
            let pictureSymbol = PictureMarkerSymbol(image: pinImage)
            pictureSymbol.width = 50.0
            pictureSymbol.height = 65.0
            pictureSymbol.offsetY = 32.5
            return pictureSymbol
        } else {
            // fallback symbol
            let simpleSymbol = SimpleMarkerSymbol(
                style: .circle,
                color: .systemOrange,
                size: 24.0
            )
            simpleSymbol.outline = SimpleLineSymbol(
                style: .solid,
                color: .white,
                width: 3.0
            )
            return simpleSymbol
        }
    }
    
    // create pin image
    private func createPinImage(from originalImage: UIImage) -> UIImage {
        let croppedImage = cropImageToSquare(originalImage)
        let pinSize = CGSize(width: 50, height: 65)
        let imageSize = CGSize(width: 36, height: 36)
        
        let renderer = UIGraphicsImageRenderer(size: pinSize)
        return renderer.image { context in
            let cgContext = context.cgContext
            
            let centerX = pinSize.width / 2
            let imageY: CGFloat = 8
            let imageRect = CGRect(
                x: (pinSize.width - imageSize.width) / 2,
                y: imageY,
                width: imageSize.width,
                height: imageSize.height
            )
            
            // photo background
            let photoPath = UIBezierPath(roundedRect: imageRect, cornerRadius: 8)
            
            // pin tip
            let tipPath = UIBezierPath()
            tipPath.move(to: CGPoint(x: centerX - 8, y: imageRect.maxY + 4))
            tipPath.addLine(to: CGPoint(x: centerX, y: pinSize.height - 4))
            tipPath.addLine(to: CGPoint(x: centerX + 8, y: imageRect.maxY + 4))
            tipPath.close()
            
            // shadow
            cgContext.setShadow(
                offset: CGSize(width: 1, height: 2),
                blur: 4,
                color: UIColor.black.withAlphaComponent(0.3).cgColor
            )
            
            // white background
            UIColor.white.setFill()
            photoPath.fill()
            
            // draw photo
            cgContext.saveGState()
            photoPath.addClip()
            croppedImage.draw(in: imageRect)
            cgContext.restoreGState()
            
            // pin tip
            UIColor.white.setFill()
            tipPath.fill()
            
            // border
            UIColor.systemGray4.setStroke()
            photoPath.lineWidth = 1
            photoPath.stroke()
        }
    }
    
    // crop image to square
    private func cropImageToSquare(_ image: UIImage) -> UIImage {
        let size = min(image.size.width, image.size.height)
        let origin = CGPoint(
            x: (image.size.width - size) / 2,
            y: (image.size.height - size) / 2
        )
        
        guard let cgImage = image.cgImage?.cropping(to: CGRect(
            x: origin.x * image.scale,
            y: origin.y * image.scale,
            width: size * image.scale,
            height: size * image.scale
        )) else {
            return image
        }
        
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}

// arcgis stamp marker
struct ArcGISStampMarker {
    let id: UUID
    let point: Point
    let symbol: Symbol
    let journalEntry: JournalEntry
}

// arcgis availability checker
struct ArcGISChecker {
    static var isAvailable: Bool {
        #if canImport(ArcGIS)
        return true
        #else
        return false
        #endif
    }
}

// bottom sheet popup for arcgis
struct ArcGISPopup: View {
    let entry: JournalEntry
    let onTapForFullView: () -> Void
    let onDismiss: () -> Void
    @State private var showSheet = false
    
    var body: some View {
        ZStack {
            // background overlay
            Color.black.opacity(showSheet ? 0.3 : 0.0)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.2), value: showSheet)
                .onTapGesture {
                    showSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onDismiss()
                    }
                }
            
            VStack {
                Spacer()
                
                // bottom sheet content
                VStack(alignment: .leading, spacing: 16) {
                    // handle bar
                    HStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(.systemGray4))
                            .frame(width: 40, height: 4)
                        Spacer()
                    }
                    .padding(.top, 8)
                    
                    // header with close button
                    HStack {
                        Text(entry.title ?? "Untitled Stamp")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        Spacer()
                        Button(action: {
                            showSheet = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onDismiss()
                            }
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.secondary)
                                .padding(8)
                                .background(Color(.systemGray5))
                                .clipShape(Circle())
                        }
                    }
                    
                    // photo
                    if let photoData = entry.photoData, let image = UIImage(data: photoData) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // details
                    VStack(alignment: .leading, spacing: 12) {
                        if let location = entry.location, !location.isEmpty {
                            HStack(spacing: 10) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Location")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                    Text(location)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                }
                                Spacer()
                            }
                        }
                        
                        if let date = entry.date {
                            HStack(spacing: 10) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Date")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                    Text(ArcGISDateFormatter.medium.string(from: date))
                                        .font(.body)
                                        .foregroundColor(.primary)
                                }
                                Spacer()
                            }
                        }
                    }
                    
                    // view details button
                    Button(action: onTapForFullView) {
                        HStack {
                            Text("View Full Details")
                                .font(.body)
                                .fontWeight(.medium)
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.body)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    
                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 34)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -2)
                .offset(y: showSheet ? 0 : 400)
                .animation(.easeOut(duration: 0.3), value: showSheet)
            }
        }
        .onAppear {
            showSheet = true
        }
    }
}

// date formatter
struct ArcGISDateFormatter {
    static let medium: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}