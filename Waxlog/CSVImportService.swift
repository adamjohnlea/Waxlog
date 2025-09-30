//
//  CSVImportService.swift
//  Waxlog
//
//  Created by Adam Lea on 9/29/25.
//

import Foundation
import SwiftData

@Observable
class CSVImportService {
    var isImporting = false
    var importProgress: Double = 0.0
    var importedCount = 0
    var totalCount = 0
    var currentlyImporting = ""
    var errorMessage: String?
    
    private let imageDownloader = ImageDownloadService()
    
    func importFromCSV(fileURL: URL, modelContext: ModelContext) async throws {
        await MainActor.run {
            isImporting = true
            importProgress = 0.0
            importedCount = 0
            totalCount = 0
            errorMessage = nil
        }
        
        defer {
            Task { @MainActor in
                isImporting = false
                currentlyImporting = ""
            }
        }
        
        // Read CSV file
        let csvContent = try String(contentsOf: fileURL)
        let rows = parseCSV(csvContent)
        
        await MainActor.run {
            totalCount = rows.count
        }
        
        // Process each row
        for (index, row) in rows.enumerated() {
            guard let record = VinylRecord.from(csvRow: row) else {
                continue
            }
            
            await MainActor.run {
                currentlyImporting = "\(record.artist) - \(record.title)"
                importProgress = Double(index + 1) / Double(rows.count)
            }
            
            // Download cover art if we have a release ID
            if let releaseID = record.releaseID {
                do {
                    if let imageData = try await imageDownloader.downloadCoverArt(releaseID: releaseID) {
                        record.coverImageData = imageData
                    }
                } catch {
                    print("Failed to download cover art for \(record.artist) - \(record.title): \(error)")
                    // Continue without image - don't fail the entire import
                }
            }
            
            // Insert record into SwiftData
            modelContext.insert(record)
            
            await MainActor.run {
                importedCount += 1
            }
            
            // Periodic save to avoid memory issues with large imports
            if (index + 1) % 50 == 0 {
                try modelContext.save()
            }
        }
        
        // Final save
        try modelContext.save()
    }
    
    private func parseCSV(_ content: String) -> [[String: String]] {
        let lines = content.components(separatedBy: .newlines)
        guard let headerLine = lines.first else { return [] }
        
        let headers = parseCSVRow(headerLine)
        var results: [[String: String]] = []
        
        for line in lines.dropFirst() {
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            let values = parseCSVRow(line)
            
            var row: [String: String] = [:]
            for (index, header) in headers.enumerated() {
                row[header] = index < values.count ? values[index] : ""
            }
            results.append(row)
        }
        
        return results
    }
    
    private func parseCSVRow(_ line: String) -> [String] {
        var values: [String] = []
        var currentValue = ""
        var insideQuotes = false
        var i = line.startIndex
        
        while i < line.endIndex {
            let char = line[i]
            
            if char == "\"" {
                if insideQuotes && i < line.index(before: line.endIndex) && line[line.index(after: i)] == "\"" {
                    // Escaped quote
                    currentValue += "\""
                    i = line.index(i, offsetBy: 2)
                    continue
                } else {
                    insideQuotes.toggle()
                }
            } else if char == "," && !insideQuotes {
                values.append(currentValue.trimmingCharacters(in: .whitespaces))
                currentValue = ""
            } else {
                currentValue += String(char)
            }
            
            i = line.index(after: i)
        }
        
        values.append(currentValue.trimmingCharacters(in: .whitespaces))
        return values
    }
}

@Observable
class ImageDownloadService {
    private let session = URLSession.shared
    private var cache: [Int: Data] = [:]
    
    func downloadCoverArt(releaseID: Int) async throws -> Data? {
        // Check cache first
        if let cachedData = cache[releaseID] {
            return cachedData
        }
        
        // This is a simplified example - you'll need to implement
        // proper Discogs API integration with authentication
        let discogsURL = "https://api.discogs.com/releases/\(releaseID)"
        
        guard let url = URL(string: discogsURL) else {
            throw ImageDownloadError.invalidURL
        }
        
        var request = URLRequest(url: url)
        // Add User-Agent header required by Discogs API
        request.setValue("WaxlogApp/1.0", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw ImageDownloadError.httpError
            }
            
            // Parse JSON response to get image URL
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let images = json["images"] as? [[String: Any]],
               let firstImage = images.first,
               let imageURLString = firstImage["uri"] as? String,
               let imageURL = URL(string: imageURLString) {
                
                // Download the actual image
                let (imageData, imageResponse) = try await session.data(from: imageURL)
                
                guard let httpImageResponse = imageResponse as? HTTPURLResponse,
                      httpImageResponse.statusCode == 200 else {
                    throw ImageDownloadError.httpError
                }
                
                // Cache the image data
                cache[releaseID] = imageData
                return imageData
            }
            
        } catch {
            throw ImageDownloadError.networkError(error)
        }
        
        return nil
    }
}

enum ImageDownloadError: LocalizedError {
    case invalidURL
    case httpError
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL for image download"
        case .httpError:
            return "HTTP error occurred while downloading image"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}