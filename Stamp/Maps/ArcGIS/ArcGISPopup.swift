// ArcGISPopup.swift
// Bottom sheet popup UI for ArcGIS implementation

import SwiftUI

// MARK: - ArcGIS Bottom Sheet Popup
struct ArcGISBottomSheetPopup: View {
    let entry: JournalEntry
    let onTapForFullView: () -> Void
    let onDismiss: () -> Void
    @State private var showSheet = false
    
    var body: some View {
        ZStack {
            // Background overlay to dismiss popup
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
                
                // Bottom sheet content
                VStack(alignment: .leading, spacing: 16) {
                    // Handle bar
                    HStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(.systemGray4))
                            .frame(width: 40, height: 4)
                        Spacer()
                    }
                    .padding(.top, 8)
                    
                    // Header with title and close button
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
                    
                    // Photo
                    if let photoData = entry.photoData, let image = UIImage(data: photoData) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Details section
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
                    
                    // Full view button
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
                .padding(.bottom, 34) // Account for tab bar
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

// Helper extension for date formatting
extension ArcGISBottomSheetPopup {
    struct ArcGISDateFormatter {
        static let medium: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter
        }()
    }
}