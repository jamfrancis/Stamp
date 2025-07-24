// MapSettings.swift
// Manages user preferences for map implementation

import Foundation
import SwiftUI

enum MapImplementation: String, CaseIterable {
    case mapKit = "mapkit"
    case arcGIS = "arcgis"
    
    var displayName: String {
        switch self {
        case .mapKit:
            return "MapKit"
        case .arcGIS:
            return "ArcGIS"
        }
    }
}

class MapSettings: ObservableObject {
    static let shared = MapSettings()
    
    @Published var selectedImplementation: MapImplementation {
        didSet {
            UserDefaults.standard.set(selectedImplementation.rawValue, forKey: "selectedMapImplementation")
        }
    }
    
    private init() {
        let savedImplementation = UserDefaults.standard.string(forKey: "selectedMapImplementation") ?? MapImplementation.mapKit.rawValue
        self.selectedImplementation = MapImplementation(rawValue: savedImplementation) ?? .mapKit
    }
}