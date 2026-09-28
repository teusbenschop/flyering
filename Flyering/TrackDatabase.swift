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


// Core Data is a layer on top of SQLite that provides a more convenient API.
// The code below uses SQLite3 straight for better performance.


import Foundation
import SQLite3
import MapKit
import Combine


final class TrackDatabase : ObservableObject {
    
    private var db: OpaquePointer?
    
    
    private func databaseUrl() -> URL?
    {
        let url = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent("waypoints.sqlite")
        return url
    }

    
    private func databaseExists() -> Bool
    {
        let url : URL? = databaseUrl()
        if url == nil {
            return false
        }
        return FileManager.default.fileExists(atPath: databaseUrl()!.path)
    }

    
    func openDatabase()
    {
        // If the database is open already, bail out.
        if (db != nil) {
            return
        }

        let url : URL? = databaseUrl()
        if url == nil {
            return
        }

        // If the database exists, just open it, and bail out.
        // This will occur if the database was created in a previous session of the app.
        if databaseExists() {
            if sqlite3_open(url?.path, &db) == SQLITE_OK {
                return
            }
            print("Cannot open database")
            db = nil
            return
        }
        // At this point, the database does not yet exist.

        // Create and open the database.
        if sqlite3_open(url?.path, &db) != SQLITE_OK {
            print("Cannot open database")
            db = nil
            return
        }
        
        // Create the table.
        let createTableString = """
            CREATE TABLE IF NOT EXISTS waypoints (
                latitude REAL,
                longitude REAL
            );
        """
        var createTableStatement: OpaquePointer? = nil
        if sqlite3_prepare_v2(db, createTableString, -1, &createTableStatement, nil) == SQLITE_OK {
            if sqlite3_step(createTableStatement) != SQLITE_DONE {
                print("User table creation failed")
            }
        } else {
            print("User table creation failed")
        }
        sqlite3_finalize(createTableStatement)
    }
    
    
    func storeCoordinate(coordinate: CLLocationCoordinate2D)
    {
        // If the database is not opened, bail out.
        if db == nil {
            return
        }
        // Insert the coordinate into the table.
        let insertStatementString = "INSERT INTO waypoints (latitude, longitude) VALUES (?, ?);"
        var insertStatement: OpaquePointer? = nil
        if sqlite3_prepare_v2(db, insertStatementString, -1, &insertStatement, nil) == SQLITE_OK {
            sqlite3_bind_double(insertStatement, 1, coordinate.latitude)
            sqlite3_bind_double(insertStatement, 2, coordinate.longitude)
            if sqlite3_step(insertStatement) == SQLITE_DONE {
                sqlite3_finalize(insertStatement)
            }
        }
    }
    
    
    func getAll() -> [CLLocationCoordinate2D]
    {
        var coordinates : [CLLocationCoordinate2D] = []
        if databaseExists() {
            let url : URL? = databaseUrl()
            if url != nil {
                // In case, as usual, if this function is called initially,
                // no database is yet open.
                // Open database into local variable.
                var db: OpaquePointer? = nil
                if sqlite3_open(url?.path, &db) == SQLITE_OK {
                    // Read coordinates.
                    let queryStatementString = "SELECT * FROM waypoints;"
                    var queryStatement: OpaquePointer? = nil
                    if sqlite3_prepare_v2(db,  queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
                        while sqlite3_step(queryStatement) == SQLITE_ROW {
                            let latitude = sqlite3_column_double(queryStatement, 0)
                            let longitude = sqlite3_column_double(queryStatement, 1)
                            let coordinate = CLLocationCoordinate2D (latitude: latitude, longitude: longitude)
                            coordinates.append(coordinate)
                        }
                        sqlite3_finalize(queryStatement)
                    }
                    // Close database again.
                    sqlite3_close(db)
                }
            }
        }
        return coordinates
    }
    
    
    func emptyDatabase()
    {
        // If the database is not opened, bail out.
        if db == nil {
            return
        }
        // Remove all data from the table.
        let insertStatementString = "DELETE FROM waypoints;"
        var insertStatement: OpaquePointer? = nil
        if sqlite3_prepare_v2(db, insertStatementString, -1, &insertStatement, nil) == SQLITE_OK {
            if sqlite3_step(insertStatement) == SQLITE_DONE {
                sqlite3_finalize(insertStatement)
            }
        }
    }

    
    func closeDatabase()
    {
        if db == nil {
            return
        }
        if sqlite3_close(db) != SQLITE_OK {
            print("Cannot close database")
        }
        db = nil
    }
    
    
    func eraseDatabase()
    {
        if !databaseExists() {
            return
        }
        let url : URL? = databaseUrl()
        if url == nil {
            return
        }
        do {
            try FileManager.default.removeItem(at: url!)
        } catch {
            print(error)
        }
    }
    
}
