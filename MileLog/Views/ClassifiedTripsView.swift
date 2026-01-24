//
//  ClassifiedTripsView.swift
//  MileLog
//
//  Created by Xing Di on 1/23/26.
//

import SwiftUI
import SwiftData

struct ClassifiedTripsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Trip.date, order: .reverse) private var allTrips: [Trip]

    let category: TripCategory

    private var filteredTrips: [Trip] {
        allTrips.filter { $0.category == category }
    }

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            if filteredTrips.isEmpty {
                ContentUnavailableView {
                    Label("No \(category.rawValue) Trips", systemImage: "car.fill")
                } description: {
                    Text("Trips classified as \(category.rawValue.lowercased()) will appear here.")
                }
            } else {
                List {
                    ForEach(filteredTrips) { trip in
                        NavigationLink(destination: AddTripView(tripToEdit: trip)) {
                            TripRowView(trip: trip)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if category == .business {
                                Button {
                                    withAnimation {
                                        setCategory(trip, to: .personal)
                                    }
                                } label: {
                                    Label("Personal", systemImage: "person.fill")
                                }
                                .tint(.blue)
                            } else {
                                Button {
                                    withAnimation {
                                        setCategory(trip, to: .business)
                                    }
                                } label: {
                                    Label("Business", systemImage: "briefcase.fill")
                                }
                                .tint(.green)
                            }

                            Button(role: .destructive) {
                                deleteTrip(trip)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                withAnimation {
                                    setCategory(trip, to: .unclassified)
                                }
                            } label: {
                                Label("Unclassify", systemImage: "arrow.uturn.backward")
                            }
                            .tint(.gray)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("\(category.rawValue) Trips")
    }

    private func setCategory(_ trip: Trip, to newCategory: TripCategory) {
        trip.category = newCategory
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    private func deleteTrip(_ trip: Trip) {
        modelContext.delete(trip)
    }
}

#Preview {
    NavigationStack {
        ClassifiedTripsView(category: .business)
    }
    .modelContainer(for: Trip.self, inMemory: true)
}
