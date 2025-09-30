//
//  VinylRecord.swift
//  Waxlog
//
//  Created by Adam Lea on 9/29/25.
//

import Foundation
import SwiftData

@Model
final class VinylRecord {
    // CloudKit-friendly identifier (no unique constraint for CloudKit)
    var id: UUID = UUID()
    
    // Basic record information - with default values for CloudKit compatibility
    @Attribute(.spotlight) var catalogNumber: String = ""
    @Attribute(.spotlight) var artist: String = ""
    @Attribute(.spotlight) var title: String = ""
    @Attribute(.spotlight) var label: String = ""
    var format: String = ""
    var released: Int?
    var releaseID: Int?
    
    // Personal collection data
    var rating: Int?
    var collectionFolder: String = "Vinyl"
    var dateAdded: Date = Date()
    var mediaCondition: String?
    var sleeveCondition: String?
    var notes: String?
    
    // Image storage
    var coverImageData: Data?
    var coverImageURL: String?
    
    // Computed properties
    var hasImage: Bool {
        coverImageData != nil
    }
    
    var isValid: Bool {
        !catalogNumber.isEmpty && !artist.isEmpty && !title.isEmpty && !label.isEmpty && !format.isEmpty
    }
    
    var displayRating: String {
        guard let rating = rating else { return "Unrated" }
        return String(repeating: "★", count: rating) + String(repeating: "☆", count: 5 - rating)
    }
    
    var formattedDateAdded: String {
        dateAdded.formatted(date: .numeric, time: .omitted)
    }
    
    // Display versions without Discogs disambiguation numbers
    var displayArtist: String {
        removeDiscogsDisambiguation(from: artist)
    }
    
    var displayLabel: String {
        removeDiscogsDisambiguation(from: label)
    }
    
    // Helper function to remove disambiguation numbers like "(2)" or "(3)"
    private func removeDiscogsDisambiguation(from text: String) -> String {
        // Regular expression to match disambiguation numbers at the end: " (number)"
        let pattern = #"\s\(\d+\)$"#
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(location: 0, length: text.utf16.count)
            return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
        } catch {
            // If regex fails for some reason, return original text
            return text
        }
    }
    
    init(
        catalogNumber: String,
        artist: String,
        title: String,
        label: String,
        format: String,
        released: Int? = nil,
        releaseID: Int? = nil,
        rating: Int? = nil,
        collectionFolder: String = "Vinyl",
        dateAdded: Date = Date(),
        mediaCondition: String? = nil,
        sleeveCondition: String? = nil,
        notes: String? = nil,
        coverImageData: Data? = nil,
        coverImageURL: String? = nil
    ) {
        // Don't override the UUID - let the default value handle it
        self.catalogNumber = catalogNumber
        self.artist = artist
        self.title = title
        self.label = label
        self.format = format
        self.released = released
        self.releaseID = releaseID
        self.rating = rating
        self.collectionFolder = collectionFolder
        self.dateAdded = dateAdded
        self.mediaCondition = mediaCondition
        self.sleeveCondition = sleeveCondition
        self.notes = notes
        self.coverImageData = coverImageData
        self.coverImageURL = coverImageURL
    }
}

// MARK: - Vinyl Record Extensions
extension VinylRecord {
    /// Creates a VinylRecord from CSV row data
    static func from(csvRow: [String: String]) -> VinylRecord? {
        guard let catalogNumber = csvRow["Catalog#"],
              let artist = csvRow["Artist"],
              let title = csvRow["Title"],
              let label = csvRow["Label"],
              let format = csvRow["Format"] else {
            return nil
        }
        
        // Parse optional fields
        let released = Int(csvRow["Released"] ?? "")
        let releaseID = Int(csvRow["release_id"] ?? "")
        let rating = Int(csvRow["Rating"] ?? "")
        let collectionFolder = csvRow["CollectionFolder"] ?? "Vinyl"
        
        // Parse date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let dateAdded = dateFormatter.date(from: csvRow["Date Added"] ?? "") ?? Date()
        
        let mediaCondition = csvRow["Collection Media Condition"]?.isEmpty == false ? csvRow["Collection Media Condition"] : nil
        let sleeveCondition = csvRow["Collection Sleeve Condition"]?.isEmpty == false ? csvRow["Collection Sleeve Condition"] : nil
        let notes = csvRow["Collection Notes"]?.isEmpty == false ? csvRow["Collection Notes"] : nil
        
        return VinylRecord(
            catalogNumber: catalogNumber,
            artist: artist,
            title: title,
            label: label,
            format: format,
            released: released,
            releaseID: releaseID,
            rating: rating,
            collectionFolder: collectionFolder,
            dateAdded: dateAdded,
            mediaCondition: mediaCondition,
            sleeveCondition: sleeveCondition,
            notes: notes
        )
    }
    
    /// Constructs a Discogs API URL for fetching cover art
    var discogsImageURL: String? {
        guard let releaseID = releaseID else { return nil }
        // You'll need to implement Discogs API integration
        // This is a placeholder for the API endpoint
        return "https://api.discogs.com/releases/\(releaseID)"
    }
}
