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
// The code below does not use Core Data. It uses SQLite3 straight for better performance.


import Foundation
import SQLite3
import MapKit
import Combine


func areaDatabaseData() -> Data
{
    let areaDatabase = AreaDatabase()
    return areaDatabase.databaseData()
}


func areaDatabaseName() -> String
{
    return "areas.sqlite"
}


final class AreaDatabase {

    private var db: OpaquePointer?


    private func databaseUrl() -> URL?
    {
        let url = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent(areaDatabaseName())
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


    func databaseData() -> Data
    {
        if databaseExists() {
            do {
                let data = try Data(contentsOf: databaseUrl() ?? URL(fileURLWithPath: ""))
                return data
            } catch {
                print(error.localizedDescription)
            }
        }
        return Data()
    }


    private func openDatabase()
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
            CREATE TABLE IF NOT EXISTS areas (
              latitude0 REAL, longitude0 REAL,
              latitude1 REAL, longitude1 REAL,
              latitude2 REAL, longitude2 REAL,
              latitude3 REAL, longitude3 REAL,
              latitude4 REAL, longitude4 REAL,
              latitude5 REAL, longitude5 REAL,
              latitude6 REAL, longitude6 REAL,
              latitude7 REAL, longitude7 REAL
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


    // Store the coordinates and return the rowid on success.
    func storeCoordinates(coordinates: [CLLocationCoordinate2D]) -> Int64?
    {
        // The database accepts eight coordinates, check input data for that.
        if coordinates.count != 8 {
            return nil
        }

        openDatabase()

        let insertStatementString =
        """
        INSERT INTO areas (
          latitude0, longitude0,
          latitude1, longitude1,
          latitude2, longitude2,
          latitude3, longitude3,
          latitude4, longitude4,
          latitude5, longitude5,
          latitude6, longitude6,
          latitude7, longitude7
        ) 
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        var insertStatement: OpaquePointer? = nil
        var insertOffset : Int32 = 0
        var newRowId : Int64? = nil
        if sqlite3_prepare_v2(db, insertStatementString, -1, &insertStatement, nil) == SQLITE_OK {
            for coordinate in coordinates {
                insertOffset += 1
                sqlite3_bind_double(insertStatement, insertOffset, coordinate.latitude)
                insertOffset += 1
                sqlite3_bind_double(insertStatement, insertOffset, coordinate.longitude)
            }
            if sqlite3_step(insertStatement) == SQLITE_DONE {
                newRowId = sqlite3_last_insert_rowid(db)
            }
            sqlite3_finalize(insertStatement)
        }

        closeDatabase()

        return newRowId
    }


    func getAll() -> [(id: Int64, coordinates: [CLLocationCoordinate2D])]
    {
        var list : [(id: Int64, coordinates: [CLLocationCoordinate2D])] = []
        if databaseExists() {
            openDatabase();
            list = getAll(dbptr: db)
            closeDatabase()
        }
        return list
    }


    private func getAll(dbptr: OpaquePointer?)  -> [(id: Int64, coordinates: [CLLocationCoordinate2D])]
    {
        var list : [(id: Int64, coordinates: [CLLocationCoordinate2D])] = []
        // Specify which columns to select to be sure the correct columns are selected.
        // One database may not have an identifier as a primary key, and another one may.
        // The columns specification makes reading from both types reliable.
        let sql =
        """
        SELECT rowid,
        latitude0, longitude0,
        latitude1, longitude1,
        latitude2, longitude2,
        latitude3, longitude3,
        latitude4, longitude4,
        latitude5, longitude5,
        latitude6, longitude6,
        latitude7, longitude7
        FROM areas;
        """
        var statement: OpaquePointer? = nil
        if sqlite3_prepare_v2(dbptr, sql, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = sqlite3_column_int64 (statement, 0)
                var coordinates : [CLLocationCoordinate2D] = []
                for i in 0..<8 {
                    let latitude  = sqlite3_column_double(statement, Int32(1 + i * 2))
                    let longitude = sqlite3_column_double(statement, Int32(2 + i * 2))
                    coordinates.append(CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
                }
                list.append((id: id, coordinates: coordinates))
            }
            sqlite3_finalize(statement)
        }
        return list
    }


    func importAreas(url: URL) -> Bool {

        // Request access to the file in the Files app.
        if url.startAccessingSecurityScopedResource() {

            do {

                // Get the binary content of the URL to import.
                let content: Data = try Data(contentsOf: url)
                url.stopAccessingSecurityScopedResource()

                // The URL of the temporary database to import.
                let url: URL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent("import.sqlite")
                print(url)

                // Save the binary content to the temporary database file.
                try content.write(to: url, options: [.atomic, .completeFileProtection])

                // Open the temporary file as database, with error handling.
                var dbptr: OpaquePointer? = nil
                if sqlite3_open(url.path, &dbptr) != SQLITE_OK {
                    print("Cannot open database")
                    return false
                }

                // Get all coordinates from the temporary database.
                let list_ids_coordinates = getAll(dbptr: dbptr)

                // Close the temporary database.
                if sqlite3_close(dbptr) != SQLITE_OK {
                    print("Cannot close database")
                }

                // Process the import by adding all records into the database.
                for entry in list_ids_coordinates {
                    _ = storeCoordinates(coordinates: entry.coordinates)

                }

                // Remove any duplicates that could be in the database due to multiple imports.
                removeDuplicates()

            } catch {
                print(error.localizedDescription)
                return false
            }
        }

        // Import success.
        return true
    }


    func removeDuplicates()
    {
        openDatabase()

        let sql =
        """
        DELETE FROM areas WHERE rowid NOT IN
        (
        SELECT MIN(rowid) FROM areas GROUP BY
        latitude0, longitude0,
        latitude1, longitude1,
        latitude2, longitude2,
        latitude3, longitude3,
        latitude4, longitude4,
        latitude5, longitude5,
        latitude6, longitude6,
        latitude7, longitude7
        );
        """
        var statement: OpaquePointer? = nil
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_DONE {
                sqlite3_finalize(statement)
            }
        }

        closeDatabase()
    }


    private func closeDatabase()
    {
        if db == nil {
            return
        }
        if sqlite3_close(db) != SQLITE_OK {
            print("Cannot close database")
        }
        db = nil
    }

}
