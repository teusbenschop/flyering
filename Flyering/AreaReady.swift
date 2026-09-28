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


// The indices for the reject and accept annotations (buttons).
// (The polygon vertices have positive indices 0...n)
let rejectIndex = -1
let acceptIndex = -2


final class MarkAreaReady: ObservableObject {

    var coordinates : [CLLocationCoordinate2D] = []
    

    func start(mapView: MKMapView) {
        
        // Remove data possibly left over from a previous mark-ready operation.
        clear(mapView: mapView)

        // Determine the points on the screen where the octagon is to be placed.
        var points : [CGPoint] = []
        let windowOrigin : CGPoint = mapView.frame.origin
        let windowSize = mapView.frame.size
        let x = windowOrigin.x
        let y = windowOrigin.y
        let w = windowSize.width
        let h = windowSize.height
        points.append(CGPoint(x: x + w * 0.1, y: y + h * 0.2)) // Top left.
        points.append(CGPoint(x: x + w * 0.5, y: y + h * 0.1))
        points.append(CGPoint(x: x + w * 0.9, y: y + h * 0.2)) // Top right.
        points.append(CGPoint(x: x + w * 0.9, y: y + h * 0.5))
        points.append(CGPoint(x: x + w * 0.9, y: y + h * 0.8)) // Bottom right.
        points.append(CGPoint(x: x + w * 0.5, y: y + h * 0.9))
        points.append(CGPoint(x: x + w * 0.1, y: y + h * 0.8)) // Bottom left.
        points.append(CGPoint(x: x + w * 0.1, y: y + h * 0.5))

        // Convert the screen points to coordinates on the map and store those.
        points.enumerated().forEach {
            let point = $0.element
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            coordinates.append(coordinate)
        }
        
        placeAnnotations(mapView: mapView)
        
        drawPolygon(mapView: mapView)

        // Determine the points on the screen for placing
        // the reject and accept annotations that act as buttons.
        // The reject button is at the left as is normal for a cancel button.
        // The accept button is at the right like the usual OK button.
        let rejectPoint = CGPoint(x: x + w * 1/3, y: y + h * 0.5)
        let acceptPoint = CGPoint(x: x + w * 2/3, y: y + h * 0.5)
        drawButtons(mapView: mapView, rejectPoint: rejectPoint, acceptPoint: acceptPoint)
    }

    
    // Function to place the annotations on the map, based on the coordinates.
    func placeAnnotations (mapView: MKMapView) {
        // Place annotations on the map at the calculated coordinates.
        coordinates.enumerated().forEach {
            let index = $0.offset
            let coordinate = $0.element
            let annotation = DraggableAnnotation(coordinate: coordinate, index: index)
            mapView.addAnnotation(annotation)
        }
    }

    
    // Function to draw the polygon on the map, based on the coordinates.
    func drawPolygon (mapView: MKMapView) {
        // If the user has started a ready operation,
        // and has not completed the operation,
        // remove the polygon from the map and clear its data.
        for polygon in mapView.overlays {
            if let readyPolygon = polygon as? ReadyPolygon {
                mapView.removeOverlay(readyPolygon)
            }
        }
        // Draw the polygon on the map to initially mark the area.
        let polygon = ReadyPolygon(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(polygon)
    }
    
    
    // Function to place the reject and accept buttons on the map.
    func drawButtons (mapView: MKMapView, rejectPoint: CGPoint, acceptPoint: CGPoint) {
        // Place annotations as buttons on the map at the calculated coordinates.
        let rejectCoordinate = mapView.convert(rejectPoint, toCoordinateFrom: mapView)
        let rejectAnnotation = DraggableAnnotation(coordinate: rejectCoordinate, index: rejectIndex)
        mapView.addAnnotation(rejectAnnotation)
        let acceptCoordinate = mapView.convert(acceptPoint, toCoordinateFrom: mapView)
        let acceptAnnotation = DraggableAnnotation(coordinate: acceptCoordinate, index: acceptIndex)
        mapView.addAnnotation(acceptAnnotation)
    }
    

    func clear(mapView: MKMapView) {

        // Clear possibly previous coordinates.
        coordinates = []
        
        // If the user has started a ready operation,
        // and has not completed it,
        // remove the relevant annotations from the map.
        for annotation in mapView.annotations {
            if annotation is DraggableAnnotation {
                mapView.removeAnnotation(annotation)
            }
        }
        
        // Remove possible polygon left over.
        drawPolygon(mapView: mapView)
    }

    
    func accept(mapView: MKMapView) {
        
        // Store the coordinates in the database.
        let areaDatabase = AreaDatabase()
        let success = areaDatabase.storeCoordinates(coordinates: coordinates)
        
        // On failure to store the coordinates, bail out early.
        // It means that the map retains the area as if still working on marking it.
        if !success {
            //status.log(item: "Failure to store the marked area")
            return
        }
        
        // Keep a copy of the coordinates.
        let coordinates = self.coordinates

        // Remove the markers from the map.
        clear(mapView: mapView)
        
        // Call function with data from the database to draw this polygon.
        drawPolygon(mapView: mapView, coordinates: coordinates)
    }

    
    // Function to draw the polygon on the map, based on the coordinates.
    func drawPolygon (mapView: MKMapView, coordinates: [CLLocationCoordinate2D]) {
        let polygon = MKPolygon(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(polygon)
    }
    
    
    func showReady (mapView: MKMapView) {
        let areaDatabase = AreaDatabase()
        let list = areaDatabase.getAll()
        print (list.count)
        for coordinates in list {
            drawPolygon(mapView: mapView, coordinates: coordinates)
        }
    }
    
    
    func hideReady (mapView: MKMapView) {
        for polygon in mapView.overlays {
            guard polygon is MKPolygon else { continue }
            mapView.removeOverlay(polygon)
        }
    }


}


func getImageName(view: DraggableAnnotationView, selected: Bool, dragging: Bool) -> String
{
    var index : Int = 0
    if let draggableAnnotation = view.annotation as? DraggableAnnotation {
        index = draggableAnnotation.index
    }
    if index >= 0 {
        // The image intends to show that the polygon vertex is draggable.
        if selected {
            return "arrow.up.and.down.and.arrow.left.and.right"
        }
    }
    // Image for the reject button.
    if index == rejectIndex {
        return "xmark.circle"
    }
    // Image for the accept button.
    if index == acceptIndex {
        return "checkmark.circle"
    }
    // Default image for the polygon vertices.
    return "circle.fill"
}


func getImageScale(view: DraggableAnnotationView, dragging: Bool) -> CGFloat
{
    var index : Int = 0
    if let draggableAnnotation = view.annotation as? DraggableAnnotation {
        index = draggableAnnotation.index
    }
    if index >= 0 {
        if dragging {
            return 1.5
        }
        else {
            return 1.0
        }
    }
    // Size for reject and accept button images.
    return 2.0
}


class DraggableAnnotation: NSObject, MKAnnotation {
    
    var coordinate: CLLocationCoordinate2D
    var index: Int
    
    init(coordinate: CLLocationCoordinate2D, index: Int) {
        self.coordinate = coordinate
        self.index = index
        super.init()
    }
}


class DraggableAnnotationView: MKAnnotationView {
    override var annotation: MKAnnotation? {
        didSet {
            self.isDraggable = true
            self.canShowCallout = false
            updateAppearance()
        }
    }
    
    override func setDragState(_ newState: MKAnnotationView.DragState, animated: Bool) {
        super.setDragState(newState, animated: animated)
        updateAppearance()
    }
    
    private func updateAppearance() {
        let dragging = dragState != .none
        let scale: CGFloat = getImageScale(view: self, dragging: dragging)
        let name = getImageName(view: self, selected: self.isSelected, dragging: dragging)
        self.transform = CGAffineTransform(scaleX: scale, y: scale)
        self.image = UIImage(systemName: name)
    }
}


// A polygon for use while marking an area as ready.
class ReadyPolygon: MKPolygon {
}


