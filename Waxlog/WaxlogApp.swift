//
//  WaxlogApp.swift
//  Waxlog
//
//  Created by Adam Lea on 9/29/25.
//

import SwiftUI
import SwiftData

@main
struct WaxlogApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            VinylRecord.self,
        ])
        
        // Enable CloudKit sync with proper configuration
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
            // Optional: Print CloudKit container identifier for debugging
            #if DEBUG
            print("📱 CloudKit container configured successfully")
            #endif
            
            return container
        } catch {
            #if DEBUG
            print("❌ Failed to create ModelContainer: \(error)")
            #endif
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Optional: Log CloudKit setup on first appearance
                    #if DEBUG
                    print("🚀 Waxlog launched with CloudKit sync enabled")
                    #endif
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
