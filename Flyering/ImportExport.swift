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
import UniformTypeIdentifiers


// The struct conforming to the FileDocument protocol.
// It serializes binary data to and from file.
struct DataDocument: FileDocument {
    
    // By default the document is empty.
    var data: Data = Data()
    
    // A simple initializer that creates a new empty document.
    init(_ data: Data = Data()) {
        self.data = data
    }
    
    // Tell the system the app support only binary data.
    static var readableContentTypes: [UTType] = [.data]
    
    // This initializer loads data that has been saved previously.
    init(configuration: ReadConfiguration) throws {
        if let contents = configuration.file.regularFileContents {
            data = contents
        }
    }
    
    // This will be called when the system wants to write the data to disk.
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}
