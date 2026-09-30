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
        let newId = areaDatabase.storeCoordinates(coordinates: coordinates)

        // On failure to store the coordinates, bail out early.
        // It means that the map retains the area as if still working on marking it.
        if newId == nil {
            return
        }
        
        // Keep a copy of the coordinates.
        let newCoordinates = self.coordinates

        // Remove the markers from the map.
        clear(mapView: mapView)
        
        // Call function with data from the database to draw this polygon.
        drawPolygon(mapView: mapView, id: newId!, coordinates: newCoordinates)

        // Remove any existing areas that the new area fully covers.
        for overlay in mapView.overlays {
            guard let existing = overlay as? StoredAreaPolygon, existing.rowid != newId else { continue }
            if polygonFullyContains(outer: newCoordinates, inner: existing.storedCoordinates) {
                areaDatabase.removeArea(id: existing.rowid)
                mapView.removeOverlay(existing)
                print ("Remove polygon", existing.rowid)
            }
        }
    }

    
    // Function to draw the polygon on the map.
    // The polygon stores the rowid and is based on the coordinates.
    func drawPolygon (mapView: MKMapView, id: Int64, coordinates: [CLLocationCoordinate2D]) {
        let polygon = StoredAreaPolygon(coordinates: coordinates, count: coordinates.count)
        polygon.rowid = id
        polygon.storedCoordinates = coordinates
        mapView.addOverlay(polygon)
    }
    
    
    func showReady (mapView: MKMapView) {
        let areaDatabase = AreaDatabase()
        let list = areaDatabase.getAll()
        for entry in list {
            drawPolygon(mapView: mapView, id: entry.id, coordinates: entry.coordinates)
        }
    }
    
    
    func hideReady (mapView: MKMapView) {
        let polygons = mapView.overlays.filter { $0 is StoredAreaPolygon }
        mapView.removeOverlays(polygons)
    }



    // A point-in-polygon test.
    // It uses the ray casting algorithm (also called the even-odd rule).
    // Returns true if this coordinate is inside the polygon. Else false.
    // Methodology
    // Imagine drawing a horizontal ray from the test point out to the east
    // (toward increasing longitude). Count how many polygon edges that ray crosses.
    // - Odd number of crossings:  Point is inside.
    // - Even number of crossings: Point is outside.
    // The code doesn't actually draw a ray.
    // It just checks each edge and flips a boolean (inside.toggle())
    // every time the ray would cross that edge.
    // Note: this checks vertices only,
    // which is a good approximation for the roughly-convex octagons this app draws,
    // but isn't a mathematically exact polygon-in-polygon test
    // for arbitrary self-intersecting shapes.
    // Full correctness would require a proper polygon-clipping library
    // rather than a hand-rolled check.
    private func coordinateInPolygon(_ coordinate: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
        var inside = false
        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let xi = polygon[i].longitude, yi = polygon[i].latitude
            let xj = polygon[j].longitude, yj = polygon[j].latitude
            if ((yi > coordinate.latitude) != (yj > coordinate.latitude)) &&
                (coordinate.longitude < (xj - xi) * (coordinate.latitude - yi) / (yj - yi) + xi) {
                inside.toggle()
            }
            j = i
        }
        return inside
    }


    private func polygonFullyContains(outer: [CLLocationCoordinate2D], inner: [CLLocationCoordinate2D]) -> Bool {
        for coordinate in inner {
            if !coordinateInPolygon(coordinate, polygon: outer) {
                return false
            }
        }
        return true
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


final class DraggableAnnotation: NSObject, MKAnnotation {

    var coordinate: CLLocationCoordinate2D
    var index: Int
    
    init(coordinate: CLLocationCoordinate2D, index: Int) {
        self.coordinate = coordinate
        self.index = index
        super.init()
    }
}


final class DraggableAnnotationView: MKAnnotationView {
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


// A polygon representing an area already stored in the database.
// The polygon subclass carries its database row id and source coordinates.
// This serves to give the map overlay an identity.
final class StoredAreaPolygon: MKPolygon {
     var rowid: Int64 = 0
     var storedCoordinates: [CLLocationCoordinate2D] = []
}
