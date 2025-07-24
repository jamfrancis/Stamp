// MapKitView.swift
// MapKit-specific implementation with photo pins and interactive popups

import SwiftUI
import MapKit

// MARK: - Main MapKit View
struct MapKitView: View {
    let journalEntries: [JournalEntry]
    @Binding var selectedEntry: JournalEntry?
    @StateObject private var viewModel = MapViewModel()
    var onStampTap: ((JournalEntry) -> Void)? = nil
    
    var body: some View {
        ZStack {
            MapKitViewRepresentable(
                journalEntries: journalEntries,
                viewModel: viewModel
            )
            
            // Show positioned popup when pin is selected
            if let selected = viewModel.selectedEntry {
                MapKitExpandingPopup(entry: selected, onTapForFullView: {
                    onStampTap?(selected)
                }) {
                    viewModel.clearSelection()
                    selectedEntry = nil
                }
                .allowsHitTesting(true)
                .zIndex(1000)
            }
        }
        .onChange(of: viewModel.selectedEntry) { oldValue, newValue in
            selectedEntry = newValue
        }
        .onChange(of: selectedEntry) { oldValue, newValue in
            if viewModel.selectedEntry?.id != newValue?.id {
                viewModel.selectEntry(newValue)
            }
        }
    }
}

// MARK: - MapKit UIViewRepresentable
struct MapKitViewRepresentable: UIViewRepresentable {
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
        updateAnnotations(on: uiView)
    }
    
    func makeCoordinator() -> MapKitCoordinator {
        MapKitCoordinator(self)
    }
    
    private func updateAnnotations(on mapView: MKMapView) {
        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
        
        let annotations = journalEntries.compactMap { entry -> StampAnnotation? in
            guard entry.latitude != 0 && entry.longitude != 0 else { return nil }
            return StampAnnotation(entry: entry)
        }
        
        mapView.addAnnotations(annotations)
    }
}

// MARK: - MapKit Coordinator
class MapKitCoordinator: NSObject, MKMapViewDelegate {
    var parent: MapKitViewRepresentable
    
    init(_ parent: MapKitViewRepresentable) {
        self.parent = parent
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let stampAnnotation = annotation as? StampAnnotation else { return nil }
        
        let identifier = "StampPhotoPin"
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
        
        if annotationView == nil {
            annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
        } else {
            annotationView?.annotation = annotation
        }
        
        // Create custom photo pin
        if let photoData = stampAnnotation.entry.photoData, let originalImage = UIImage(data: photoData) {
            let pinImage = MapKitPinRenderer.createPhotoPinImage(from: originalImage)
            annotationView?.image = pinImage
            annotationView?.centerOffset = CGPoint(x: 0, y: -pinImage.size.height / 2)
        } else {
            // Fallback for entries without photos
            let placeholderPin = MapKitPinRenderer.createPlaceholderPinImage()
            annotationView?.image = placeholderPin
            annotationView?.centerOffset = CGPoint(x: 0, y: -placeholderPin.size.height / 2)
        }
        
        annotationView?.canShowCallout = false
        
        return annotationView
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let stampAnnotation = view.annotation as? StampAnnotation else { return }
        
        // Deselect the annotation immediately to prevent native callout
        mapView.deselectAnnotation(view.annotation, animated: false)
        
        DispatchQueue.main.async {
            // Toggle selection for consistent behavior
            if self.parent.viewModel.selectedEntry?.id == stampAnnotation.entry.id {
                self.parent.viewModel.clearSelection()
            } else {
                self.parent.viewModel.selectEntry(stampAnnotation.entry)
            }
        }
    }
}