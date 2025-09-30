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
            
            // Skip image download during CSV import to avoid rate limits
            // We'll download images separately with the ArtworkDownloadService
            
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
class ArtworkDownloadService {
    var isDownloading = false
    var downloadProgress: Double = 0.0
    var downloadedCount = 0
    var totalCount = 0
    var currentlyDownloading = ""
    var errorMessage: String?
    
    private let imageDownloader = ImageDownloadService()
    
    func downloadArtworkForRecords(_ records: [VinylRecord], modelContext: ModelContext) async {
        await MainActor.run {
            isDownloading = true
            downloadProgress = 0.0
            downloadedCount = 0
            totalCount = records.count
            errorMessage = nil
        }
        
        defer {
            Task { @MainActor in
                isDownloading = false
                currentlyDownloading = ""
            }
        }
        
        // Process each record
        for (index, record) in records.enumerated() {
            guard let releaseID = record.releaseID else {
                await MainActor.run {
                    downloadedCount += 1
                    downloadProgress = Double(downloadedCount) / Double(totalCount)
                }
                continue
            }
            
            await MainActor.run {
                currentlyDownloading = "\(record.artist) - \(record.title)"
            }
            
            do {
                if let imageData = try await imageDownloader.downloadCoverArt(releaseID: releaseID) {
                    await MainActor.run {
                        record.coverImageData = imageData
                    }
                }
            } catch {
                print("Failed to download cover art for \(record.artist) - \(record.title): \(error)")
                // Continue with other downloads
                if error is ImageDownloadError {
                    await MainActor.run {
                        errorMessage = "Some downloads failed - will continue with others"
                    }
                }
            }
            
            await MainActor.run {
                downloadedCount += 1
                downloadProgress = Double(downloadedCount) / Double(totalCount)
            }
            
            // Save periodically
            if (index + 1) % 10 == 0 {
                do {
                    try modelContext.save()
                } catch {
                    print("Error saving artwork: \(error)")
                }
            }
        }
        
        // Final save
        do {
            try modelContext.save()
        } catch {
            await MainActor.run {
                errorMessage = "Error saving artwork: \(error.localizedDescription)"
            }
        }
    }
}

@Observable
class ImageDownloadService {
    private let session = URLSession.shared
    private var cache: [Int: Data] = [:]
    private var lastRequestTime: Date = Date.distantPast
    private let minimumDelayBetweenRequests: TimeInterval = 1.1 // Just over 1 second for 60/minute limit
    
    func downloadCoverArt(releaseID: Int) async throws -> Data? {
        // Check cache first
        if let cachedData = cache[releaseID] {
            return cachedData
        }
        
        // Retry logic for rate limits
        for attempt in 1...3 {
            do {
                return try await attemptDownload(releaseID: releaseID)
            } catch ImageDownloadError.rateLimited {
                if attempt < 3 {
                    // Wait longer for rate limit
                    let backoffDelay = TimeInterval(attempt * 5) // 5, 10 seconds
                    try? await Task.sleep(nanoseconds: UInt64(backoffDelay * 1_000_000_000))
                    continue
                } else {
                    throw ImageDownloadError.rateLimited
                }
            } catch {
                throw error
            }
        }
        
        return nil
    }
    
    private func attemptDownload(releaseID: Int) async throws -> Data? {
        // Rate limiting - wait if we need to
        await enforceRateLimit()
        
        let discogsURL = "https://api.discogs.com/releases/\(releaseID)"
        
        guard let url = URL(string: discogsURL) else {
            throw ImageDownloadError.invalidURL
        }
        
        var request = URLRequest(url: url)
        // Add proper User-Agent header required by Discogs API
        request.setValue("WaxlogApp/1.0 +https://example.com/contact", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30
        
        let (data, response) = try await session.data(for: request)
        lastRequestTime = Date()
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ImageDownloadError.httpError
        }
        
        // Handle different response codes
        switch httpResponse.statusCode {
        case 200:
            // Success - continue
            break
        case 429:
            // Rate limited
            throw ImageDownloadError.rateLimited
        case 404:
            // Not found - might not have images
            return nil
        default:
            throw ImageDownloadError.httpError
        }
        
        // Parse JSON response to get image URL
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let images = json["images"] as? [[String: Any]],
              let firstImage = images.first,
              let imageURLString = firstImage["uri"] as? String,
              let imageURL = URL(string: imageURLString) else {
            // No images found
            return nil
        }
        
        // Download the actual image (with another rate limit check)
        await enforceRateLimit()
        
        let (imageData, imageResponse) = try await session.data(from: imageURL)
        lastRequestTime = Date()
        
        guard let httpImageResponse = imageResponse as? HTTPURLResponse,
              httpImageResponse.statusCode == 200 else {
            throw ImageDownloadError.httpError
        }
        
        // Cache the image data
        cache[releaseID] = imageData
        return imageData
    }
    
    private func enforceRateLimit() async {
        let timeSinceLastRequest = Date().timeIntervalSince(lastRequestTime)
        if timeSinceLastRequest < minimumDelayBetweenRequests {
            let delayNeeded = minimumDelayBetweenRequests - timeSinceLastRequest
            try? await Task.sleep(nanoseconds: UInt64(delayNeeded * 1_000_000_000))
        }
    }
}

enum ImageDownloadError: LocalizedError {
    case invalidURL
    case httpError
    case rateLimited
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL for image download"
        case .httpError:
            return "HTTP error occurred while downloading image"
        case .rateLimited:
            return "Rate limited - too many requests"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
