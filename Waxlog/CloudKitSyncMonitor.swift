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
    private(set) var syncStatus: SyncStatus = .checking
    private(set) var lastSyncDate: Date?
    private(set) var errorMessage: String?
    private(set) var recordCount: Int = 0
    
    enum SyncStatus {
        case checking
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
                        self.lastSyncDate = Date()
                    case .noAccount:
                        self.syncStatus = .error
                        self.errorMessage = "Please sign in to iCloud in Settings"
                    case .restricted:
                        self.syncStatus = .error
                        self.errorMessage = "iCloud account is restricted"
                    case .couldNotDetermine:
                        self.syncStatus = .error
                        self.errorMessage = "Cannot determine iCloud status"
                    case .temporarilyUnavailable:
                        self.syncStatus = .error
                        self.errorMessage = "iCloud is temporarily unavailable"
                    @unknown default:
                        self.syncStatus = .error
                        self.errorMessage = "Unknown iCloud status"
                    }
                }
            } catch {
                await MainActor.run {
                    self.syncStatus = .error
                    self.errorMessage = "iCloud error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func refresh() {
        syncStatus = .checking
        checkAccountStatus()
    }
}

// MARK: - Sync Status View
struct SyncStatusView: View {
    @State private var syncMonitor = CloudKitSyncMonitor()
    
    var body: some View {
        HStack {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
                .imageScale(.small)
            
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if syncMonitor.syncStatus == .error {
                Button("Retry") {
                    syncMonitor.refresh()
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
        }
    }
    
    private var statusIcon: String {
        switch syncMonitor.syncStatus {
        case .checking:
            return "icloud"
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
        case .checking:
            return .secondary
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
        case .checking:
            return "Checking iCloud status..."
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
