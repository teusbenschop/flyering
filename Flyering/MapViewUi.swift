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

struct MapViewUi: UIViewRepresentable {

    @EnvironmentObject var mapModel: MapViewModel
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var status: Status
    @EnvironmentObject var markAreaReady: MarkAreaReady
    
    @State private var previousUserTrackingMode: MKUserTrackingMode = .none
    @State private var previousShowAreasReady: Bool = false


    func makeUIView(context: Context) -> MKMapView {

        let mapView = mapModel.mkMapView
        
        // Assign the coordinator (delegate).
        mapView.delegate = context.coordinator

        // Display all points of interest because these may assist as beacons during flyering.
        let configuration = MKStandardMapConfiguration()
        configuration.pointOfInterestFilter = .includingAll
        mapView.preferredConfiguration = configuration

        // More useful settings for the map.
        mapView.mapType = .standard
        mapView.isPitchEnabled = true
        mapView.isRotateEnabled = true
        mapView.showsUserLocation = true

        // Do not track user initially (can be changed by the user).
        mapView.setUserTrackingMode(.none, animated: false)

        // Don't show the user tracking button because that interferes with the custom menu button.
        mapView.showsUserTrackingButton = false

        // Let the map open at the user's location for convenience. // Todo fix this again.
        if let location = locationManager.location {
            mapView.region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        }

        // Return the configured map.
        return mapView
    }


    // This is called if any of the observed objects or their published members changes.
    func updateUIView(_ uiView: MKMapView, context: Context) {
        
        // Handle focusing on user's location.
        if status.goToUserLocation, let location = locationManager.location {
            uiView.setRegion(
                MKCoordinateRegion(
                    center: location.coordinate,
                    // Keep the current zoomlevel as the user may have adjusted it.
                    span: uiView.region.span
                ),
                animated: false
            )
            // Check again whether or not the labels should be displayed.
            uiView.delegate?.mapView?(uiView, regionDidChangeAnimated: false)
        }
        
        // Handle change in user tracking mode.
        if status.userTrackingMode != previousUserTrackingMode {
            uiView.setUserTrackingMode(status.userTrackingMode, animated: false)
            DispatchQueue.main.async {
                previousUserTrackingMode = status.userTrackingMode
            }
        }
        
        // Check on and add the track to the map.
        if !status.pendingTrack.isEmpty {
            for coordinate in status.pendingTrack {
                let annotation = MKPointAnnotation()
                annotation.coordinate = coordinate
                uiView.addAnnotation(annotation)
            }
            DispatchQueue.main.async() {
                status.pendingTrack = []
            }
        }
        
        // Check on whether to erase the recorded track.
        if status.clearTrack {
            for annotation in uiView.annotations {
                guard annotation is MKPointAnnotation else { continue }
                uiView.removeAnnotation(annotation)
            }
            DispatchQueue.main.async() {
                status.clearTrack = false
            }
        }
        
        // Check on whether to start marking area as ready.
        if status.markReadyStart {
            markAreaReady.start(mapView: uiView)
            DispatchQueue.main.async() {
                status.markReadyStart = false
            }
        }
        
        // Check on whether to show the area ready.
        if status.showAreasReady != previousShowAreasReady {
            if status.showAreasReady {
                markAreaReady.showReady(mapView: uiView)
            } else {
                markAreaReady.hideReady(mapView: uiView)
            }
            DispatchQueue.main.async() {
                previousShowAreasReady = status.showAreasReady
            }
        }
        
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // The Coordinator contains code for custom view appearance and behaviour.
    class Coordinator: NSObject, MKMapViewDelegate {

        var parent: MapViewUi
        
        init(_ parent: MapViewUi) {
            self.parent = parent
            super.init()
            let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            self.parent.mapModel.mkMapView.addGestureRecognizer(tapRecognizer)
            let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
            self.parent.mapModel.mkMapView.addGestureRecognizer(longPressRecognizer)
        }
    }
    
    
}

