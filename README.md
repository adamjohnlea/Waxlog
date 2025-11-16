# Waxlog

A modern iOS app for managing your vinyl record and music collection with iCloud sync.

## Overview

Waxlog is a native iOS application built with SwiftUI and SwiftData that helps you catalog, organize, and manage your physical music collection. Import your collection from Discogs CSV exports, automatically download cover artwork, and keep everything synced across your devices with iCloud.

## Features

### Collection Management
- **Import from CSV**: Import your entire collection from Discogs CSV exports
- **Paste CSV Data**: Quick import by pasting CSV data directly (great for simulator testing)
- **Automatic Cover Art**: Downloads album artwork from the Discogs API
- **Search**: Quickly find records by artist, title, or label
- **Folder Organization**: Organize your collection into custom folders (Vinyl, CDs, etc.)
- **Detailed Records**: Track catalog numbers, release years, ratings, and condition

### Data Sync
- **iCloud Sync**: Automatic syncing across all your devices via CloudKit
- **Sync Status Monitor**: Real-time sync status visibility
- **Background Updates**: Receives CloudKit push notifications for data updates

### Record Details
Each record stores:
- Artist, Title, Album
- Label and Catalog Number
- Release Year
- Format (LP, CD, etc.)
- Personal Rating (1-5 stars)
- Media and Sleeve Condition
- Personal Notes
- Cover Artwork
- Collection Folder
- Date Added

## Technical Stack

- **Language**: Swift 5.0
- **UI Framework**: SwiftUI
- **Data Persistence**: SwiftData
- **Cloud Sync**: CloudKit
- **Minimum iOS**: iOS 26.0
- **Platform**: iPhone & iPad (Universal)

## Requirements

- Xcode 26.0 or later
- iOS 26.0 or later
- Apple Developer account (for CloudKit functionality)
- Valid iCloud container setup

## Setup

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd Waxlog
   ```

2. Open the project in Xcode:
   ```bash
   open Waxlog.xcodeproj
   ```

3. Configure your development team:
   - Select the project in the navigator
   - Choose the Waxlog target
   - Update the Development Team to your Apple Developer account

4. CloudKit Setup:
   - The app uses the `iCloud.waxlog` container
   - Ensure iCloud capabilities are enabled
   - CloudKit container will be created automatically on first launch

5. Build and run on your device or simulator

## Usage

### Importing Your Collection

#### From Discogs CSV Export
1. Export your collection from Discogs as CSV
2. Transfer the file to your iOS device
3. In Waxlog, tap the "+" menu
4. Select "Import CSV File"
5. Choose your CSV file
6. Wait for the import to complete

#### Using Paste (Simulator-Friendly)
1. Copy CSV data to clipboard
2. In Waxlog, tap the "+" menu
3. Select "Paste CSV Data"
4. The CSV data will be automatically pasted
5. Tap "Import"

### Downloading Artwork
After importing, records with a Discogs Release ID but no artwork will show an orange photo badge. To download:

1. Tap the "+" menu
2. Select "Download Missing Artwork"
3. Or tap the notification banner showing missing artwork count
4. The app will download artwork respecting Discogs API rate limits (60 requests/minute)

### Search and Filter
- Use the search bar to find records by artist, title, or label
- Filter by collection folder using the dropdown in the Collection section
- Sort is automatically by date added (newest first)

### Adding Sample Data
For testing or demonstration:
- **Single Sample**: Adds one test record
- **Sample Collection**: Adds 4 diverse sample records with different formats

## Project Structure

```
Waxlog/
├── WaxlogApp.swift              # App entry point, CloudKit configuration
├── VinylRecord.swift            # Data model with SwiftData
├── ContentView.swift            # Main view with list and navigation
├── VinylRecordDetailView.swift  # Detail view for individual records
├── CSVImportService.swift       # CSV parsing and artwork download
├── CloudKitSyncMonitor.swift    # iCloud sync status monitoring
├── Item.swift                   # (Legacy, can be removed)
├── Waxlog.entitlements         # CloudKit and iCloud entitlements
└── Info.plist                  # Background modes configuration
```

## Architecture

### Data Layer
- **SwiftData**: Modern data persistence with @Model classes
- **CloudKit Integration**: Automatic sync via ModelConfiguration
- **Spotlight Integration**: Records are searchable via iOS Spotlight

### Services
- **CSVImportService**: Handles CSV parsing with progress tracking
- **ArtworkDownloadService**: Manages bulk artwork downloads
- **ImageDownloadService**: Downloads individual images from Discogs API with rate limiting and caching
- **CloudKitSyncMonitor**: Monitors iCloud sync state

### UI Components
- **ContentView**: Main list with search, filtering, and toolbar actions
- **VinylRecordRow**: Compact record display with artwork thumbnail
- **VinylRecordDetailView**: Detailed record information
- **ImportProgressView**: Real-time import progress
- **ArtworkDownloadProgressView**: Artwork download status
- **SyncStatusView**: CloudKit sync indicator

## API Integration

### Discogs API
The app integrates with the Discogs API for cover artwork:
- **Endpoint**: `https://api.discogs.com/releases/{releaseID}`
- **Rate Limiting**: 60 requests/minute (enforced with 1.1s delay)
- **Retry Logic**: 3 attempts with exponential backoff for rate limits
- **User-Agent**: Required header for Discogs API compliance

**Note**: No API key required for basic image retrieval, but rate limits apply.

## Known Limitations

- Discogs API has a rate limit of 60 requests/minute
- Large collection imports may take time due to rate limiting
- Requires active internet connection for artwork downloads
- CloudKit sync requires signed-in iCloud account

## Future Enhancements

Potential features for future development:
- [ ] Discogs API authentication for higher rate limits
- [ ] Export collection to CSV
- [ ] Statistics and collection insights
- [ ] Barcode scanning for quick adding
- [ ] Custom sorting options
- [ ] Collection value tracking
- [ ] Wishlist functionality

## Contributing

This is a personal project, but suggestions and bug reports are welcome via GitHub issues.

## License

[Add your license information here]

## Credits

- Built by Adam Lea
- Powered by Discogs API for artwork
- Uses Apple's SwiftUI, SwiftData, and CloudKit frameworks

## Contact

[Add your contact information or links here]

---

**Note**: This app is not affiliated with or endorsed by Discogs. It uses publicly available CSV export data and the Discogs API in accordance with their terms of service.
