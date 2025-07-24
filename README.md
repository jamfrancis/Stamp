# Overview

As a software engineer, I am always looking for opportunities to expand my skills and explore new technologies. This project is a personal endeavor to deepen my understanding of Geographic Information Systems (GIS) and mapping technologies on the iOS platform. I created an application that allows users to document their travels and experiences by creating "stamps" on a map, combining personal journaling with interactive cartography.

The application, Stamp, is a travel journaling app that leverages GIS to provide a rich, location-based experience. Users can create stamps that include a title, date, photo, and notes, which are then plotted on an interactive map. The core of the app is its ability to visually represent a user's travel history, turning a collection of memories into a personalized world map. The data for the maps is sourced from Apple Maps, providing a reliable and familiar interface for users.

My primary purpose in developing this software was to gain hands-on experience with MapKit and to explore the challenges of building a location-aware application. I wanted to move beyond simple map displays and implement features that are central to GIS, such as custom annotations, data overlays, and user interaction with map features.

[Software Demo Video](https://youtu.be/fhPr0o9lXRQ?si=eUMCiIyqEpVBS0pz)

# Development Environment

The app was developed using Xcode 26.0 Beta on macOS 26, with testing performed on both the iOS Simulator and physical devices. The entire application is written in Swift 6.2, using SwiftUI for the user interface and MapKit for all mapping and GIS-related functionalities.

The app integrates with Supabase for cloud storage, allowing for the seamless synchronization of travel stamps across multiple devices. This provides a robust backend for storing and retrieving geospatial data, ensuring that user information is always backed up and accessible.

# Useful Websites

* [iGIS](https://apps.apple.com/us/app/igis/id338967424)
* [Touch GIS](https://touchgis.app/)
* [ArcGIS Maps SDK for Swift](https://developers.arcgis.com/swift/)
* [Leaflet](https://leafletjs.com/)
* [Apple Developer Documentation – MapKit](https://developer.apple.com/documentation/mapkit)

# Future Work

* Implement offline map caching for remote areas where internet connectivity is limited.
* Add support for importing and exporting travel data in standard GIS formats like GeoJSON or KML.
* Integrate with other GIS services to provide more detailed map layers, such as satellite imagery or topographic maps.
* Develop a feature to create and share custom travel routes and itineraries.
