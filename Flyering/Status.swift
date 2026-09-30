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


import Combine
import MapKit


final class Status: ObservableObject {
    
    // Selector for which page to show.
    @Published var pageSelector : displaying = .map

    // Whether to center the map on the user's location.
    @Published var goToUserLocation : Bool = false

    // Whether to set the screen to remain on always.
    @Published var screenOn = false
    
    // How the map tracks the user location.
    @Published var userTrackingMode: MKUserTrackingMode = .none
    // Counting down after the user moved or panned the map.
    @Published var userMapInteractionCountDown : Int = 0

    // Whether to record the traveled track.
    @Published var recordTrack : Bool = false
    // Cache of waypoints still to draw.
    @Published var pendingTrack : [CLLocationCoordinate2D] = []
    // Whether to clear the recorded track.
    @Published var clearTrack : Bool = false
    
    // The journal.
    @Published var journalText : String = ""

    // Marking an area as ready.
    @Published var markReadyStart : Bool = false
    @Published var showAreasReady : Bool = false
    @Published var removeLastArea : Bool = false
}


enum displaying {
    case map // Display the main page with the map.
    case actions // Display the page with the action controls.
    case maintenance // Display the page with maintenance controls
    case journal // Display the page with the journal control
    case exporting // Display the standard file export dialog.
    case importing // Display the standard file import dialog.
}


extension Status {

    var displayActions : Bool {
        get { pageSelector == .actions }
        set (display) {
            pageSelector = display ? .actions : .map
        }
    }

    var displayMaintenance : Bool {
        get { pageSelector == .maintenance }
        set (display) {
            pageSelector = display ? .maintenance : .map
        }
    }
    
    var displayJournal : Bool {
        get { pageSelector == .journal }
        set (display) {
            pageSelector = display ? .journal : .map
        }
    }

    var displayExport : Bool {
        get { pageSelector == .exporting }
        set (display) {
            pageSelector = display ? .exporting : .map
        }
    }

    var displayImport : Bool {
        get { pageSelector == .importing }
        set (display) {
            pageSelector = display ? .importing : .map
        }
    }

    var followingLocation: Bool {
        get { userTrackingMode != .none }
        set (follow) {
            userTrackingMode = follow ? .follow : .none
        }
    }
    
    var followingDirection: Bool {
        get { userTrackingMode == .followWithHeading }
        set (follow) {
            userTrackingMode = follow ? .followWithHeading : .follow
        }
    }
    
    func log(item: String) {
        var fragment : String = ""
        if !journalText.isEmpty {
            fragment.append("\n")
        }
        fragment.append(item)
        journalText.append(fragment)
    }
    
}
