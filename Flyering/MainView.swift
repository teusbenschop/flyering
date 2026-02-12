/*
 Copyright (©) 2025-2025 Teus Benschop.
 
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
import MapKit
import Combine
import Foundation
import CoreLocation
import UniformTypeIdentifiers


struct MainView: View {
    
    // Property wrappers for observable objects that the parent view supplies.
    @EnvironmentObject private var mapModel: MapViewModel
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var status: Status
    @EnvironmentObject private var trackDatabase: TrackDatabase
    @Environment(\.scenePhase) var scenePhase

    @State var timer = Timer.publish(every: 5, tolerance: 0.5, on: .main, in: .common).autoconnect()
    @State private var lastLocation : CLLocation = CLLocation()
    @State private var counter : Int = 0

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                MapViewUi()
                    .ignoresSafeArea()
                ButtonDisplayMenu()
                    .padding()
            }
            .navigationDestination(isPresented: $status.displayActions) {
                ActionsView()
            }
            .navigationDestination(isPresented: $status.displayMaintenance) {
                MaintenanceView()
            }
            .navigationDestination(isPresented: $status.displayJournal) {
                JournalView()
            }
        }
        .onAppear {
            // On startup cause the map to draw any track from the database.
            status.pendingTrack = trackDatabase.getAll()
            // Handle keeping screen on.
            if status.screenOn {
                UIApplication.shared.isIdleTimerDisabled = true
            }
            // Do logging.
            status.log(item: "Main view appears")
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onReceive(timer) { time in
            if status.recordTrack {
                if scenePhase == .active {
                    recordTrack()
                }
            }
            // A mechanism that detects if the map has not moved in a while.
            // If that is the case, and the map tracks the user location,
            // then this mechanism will reset the user tracking mode.
            let interactionLimit = 3
            if status.userMapInteractionCountDown < interactionLimit {
                status.userMapInteractionCountDown += 1
                if status.userMapInteractionCountDown == interactionLimit {
                    if (status.userTrackingMode != .none) {
                        let userTrackingMode = status.userTrackingMode
                        status.userTrackingMode = .none
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            status.userTrackingMode = userTrackingMode
                        }
                    }
                }
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            locationManager.handleChangeScenePhase(recording: status.recordTrack,
                                                   old: oldPhase, new: newPhase)
        }
        .fileExporter(
            isPresented: $status.displayExport,
            document: DataDocument(areaDatabaseData()),
            contentType: .data,
            defaultFilename: areaDatabaseName()
        ) { result in
            switch result {
            case .success(let url):
                print("Saved to", url)
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
        .fileImporter(
            isPresented: $status.displayImport,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else {return}
                print(url)
                let areaDatabase = AreaDatabase()
                areaDatabase.importAreas(url: url)
            case .failure(let error):
                print("failed with error:", error.localizedDescription)
            }
        }

    }

    func recordTrack() {
        // Iterate over the locations.
        while !locationManager.locations.isEmpty {
            // Safely get and remove one location from the array.
            let location = safelyGetOneLocation()
            // Get the time elapsed since the last recorded location,
            // whether it's large enough to record it.
            let intervalSeconds = location.timestamp.timeIntervalSince(lastLocation.timestamp)
            if (intervalSeconds < 5) {
                continue;
            }
            // Get the distance from the previous location,
            // whether it's large enough to draw it.
            let distanceMeters = location.distance(from: lastLocation)
            if (distanceMeters < 4.9) {
                continue
            }
            // Store this location as a reference for next time.
            lastLocation = location
            // Store the new coordinate in the database.
            // Store it in the State object.
            // This will prompt the mapview to draw it on the map.
            let coordinate = location.coordinate
            trackDatabase.storeCoordinate(coordinate: coordinate)
            status.pendingTrack.append(coordinate)
        }
    }

    
    func safelyGetOneLocation() -> CLLocation {
        locationManager.lock.lock()
        defer { locationManager.lock.unlock() }
        let location = locationManager.locations.removeFirst()
        return location
    }
    

    
    
}
