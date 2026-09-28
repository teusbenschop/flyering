/*
 Copyright (©) 2025-2026 Teus Benschop.
 
 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 3 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

import SwiftUI

// Tutorials used:
// https://medium.com/@leocoronag/interactive-polygon-zones-in-mapkit-customizing-your-map-views-to-an-obsessive-extent-77943267ed10

// In-depth information:
// https://developer.apple.com/library/archive/documentation/UserExperience/Conceptual/LocationAwarenessPG/AnnotatingMaps/AnnotatingMaps.html

// Method for linking data and views:
// 1. Create view model classes for the different features of the app.
// 2. These classes conform to the ObservableObject protocol.
// 3. Define singleton objects in the top of the view hierarchy with @StateObject.
// $. Pass the singletons down as environment objects.
// This frees the developer from the pain of bindings and general coupling in the code structure.


@main
struct FlyeringTracker: App {
    
    @StateObject private var mapModel = MapViewModel()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var status = Status()
    @StateObject private var trackDatabase = TrackDatabase()
    @StateObject private var markAreaReady = MarkAreaReady()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(mapModel)
                .environmentObject(locationManager)
                .environmentObject(status)
                .environmentObject(trackDatabase)
                .environmentObject(markAreaReady)
        }
    }
}
