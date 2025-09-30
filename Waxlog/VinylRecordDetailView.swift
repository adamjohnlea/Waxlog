//
//  VinylRecordDetailView.swift
//  Waxlog
//
//  Created by Adam Lea on 9/29/25.
//

import SwiftUI

struct VinylRecordDetailView: View {
    @Bindable var record: VinylRecord
    @State private var isEditing = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Cover Art Section
                coverArtSection
                
                // Basic Information
                basicInfoSection
                
                // Collection Information
                collectionInfoSection
                
                // Technical Information
                technicalInfoSection
                
                // Notes Section
                if let notes = record.notes, !notes.isEmpty {
                    notesSection(notes)
                }
            }
            .padding()
        }
        .navigationTitle(record.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditing ? "Done" : "Edit") {
                    isEditing.toggle()
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            EditRecordView(record: record)
        }
    }
    
    private var coverArtSection: some View {
        HStack {
            Spacer()
            Group {
                if let imageData = record.coverImageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: "opticaldisc.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: 200, maxHeight: 200)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .shadow(radius: 4)
            Spacer()
        }
    }
    
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Artist")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            Text(record.artist)
                .font(.title)
                .fontWeight(.bold)
            
            Text(record.title)
                .font(.title2)
                .foregroundColor(.secondary)
            
            HStack {
                Label(record.label, systemImage: "tag")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let released = record.released {
                    Label("\(released)", systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            if record.rating != nil {
                HStack {
                    Text("Rating:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(record.displayRating)
                        .font(.subheadline)
                }
            }
        }
    }
    
    private var collectionInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Collection Info")
                .font(.headline)
                .padding(.top)
            
            InfoRow(title: "Folder", value: record.collectionFolder)
            InfoRow(title: "Date Added", value: record.formattedDateAdded)
            
            if let mediaCondition = record.mediaCondition {
                InfoRow(title: "Media Condition", value: mediaCondition)
            }
            
            if let sleeveCondition = record.sleeveCondition {
                InfoRow(title: "Sleeve Condition", value: sleeveCondition)
            }
        }
    }
    
    private var technicalInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Technical Info")
                .font(.headline)
                .padding(.top)
            
            InfoRow(title: "Format", value: record.format)
            InfoRow(title: "Catalog #", value: record.catalogNumber)
            
            if let releaseID = record.releaseID {
                InfoRow(title: "Release ID", value: "\(releaseID)")
            }
        }
    }
    
    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.headline)
                .padding(.top)
            
            Text(notes)
                .font(.body)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
            
            Spacer()
        }
    }
}

struct EditRecordView: View {
    @Bindable var record: VinylRecord
    @Environment(\.dismiss) private var dismiss
    
    @State private var tempRating: Double
    
    init(record: VinylRecord) {
        self.record = record
        self._tempRating = State(initialValue: Double(record.rating ?? 0))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    TextField("Artist", text: $record.artist)
                    TextField("Title", text: $record.title)
                    TextField("Label", text: $record.label)
                    TextField("Format", text: $record.format)
                }
                
                Section("Collection") {
                    TextField("Folder", text: $record.collectionFolder)
                    TextField("Media Condition", text: Binding(
                        get: { record.mediaCondition ?? "" },
                        set: { record.mediaCondition = $0.isEmpty ? nil : $0 }
                    ))
                    TextField("Sleeve Condition", text: Binding(
                        get: { record.sleeveCondition ?? "" },
                        set: { record.sleeveCondition = $0.isEmpty ? nil : $0 }
                    ))
                }
                
                Section("Rating") {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Rating: \(Int(tempRating)) stars")
                            Spacer()
                            Button("Clear") {
                                tempRating = 0
                                record.rating = nil
                            }
                            .foregroundColor(.red)
                        }
                        
                        Slider(value: $tempRating, in: 0...5, step: 1)
                            .onChange(of: tempRating) { _, newValue in
                                record.rating = newValue > 0 ? Int(newValue) : nil
                            }
                    }
                }
                
                Section("Notes") {
                    TextField("Notes", text: Binding(
                        get: { record.notes ?? "" },
                        set: { record.notes = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                    .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    let sampleRecord = VinylRecord(
        catalogNumber: "SAMPLE-001",
        artist: "Sample Artist",
        title: "Sample Album",
        label: "Sample Records",
        format: "LP, Album",
        released: 2025,
        rating: 4,
        collectionFolder: "Vinyl",
        mediaCondition: "Near Mint (NM or M-)",
        sleeveCondition: "Very Good Plus (VG+)",
        notes: "This is a sample record with some notes about it."
    )
    
    NavigationView {
        VinylRecordDetailView(record: sampleRecord)
    }
}