//
//  ContentView.swift
//  Waxlog
//
//  Created by Adam Lea on 9/29/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\VinylRecord.dateAdded, order: .reverse)]) 
    private var records: [VinylRecord]
    
    @State private var searchText = ""
    @State private var showingImport = false
    @State private var showingPasteSheet = false
    @State private var selectedFolder = "All"
    @State private var csvImporter = CSVImportService()
    @State private var pastedCSVText = ""
    @State private var artworkDownloader = ArtworkDownloadService()
    
    var filteredRecords: [VinylRecord] {
        var filtered = records
        
        // Filter by folder
        if selectedFolder != "All" {
            filtered = filtered.filter { $0.collectionFolder == selectedFolder }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { record in
                record.artist.localizedCaseInsensitiveContains(searchText) ||
                record.title.localizedCaseInsensitiveContains(searchText) ||
                record.label.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filtered
    }
    
    var folders: [String] {
        let allFolders = Set(records.map { $0.collectionFolder })
        return ["All"] + Array(allFolders).sorted()
    }
    
    var recordsWithoutArtwork: [VinylRecord] {
        records.filter { $0.coverImageData == nil && $0.releaseID != nil }
    }

    var body: some View {
        NavigationSplitView {
            VStack {
                // Import progress view
                if csvImporter.isImporting {
                    ImportProgressView(importer: csvImporter)
                        .padding()
                }
                
                // Artwork download progress view
                if artworkDownloader.isDownloading {
                    ArtworkDownloadProgressView(downloader: artworkDownloader)
                        .padding()
                }
                
                List {
                    // Missing artwork notification
                    if !recordsWithoutArtwork.isEmpty && !artworkDownloader.isDownloading {
                        Section {
                            HStack {
                                Image(systemName: "photo.badge.plus")
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading) {
                                    Text("\(recordsWithoutArtwork.count) records missing artwork")
                                        .font(.subheadline)
                                    Text("Tap to download missing cover art")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button("Download") {
                                    Task {
                                        await downloadMissingArtwork()
                                    }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    
                    // Folder picker section
                    if !folders.isEmpty && folders.count > 1 {
                        Section("Collection") {
                            Picker("Folder", selection: $selectedFolder) {
                                ForEach(folders, id: \.self) { folder in
                                    Text(folder).tag(folder)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                    
                    // Records list
                    Section("Records (\(filteredRecords.count))") {
                        if filteredRecords.isEmpty && records.isEmpty {
                            ContentUnavailableView(
                                "No Records Yet",
                                systemImage: "opticaldisc",
                                description: Text("Import your CSV data or add sample records to get started")
                            )
                        } else if filteredRecords.isEmpty {
                            ContentUnavailableView.search
                        } else {
                            ForEach(filteredRecords) { record in
                                NavigationLink {
                                    VinylRecordDetailView(record: record)
                                } label: {
                                    VinylRecordRow(record: record)
                                }
                            }
                            .onDelete(perform: deleteRecords)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search records")
            .navigationTitle("Waxlog")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    Menu {
                        // File import (works better on device)
                        Button(action: {
                            showingImport = true
                        }) {
                            Label("Import CSV File", systemImage: "square.and.arrow.down")
                        }
                        
                        // Paste CSV data (works great in simulator!)
                        Button(action: {
                            showingPasteSheet = true
                        }) {
                            Label("Paste CSV Data", systemImage: "doc.on.clipboard")
                        }
                        
                        Divider()
                        
                        // Download missing artwork
                        Button(action: {
                            Task { await downloadMissingArtwork() }
                        }) {
                            Label("Download Missing Artwork (\(recordsWithoutArtwork.count))", systemImage: "photo.badge.plus")
                        }
                        .disabled(csvImporter.isImporting || artworkDownloader.isDownloading || recordsWithoutArtwork.isEmpty)
                        
                        Divider()
                        
                        // Sample data options
                        Button(action: importSampleCollection) {
                            Label("Import Sample Collection", systemImage: "square.and.arrow.down.fill")
                        }
                        
                        Button(action: addSampleRecord) {
                            Label("Add Single Sample", systemImage: "plus")
                        }
                        
                        Divider()
                        
                        // Clear all data
                        Button(role: .destructive, action: clearAllRecords) {
                            Label("Clear All Records", systemImage: "trash")
                        }
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .fileImporter(
                isPresented: $showingImport,
                allowedContentTypes: [UTType.commaSeparatedText, UTType.plainText],
                allowsMultipleSelection: false
            ) { result in
                Task {
                    await handleFileImport(result: result)
                }
            }
            .sheet(isPresented: $showingPasteSheet) {
                PasteCSVView(csvText: $pastedCSVText, importer: csvImporter, modelContext: modelContext)
            }
        } detail: {
            VStack {
                Image(systemName: "opticaldisc.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                Text("Select a record")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func addSampleRecord() {
        withAnimation {
            let sampleRecord = VinylRecord(
                catalogNumber: "SAMPLE-001",
                artist: "Sample Artist",
                title: "Sample Album",
                label: "Sample Records",
                format: "LP, Album",
                released: 2025,
                rating: 5,
                collectionFolder: "Vinyl",
                notes: "Sample record for testing"
            )
            modelContext.insert(sampleRecord)
        }
    }
    
    private func importSampleCollection() {
        let sampleRecords = [
            VinylRecord(
                catalogNumber: "FTN 17718",
                artist: "Eef Barzelay",
                title: "Lose Big",
                label: "429 Records",
                format: "CD, Album",
                released: 2008,
                releaseID: 3025182,
                collectionFolder: "CDs"
            ),
            VinylRecord(
                catalogNumber: "AMP-28059",
                artist: "Joe Jackson",
                title: "Night And Day",
                label: "A&M Records",
                format: "LP, Album",
                released: 1982,
                releaseID: 9503024,
                collectionFolder: "Vinyl"
            ),
            VinylRecord(
                catalogNumber: "SW-385",
                artist: "The Beatles",
                title: "Hey Jude (The Beatles Again)",
                label: "Apple Records",
                format: "LP, Comp, RP",
                released: 1970,
                releaseID: 11284685,
                collectionFolder: "Vinyl"
            ),
            VinylRecord(
                catalogNumber: "325795",
                artist: "R.E.M.",
                title: "Green",
                label: "Concord Bicycle Music",
                format: "LP, Album, RE, RM, 25t",
                released: 2016,
                releaseID: 4572285,
                rating: 5,
                collectionFolder: "Vinyl",
                mediaCondition: "Near Mint (NM or M-)",
                sleeveCondition: "Near Mint (NM or M-)",
                notes: "Just testing the notes field for my app using the API"
            )
        ]
        
        withAnimation {
            for record in sampleRecords {
                modelContext.insert(record)
            }
        }
    }
    
    private func downloadMissingArtwork() async {
        let missingRecords = recordsWithoutArtwork
        guard !missingRecords.isEmpty else { return }
        
        await artworkDownloader.downloadArtworkForRecords(missingRecords, modelContext: modelContext)
    }
    
    private func clearAllRecords() {
        withAnimation {
            for record in records {
                modelContext.delete(record)
            }
        }
    }

    private func deleteRecords(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(filteredRecords[index])
            }
        }
    }
    
    private func handleFileImport(result: Result<[URL], Error>) async {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            do {
                try await csvImporter.importFromCSV(fileURL: url, modelContext: modelContext)
            } catch {
                await MainActor.run {
                    csvImporter.errorMessage = error.localizedDescription
                }
            }
            
        case .failure(let error):
            await MainActor.run {
                csvImporter.errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Supporting Views

struct VinylRecordRow: View {
    let record: VinylRecord
    
    var body: some View {
        HStack {
            // Cover art placeholder
            Group {
                if let imageData = record.coverImageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: record.releaseID != nil ? "photo.badge.plus" : "opticaldisc.fill")
                        .foregroundColor(record.releaseID != nil ? .orange : .secondary)
                }
            }
            .frame(width: 50, height: 50)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(record.artist)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(record.title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Text(record.label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack {
                    if let released = record.released {
                        Text("\(released)")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray5))
                            .cornerRadius(4)
                    }
                    
                    if record.rating != nil {
                        Text(record.displayRating)
                            .font(.caption2)
                    }
                }
            }
            
            Spacer()
        }
    }
}

struct ImportProgressView: View {
    @Bindable var importer: CSVImportService
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                ProgressView(value: importer.importProgress)
                    .progressViewStyle(LinearProgressViewStyle())
                
                Text("\(importer.importedCount)/\(importer.totalCount)")
                    .font(.caption)
                    .monospacedDigit()
            }
            
            if !importer.currentlyImporting.isEmpty {
                Text("Importing: \(importer.currentlyImporting)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            if let error = importer.errorMessage {
                Text("Error: \(error)")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

struct ArtworkDownloadProgressView: View {
    @Bindable var downloader: ArtworkDownloadService
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                ProgressView(value: downloader.downloadProgress)
                    .progressViewStyle(LinearProgressViewStyle())
                
                Text("\(downloader.downloadedCount)/\(downloader.totalCount)")
                    .font(.caption)
                    .monospacedDigit()
            }
            
            if !downloader.currentlyDownloading.isEmpty {
                Text("Downloading artwork for: \(downloader.currentlyDownloading)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            if let error = downloader.errorMessage {
                Text("Error: \(error)")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

struct PasteCSVView: View {
    @Binding var csvText: String
    let importer: CSVImportService
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var isImporting = false
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Paste your CSV data below")
                    .font(.headline)
                    .padding()
                
                TextEditor(text: $csvText)
                    .font(.system(.body, design: .monospaced))
                    .border(Color.gray, width: 1)
                    .padding()
                
                if csvText.isEmpty {
                    Text("Tip: Copy your CSV data from a spreadsheet or text file and paste it here. The first line should contain column headers.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                
                Spacer()
            }
            .navigationTitle("Paste CSV Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Import") {
                        Task {
                            await importFromPastedText()
                        }
                    }
                    .disabled(csvText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isImporting)
                }
            }
            .disabled(isImporting)
        }
    }
    
    private func importFromPastedText() async {
        isImporting = true
        defer { isImporting = false }
        
        // Create a temporary file from the pasted text
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("pasted.csv")
        
        do {
            try csvText.write(to: tempURL, atomically: true, encoding: .utf8)
            try await importer.importFromCSV(fileURL: tempURL, modelContext: modelContext)
            
            // Clean up temp file
            try? FileManager.default.removeItem(at: tempURL)
            
            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run {
                // Handle error - you might want to show an alert here
                print("Import error: \(error)")
            }
            
            // Clean up temp file even on error
            try? FileManager.default.removeItem(at: tempURL)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: VinylRecord.self, inMemory: true)
}