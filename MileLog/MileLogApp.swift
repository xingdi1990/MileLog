//
//  MileLogApp.swift
//  MileLog
//
//  Created by Xing Di on 1/23/26.
//

import SwiftUI
import SwiftData

@main
struct MileLogApp: App {
    @StateObject private var tripDetectionManager = TripDetectionManager()
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: Trip.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(tripDetectionManager: tripDetectionManager)
                .onAppear {
                    tripDetectionManager.setModelContext(modelContainer.mainContext)
                }
        }
        .modelContainer(modelContainer)
    }
}
