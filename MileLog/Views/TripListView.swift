//
//  TripListView.swift
//  MileLog
//
//  Created by Xing Di on 1/23/26.
//

import SwiftUI
import SwiftData

struct TripListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Trip.date, order: .reverse) private var trips: [Trip]
    @State private var showingAddTrip = false

    private var unclassifiedTrips: [Trip] {
        trips.filter { $0.category == .unclassified }
    }

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            if unclassifiedTrips.isEmpty {
                ContentUnavailableView {
                    Label("All Caught Up!", systemImage: "checkmark.circle.fill")
                } description: {
                    Text("No trips to classify. Tap + to log a new trip.")
                }
            } else {
                List {
                    ForEach(unclassifiedTrips) { trip in
                        NavigationLink(destination: AddTripView(tripToEdit: trip)) {
                            TripRowView(trip: trip)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                withAnimation {
                                    setCategory(trip, to: .personal)
                                }
                            } label: {
                                Label("Personal", systemImage: "person.fill")
                            }
                            .tint(.blue)

                            Button(role: .destructive) {
                                deleteTrip(trip)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                withAnimation {
                                    setCategory(trip, to: .business)
                                }
                            } label: {
                                Label("Business", systemImage: "briefcase.fill")
                            }
                            .tint(.green)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Trips")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddTrip = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
            }
        }
        .sheet(isPresented: $showingAddTrip) {
            AddTripView()
        }
    }

    private func setCategory(_ trip: Trip, to category: TripCategory) {
        trip.category = category
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    private func deleteTrip(_ trip: Trip) {
        modelContext.delete(trip)
    }
}

#Preview {
    NavigationStack {
        TripListView()
    }
    .modelContainer(for: Trip.self, inMemory: true)
}
