// MapKitImplementation.swift
// complete mapkit implementation with photo pins and popups

import SwiftUI
import MapKit

// main mapkit view
struct MapKitView: View {
    let journalEntries: [JournalEntry]
    @Binding var selectedEntry: JournalEntry?
    @StateObject private var viewModel = MapViewModel()
    var onStampTap: ((JournalEntry) -> Void)? = nil
    
    var body: some View {
        ZStack {
            // mapkit map with pins
            MapKitMapRepresentable(
                journalEntries: journalEntries,
                viewModel: viewModel
            )
            
            // popup when pin selected
            if let selected = viewModel.selectedEntry {
                MapKitPopup(entry: selected, onTapForFullView: {
                    onStampTap?(selected)
                }) {
                    viewModel.clearSelection()
                    selectedEntry = nil
                }
                .allowsHitTesting(true)
                .zIndex(1000)
            }
        }
        // sync view model with binding
        .onChange(of: viewModel.selectedEntry) { newValue in
            selectedEntry = newValue
        }
        .onChange(of: selectedEntry) { newValue in
            if viewModel.selectedEntry?.id != newValue?.id {
                viewModel.selectEntry(newValue)
            }
        }
    }
}

// mapkit uiview wrapper
struct MapKitMapRepresentable: UIViewRepresentable {
    let journalEntries: [JournalEntry]
    let viewModel: MapViewModel
    @State private var mapView = MKMapView()
    
    func makeUIView(context: Context) -> MKMapView {
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        updatePins(on: uiView)
    }
    
    func makeCoordinator() -> MapKitCoordinator {
        MapKitCoordinator(self)
    }
    
    // add pins to map
    private func updatePins(on mapView: MKMapView) {
        // remove old pins
        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
        
        // add new pins
        let pins = journalEntries.compactMap { entry -> StampPin? in
            guard entry.latitude != 0 && entry.longitude != 0 else { return nil }
            return StampPin(entry: entry)
        }
        mapView.addAnnotations(pins)
    }
}

// mapkit delegate coordinator
class MapKitCoordinator: NSObject, MKMapViewDelegate {
    var parent: MapKitMapRepresentable
    
    init(_ parent: MapKitMapRepresentable) {
        self.parent = parent
    }
    
    // create custom pin views
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let stampPin = annotation as? StampPin else { return nil }
        
        let identifier = "StampPin"
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
        
        if pinView == nil {
            pinView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
        } else {
            pinView?.annotation = annotation
        }
        
        // create pin image
        if let photoData = stampPin.entry.photoData, let image = UIImage(data: photoData) {
            let pinImage = createPhotoPinImage(from: image)
            pinView?.image = pinImage
            pinView?.centerOffset = CGPoint(x: 0, y: -pinImage.size.height / 2)
        } else {
            let placeholderPin = createPlaceholderPin()
            pinView?.image = placeholderPin
            pinView?.centerOffset = CGPoint(x: 0, y: -placeholderPin.size.height / 2)
        }
        
        pinView?.canShowCallout = false
        return pinView
    }
    
    // handle pin selection
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let stampPin = view.annotation as? StampPin else { return }
        
        // prevent native callout
        mapView.deselectAnnotation(view.annotation, animated: false)
        
        // update selection on main thread
        DispatchQueue.main.async {
            if self.parent.viewModel.selectedEntry?.id == stampPin.entry.id {
                self.parent.viewModel.clearSelection()
            } else {
                self.parent.viewModel.selectEntry(stampPin.entry)
            }
        }
    }
    
    // create photo pin image
    private func createPhotoPinImage(from originalImage: UIImage) -> UIImage {
        let croppedImage = cropToSquare(originalImage)
        let pinSize = CGSize(width: 60, height: 75)
        let photoSize = CGSize(width: 50, height: 50)
        
        let renderer = UIGraphicsImageRenderer(size: pinSize)
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // photo rectangle
            let photoRect = CGRect(
                x: (pinSize.width - photoSize.width) / 2,
                y: 5,
                width: photoSize.width,
                height: photoSize.height
            )
            
            // pin tip triangle
            let tipPath = UIBezierPath()
            let centerX = pinSize.width / 2
            tipPath.move(to: CGPoint(x: centerX - 8, y: photoRect.maxY + 5))
            tipPath.addLine(to: CGPoint(x: centerX, y: pinSize.height - 5))
            tipPath.addLine(to: CGPoint(x: centerX + 8, y: photoRect.maxY + 5))
            tipPath.close()
            
            // draw shadow
            cgContext.setShadow(offset: CGSize(width: 2, height: 3), blur: 6, color: UIColor.black.withAlphaComponent(0.4).cgColor)
            
            // white background
            let frameRect = photoRect.insetBy(dx: -3, dy: -3)
            let framePath = UIBezierPath(roundedRect: frameRect, cornerRadius: 8)
            UIColor.white.setFill()
            framePath.fill()
            
            // draw photo
            cgContext.saveGState()
            let photoPath = UIBezierPath(roundedRect: photoRect, cornerRadius: 6)
            photoPath.addClip()
            croppedImage.draw(in: photoRect)
            cgContext.restoreGState()
            
            // draw pin tip
            UIColor.white.setFill()
            tipPath.fill()
            
            // border
            UIColor.systemGray4.setStroke()
            let borderPath = UIBezierPath(roundedRect: photoRect, cornerRadius: 6)
            borderPath.lineWidth = 1
            borderPath.stroke()
        }
    }
    
    // create placeholder pin
    private func createPlaceholderPin() -> UIImage {
        let pinSize = CGSize(width: 60, height: 75)
        let photoSize = CGSize(width: 50, height: 50)
        
        let renderer = UIGraphicsImageRenderer(size: pinSize)
        return renderer.image { context in
            let cgContext = context.cgContext
            
            let photoRect = CGRect(
                x: (pinSize.width - photoSize.width) / 2,
                y: 5,
                width: photoSize.width,
                height: photoSize.height
            )
            
            let tipPath = UIBezierPath()
            let centerX = pinSize.width / 2
            tipPath.move(to: CGPoint(x: centerX - 8, y: photoRect.maxY + 5))
            tipPath.addLine(to: CGPoint(x: centerX, y: pinSize.height - 5))
            tipPath.addLine(to: CGPoint(x: centerX + 8, y: photoRect.maxY + 5))
            tipPath.close()
            
            cgContext.setShadow(offset: CGSize(width: 2, height: 3), blur: 6, color: UIColor.black.withAlphaComponent(0.4).cgColor)
            
            // white background
            let frameRect = photoRect.insetBy(dx: -3, dy: -3)
            let framePath = UIBezierPath(roundedRect: frameRect, cornerRadius: 8)
            UIColor.white.setFill()
            framePath.fill()
            
            // gray placeholder
            let placeholderPath = UIBezierPath(roundedRect: photoRect, cornerRadius: 6)
            UIColor.systemGray5.setFill()
            placeholderPath.fill()
            
            // photo icon
            let iconRect = CGRect(x: photoRect.midX - 12, y: photoRect.midY - 12, width: 24, height: 24)
            if let photoIcon = UIImage(systemName: "photo")?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)) {
                UIColor.systemGray3.setFill()
                photoIcon.draw(in: iconRect)
            }
            
            // pin tip
            UIColor.white.setFill()
            tipPath.fill()
            
            // border
            UIColor.systemGray4.setStroke()
            let borderPath = UIBezierPath(roundedRect: photoRect, cornerRadius: 6)
            borderPath.lineWidth = 1
            borderPath.stroke()
        }
    }
    
    // crop image to square
    private func cropToSquare(_ image: UIImage) -> UIImage {
        let size = min(image.size.width, image.size.height)
        let x = (image.size.width - size) / 2
        let y = (image.size.height - size) / 2
        
        let cropRect = CGRect(x: x, y: y, width: size, height: size)
        
        guard let cgImage = image.cgImage?.cropping(to: cropRect) else {
            return image
        }
        
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}

// pin annotation class
class StampPin: NSObject, MKAnnotation {
    let entry: JournalEntry
    var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?
    
    init(entry: JournalEntry) {
        self.entry = entry
        self.coordinate = CLLocationCoordinate2D(latitude: entry.latitude, longitude: entry.longitude)
        self.title = entry.title ?? "Untitled Stamp"
        
        // create subtitle with location and date
        var subtitleParts: [String] = []
        if let location = entry.location, !location.isEmpty {
            subtitleParts.append(location)
        }
        if let date = entry.date {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            subtitleParts.append(formatter.string(from: date))
        }
        self.subtitle = subtitleParts.joined(separator: " • ")
        
        super.init()
    }
}

// popup for mapkit
struct MapKitPopup: View {
    let entry: JournalEntry
    let onTapForFullView: () -> Void
    let onDismiss: () -> Void
    @State private var showPopup = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // background overlay
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.15)) {
                            onDismiss()
                        }
                    }
                
                // popup content
                VStack(spacing: 0) {
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        // title
                        HStack {
                            Text(entry.title ?? "Untitled Stamp")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .lineLimit(2)
                            Spacer()
                        }
                        
                        // photo
                        if let photoData = entry.photoData, let image = UIImage(data: photoData) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 120)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        
                        // location and date
                        VStack(alignment: .leading, spacing: 6) {
                            if let location = entry.location, !location.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "location.fill")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    Text(location)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            
                            if let date = entry.date {
                                HStack(spacing: 6) {
                                    Image(systemName: "calendar")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    Text(DateFormatter.medium.string(from: date))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        // view details button
                        Button(action: onTapForFullView) {
                            HStack {
                                Text("View Details")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .font(.caption)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    .padding(16)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
                    .overlay(
                        // callout pointer
                        Path { path in
                            let width: CGFloat = 20
                            let height: CGFloat = 10
                            path.move(to: CGPoint(x: -width/2, y: 0))
                            path.addLine(to: CGPoint(x: 0, y: height))
                            path.addLine(to: CGPoint(x: width/2, y: 0))
                            path.closeSubpath()
                        }
                        .fill(Color(.systemBackground))
                        .offset(y: 16)
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2),
                        alignment: .bottom
                    )
                    .frame(maxWidth: 280)
                    .scaleEffect(showPopup ? 1.0 : 0.8)
                    .opacity(showPopup ? 1.0 : 0.0)
                    
                    Spacer().frame(height: 120)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.15)) {
                showPopup = true
            }
        }
    }
}

// date formatter extension
extension DateFormatter {
    static let medium: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}