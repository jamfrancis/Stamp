// MapKitPopup.swift
// Custom popup UI components for MapKit implementation

import SwiftUI

// MARK: - MapKit Expanding Popup
struct MapKitExpandingPopup: View {
    let entry: JournalEntry
    let onTapForFullView: () -> Void
    let onDismiss: () -> Void
    @State private var showPopup = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Full screen background overlay to dismiss popup
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.15)) {
                            onDismiss()
                        }
                    }
                
                // Popup positioned above center
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Callout bubble
                    VStack(alignment: .leading, spacing: 12) {
                        // Header
                        HStack {
                            Text(entry.title ?? "Untitled Stamp")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .lineLimit(2)
                            Spacer()
                        }
                        
                        // Photo
                        if let photoData = entry.photoData, let image = UIImage(data: photoData) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 120)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        
                        // Details
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
                        
                        // Full view button
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
                        // Callout pointer
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

// Helper extension for date formatting
extension DateFormatter {
    static let medium: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}