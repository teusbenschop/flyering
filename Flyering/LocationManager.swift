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
import MapKit
import Combine
import Foundation
import CoreLocation


enum status {
    case none // No location information available.
    case inuse // Location information available if app is in the foreground, i.e. in use.
    case always // Location information always availble, also if app runs in background.
}


private let please_grant_access_to_user_location = "Please grant access to user location"
private let user_location_has_been_restricted = "User location has been restricted"
private let user_location_has_been_denied = "User location has been denied"
private let user_location_always_available = "User location always available"
private let user_location_available_when_app_in_use = "User location available when app in use"
private let user_location_disabled = "User location disabled"


// Basic location manager object.
// This object is the delegate of the Core Location Location Manager.
// This object will makes updates in the CLLocationManager available to the app.
// On the iOS simulator, the location permissions can be set from the terminal:
// $ xcrun simctl privacy "iPhone 12" grant location-always org.bibledit.ios.test
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    
    @Published var status : status = .none
    @Published var info : String = ""
    // Most recent location, always updated, whether recording or not.
    @Published var location: CLLocation?
    // The list of locations, updated when recording.
    @Published var recording: Bool = false
    @Published var locations: [CLLocation] = []
    @Published var lock = NSLock()

    private var locationManager = CLLocationManager()
    private var backgroundActivitySesion: CLBackgroundActivitySession? = nil
    private var appInForeground : Bool = false

    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        // Right at initialization it requests a single, one time location data point.
        // This causes, through some logic elsewhere,
        // the map to open at the user's location for convenience.
        locationManager.startUpdatingLocation()
        locationManager.requestLocation()
        // Keep receiving locations even if the app is in the background. Todo switch on if background only.
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.showsBackgroundLocationIndicator = true
    }

    
    // Tells the delegate when the app creates the location manager
    // and when the authorization status changes.
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse:
            // Needed to cause the map to open at the user's location.
            manager.startUpdatingLocation()
            manager.requestLocation()
        case .authorizedAlways:
            // Needed to cause the map to open at the user's location.
            manager.startUpdatingLocation()
            manager.requestLocation()
        case .restricted:
            ()
        case .denied:
            ()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        @unknown default:
            ()
        }
        updateFeedback()
    }

    
    // Tells the delegate that the location manager was unable to retrieve a location value.
    func locationManager(_ manager: CLLocationManager,
                         didFailWithError error: Error) {
        status = .none
        info = error.localizedDescription
    }

    
    // Tells the delegate that new location data is available.
    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.location = location
        if recording {
            lock.lock()
            defer { lock.unlock() }
            self.locations.append(location)
        }
        if appInForeground {
            updateFeedback()
        }
    }

    
    // Tells the delegate that updates will no longer be deferred.
    func locationManager(_ manager: CLLocationManager,
                         didFinishDeferredUpdatesWithError: (any Error)?) {
    }
    
    
    // Tells the delegate that location updates were paused.
    func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
    }
    
    // Tells the delegate that the delivery of location updates has resumed.
    func locationManagerDidResumeLocationUpdates(_ manager: CLLocationManager) {
    }
    
    
    // Tells the delegate that the location manager received updated heading information.
    func locationManager(_ manager: CLLocationManager, didUpdateHeading: CLHeading) {
    }
    
    
    // Asks the delegate whether the heading calibration alert should be displayed.
    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        return false
    }

    
    // Update location feedback to be used in SwiftUI.
    // Make sure to not blindly set the feedback, as this causes redraws in SwiftUI.
    // Only update a feedback variable if needed.
    func updateFeedback() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            if (status != .none) {
                status = .none
            }
            if (info != please_grant_access_to_user_location) {
                info = please_grant_access_to_user_location
            }
        case .restricted:
            if (status != .none) {
                status = .none
            }
            if (info != user_location_has_been_restricted) {
                info = user_location_has_been_restricted
            }
        case .denied:
            if (status != .none) {
                status = .none
            }
            if (info != user_location_has_been_denied) {
                info = user_location_has_been_denied
            }
        case .authorizedAlways:
            if (status != .always) {
                status = .always
            }
            if (info != user_location_always_available) {
                info = user_location_always_available
            }
        case .authorizedWhenInUse:
            if (status != .inuse) {
                status = .inuse
            }
            if (info != user_location_available_when_app_in_use) {
                info = user_location_available_when_app_in_use
            }
        @unknown default:
            if (status != .none) {
                status = .none
            }
            if (info != user_location_disabled) {
                info = user_location_disabled
            }
        }
    }
    
    
    func checkLocationAuthorization() {
        updateFeedback()
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted:
            ()
        case .denied:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways:
            ()
        case .authorizedWhenInUse:
            location = locationManager.location
            guard let location = locationManager.location else { return }
            locations.append(location)
        @unknown default:
            ()
        }
    }
    
    
    func handleChangeScenePhase (recording: Bool, old: ScenePhase, new: ScenePhase) {
        // If recording the track,
        // just before going into the background,
        // create the object that manages a visual indicator to the user
        // that keeps the app in use in the background,
        // allowing it to receive updates or events.
        if new == .background {
            if recording {
                backgroundActivitySesion = CLBackgroundActivitySession()
            }
        }
        // When going back to the foreground, remove this object again.
        if (new == .active) {
            backgroundActivitySesion = nil
        }
        // Set flag for whether app is running in the foreground.
        if (new == .active) {
            appInForeground = true
        }
        if (new == .background) {
            appInForeground = false
        }
        //print (recording, old, new)
    }
    
    func startReceivingLocations() {
        // To receive the most precise and regular location data,
        // call the startUpdatingLocation() function,
        // This is the most power-consuming option.
        // Other options, such as startMonitoringSignificantLocationChanges()
        // and startMonitoringVisits() are lower power,
        // but also not as precise or as frequently updated.
        locationManager.startUpdatingLocation()
    }
    
    func stopReceivingLocations() {
        locationManager.stopUpdatingLocation()
    }
}

