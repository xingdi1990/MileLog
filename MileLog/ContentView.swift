//
//  ContentView.swift
//  MileLog
//
//  Created by Xing Di on 1/23/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @ObservedObject var tripDetectionManager: TripDetectionManager

    var body: some View {
        TabView {
            NavigationStack {
                TripListView()
            }
            .tabItem {
                Label("Trips", systemImage: "car.fill")
            }

            NavigationStack {
                AutoTrackingView(detectionManager: tripDetectionManager)
            }
            .tabItem {
                Label("Auto", systemImage: "location.circle.fill")
            }

            NavigationStack {
                SummaryView()
            }
            .tabItem {
                Label("Summary", systemImage: "chart.pie.fill")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
    }
}

#Preview {
    ContentView(tripDetectionManager: TripDetectionManager())
        .modelContainer(for: Trip.self, inMemory: true)
}
