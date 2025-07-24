// ArcGISView.swift
// ArcGIS Maps SDK implementation with professional cartography

import SwiftUI
import ArcGIS

// MARK: - Main ArcGIS View
struct ArcGISView: View {
    let journalEntries: [JournalEntry]
    @Binding var selectedEntry: JournalEntry?
    @StateObject private var viewModel = MapViewModel()
    @Binding var showPastMonthOnly: Bool
    var onStampTap: ((JournalEntry) -> Void)? = nil
    
    var body: some View {
        if ArcGISAvailability.isAvailable {
            ArcGISMapViewContainer(
                journalEntries: journalEntries,
                viewModel: viewModel,
                showPastMonthOnly: $showPastMonthOnly,
                onStampTap: onStampTap
            )
            .onChange(of: viewModel.selectedEntry) { oldValue, newValue in
                selectedEntry = newValue
            }
            .onChange(of: selectedEntry) { oldValue, newValue in
                if viewModel.selectedEntry?.id != newValue?.id {
                    viewModel.selectEntry(newValue)
                }
            }
        } else {
            ArcGISUnavailableFallback(
                journalEntries: journalEntries,
                viewModel: viewModel
            )
        }
    }
}

// MARK: - ArcGIS Container with Header
struct ArcGISMapViewContainer: View {
    let journalEntries: [JournalEntry]
    let viewModel: MapViewModel
    @Binding var showPastMonthOnly: Bool
    var onStampTap: ((JournalEntry) -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // ArcGIS branding header
            HStack {
                VStack(alignment: .leading) {
                    Text("ArcGIS Maps")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("Professional cartography with internet basemap")
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
            
            // Main ArcGIS map view
            ArcGISMapViewImplementation(
                journalEntries: journalEntries,
                viewModel: viewModel,
                showPastMonthOnly: $showPastMonthOnly,
                onStampTap: onStampTap
            )
        }
    }
}

// MARK: - Fallback View
struct ArcGISUnavailableFallback: View {
    let journalEntries: [JournalEntry]
    let viewModel: MapViewModel
    
    var body: some View {
        VStack {
            Text("ArcGIS Unavailable")
                .font(.title2)
                .foregroundColor(.orange)
                .padding()
            
            Text("ArcGIS SDK not available. Contact developer for MapKit fallback.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
        .background(Color(.systemGray6))
    }
}