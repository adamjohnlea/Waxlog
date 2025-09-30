//
//  CloudKitSyncMonitor.swift
//  Waxlog
//
//  Created by Adam Lea on 9/29/25.
//

import SwiftUI
import SwiftData
import CloudKit

@Observable
final class CloudKitSyncMonitor {
    private(set) var syncStatus: SyncStatus = .notSyncing
    private(set) var lastSyncDate: Date?
    private(set) var errorMessage: String?
    
    enum SyncStatus {
        case notSyncing
        case syncing
        case completed
        case error
    }
    
    init() {
        // Monitor CloudKit account status
        checkAccountStatus()
    }
    
    private func checkAccountStatus() {
        let container = CKContainer.default()
        
        Task {
            do {
                let accountStatus = try await container.accountStatus()
                
                await MainActor.run {
                    switch accountStatus {
                    case .available:
                        self.syncStatus = .completed
                        self.errorMessage = nil
                    case .noAccount:
                        self.syncStatus = .error
                        self.errorMessage = "No iCloud account signed in"
                    case .restricted:
                        self.syncStatus = .error
                        self.errorMessage = "iCloud account restricted"
                    case .couldNotDetermine:
                        self.syncStatus = .error
                        self.errorMessage = "Could not determine iCloud status"
                    case .temporarilyUnavailable:
                        self.syncStatus = .error
                        self.errorMessage = "iCloud temporarily unavailable"
                    @unknown default:
                        self.syncStatus = .error
                        self.errorMessage = "Unknown iCloud status"
                    }
                }
            } catch {
                await MainActor.run {
                    self.syncStatus = .error
                    self.errorMessage = "Error checking iCloud status: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Sync Status View
struct SyncStatusView: View {
    @State private var syncMonitor = CloudKitSyncMonitor()
    
    var body: some View {
        HStack {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
            
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var statusIcon: String {
        switch syncMonitor.syncStatus {
        case .notSyncing:
            return "icloud"
        case .syncing:
            return "icloud.and.arrow.up"
        case .completed:
            return "icloud.and.arrow.up"
        case .error:
            return "icloud.slash"
        }
    }
    
    private var statusColor: Color {
        switch syncMonitor.syncStatus {
        case .notSyncing:
            return .secondary
        case .syncing:
            return .blue
        case .completed:
            return .green
        case .error:
            return .red
        }
    }
    
    private var statusText: String {
        if let errorMessage = syncMonitor.errorMessage {
            return errorMessage
        }
        
        switch syncMonitor.syncStatus {
        case .notSyncing:
            return "iCloud sync ready"
        case .syncing:
            return "Syncing to iCloud..."
        case .completed:
            return "Synced to iCloud"
        case .error:
            return "Sync error"
        }
    }
}