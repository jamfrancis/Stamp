# Overview

Stamp is an iOS travel journaling app that allows users to create digital "stamps" to document their travels and experiences. Each stamp contains a title, location, date, photo, and personal notes, creating a comprehensive record of memorable moments. The app now features cloud database integration with Supabase, enabling real-time synchronization across devices and secure cloud storage of all travel entries.

The app seamlessly integrates with Supabase, a PostgreSQL-based cloud database platform, to provide robust data persistence and synchronization. Users can create, edit, and delete stamps locally, with changes automatically syncing to the cloud when an internet connection is available. The sync system handles offline functionality gracefully, queuing changes locally and uploading them when connectivity is restored. This ensures that travel memories are never lost, even when exploring remote destinations without reliable internet access.

As a software engineer, I built this app to deepen my understanding of modern iOS development patterns, particularly around cloud database integration, offline-first architecture, and real-time data synchronization. The project challenged me to implement complex sync logic while maintaining a simple, intuitive user experience that follows iOS design principles.

[Software Demo Video](https://youtu.be/k_R61EQgq0I)

# Cloud Database

The app uses Supabase as its cloud database platform, which provides a PostgreSQL database with real-time subscriptions, authentication, and RESTful APIs. Supabase offers a modern alternative to Firebase with the added benefit of using standard SQL and being open-source.

The database structure centers around a single stamps table with the following schema:

id (UUID, Primary Key): Unique identifier for each stamp
title (String): User-defined title for the stamp
content (Text): Detailed notes and descriptions
location (String): Geographic location name
date (Timestamp): When the stamp was created or when the experience occurred
photo_data (Text): URL that points to Supabase Storage location
edit_date (Timestamp): Last modification timestamp
is_archived (Boolean): Soft delete flag for archived stamps
latitude (Double): GPS latitude coordinate extracted from photos
longitude (Double): GPS longitude coordinate extracted from photos
created_at (Timestamp): Database creation timestamp
updated_at (Timestamp): Database modification timestamp for sync tracking

# Development Environment

The app was developed using Xcode 26.0 Beta on macOS 26, with testing performed on both the iOS Simulator and physical devices including iPhone 14 Pro and iPad Pro 11-inch using iOS 26. The project leverages modern iOS development tools and frameworks to create a native, performant experience.
The app is written entirely in Swift 6.2 using SwiftUI for the user interface framework.

# Useful Websites

* [Apple Developer Documentation – SwiftUI](https://developer.apple.com/documentation/swiftui)
* [Hacking with Swift – SwiftUI Tutorials](https://www.hackingwithswift.com/quick-start/swiftui)
* [Stack Overflow](https://stackoverflow.com)
* [Swift by Sundell](https://www.swiftbysundell.com)

# Future Work

* Create export functionality for sharing complete travel journals
* Implement push notifications for sync status and shared journal updates
* Add offline map tiles for locations without internet connectivity