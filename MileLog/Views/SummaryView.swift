//
//  SummaryView.swift
//  MileLog
//
//  Created by Xing Di on 1/23/26.
//

import SwiftUI
import SwiftData

struct SummaryView: View {
    @Query private var trips: [Trip]
    @AppStorage(SettingsKeys.mileageRate) private var mileageRate: Double = SettingsKeys.defaultRate

    private var businessTrips: [Trip] {
        trips.filter { $0.category == .business }
    }

    private var personalTrips: [Trip] {
        trips.filter { $0.category == .personal }
    }

    private var totalBusinessMiles: Double {
        businessTrips.reduce(0) { $0 + $1.distance }
    }

    private var totalPersonalMiles: Double {
        personalTrips.reduce(0) { $0 + $1.distance }
    }

    private var totalDeduction: Double {
        businessTrips.reduce(0) { $0 + $1.deductibleAmount }
    }

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            ScrollView {
                VStack(spacing: 20) {
                    // Total deduction card
                    VStack(spacing: 8) {
                        Text("Total Tax Deduction")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Text(String(format: "$%.2f", totalDeduction))
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(.green)

                        Text(String(format: "Rate: $%.2f/mile", mileageRate))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .glassCard()

                    // Stats grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        StatCard(
                            title: "Business Miles",
                            value: String(format: "%.1f", totalBusinessMiles),
                            unit: "mi",
                            color: .green,
                            icon: "briefcase.fill"
                        )

                        StatCard(
                            title: "Personal Miles",
                            value: String(format: "%.1f", totalPersonalMiles),
                            unit: "mi",
                            color: .blue,
                            icon: "person.fill"
                        )

                        NavigationLink(destination: ClassifiedTripsView(category: .business)) {
                            StatCard(
                                title: "Business Trips",
                                value: "\(businessTrips.count)",
                                unit: "trips",
                                color: .green,
                                icon: "car.fill"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink(destination: ClassifiedTripsView(category: .personal)) {
                            StatCard(
                                title: "Personal Trips",
                                value: "\(personalTrips.count)",
                                unit: "trips",
                                color: .blue,
                                icon: "car.fill"
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // Year breakdown (if trips span multiple months)
                    if !trips.isEmpty {
                        MonthlyBreakdownView(trips: businessTrips)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Summary")
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title)
                .fontWeight(.bold)

            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .glassCard()
    }
}

struct MonthlyBreakdownView: View {
    let trips: [Trip]

    private var monthlyData: [(month: String, miles: Double, deduction: Double)] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"

        var grouped: [String: (miles: Double, deduction: Double)] = [:]

        for trip in trips {
            let key = formatter.string(from: trip.date)
            let existing = grouped[key] ?? (miles: 0, deduction: 0)
            grouped[key] = (
                miles: existing.miles + trip.distance,
                deduction: existing.deduction + trip.deductibleAmount
            )
        }

        return grouped.map { (month: $0.key, miles: $0.value.miles, deduction: $0.value.deduction) }
            .sorted { $0.month > $1.month }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Breakdown")
                .font(.headline)

            ForEach(monthlyData, id: \.month) { data in
                HStack {
                    Text(data.month)
                        .font(.subheadline)

                    Spacer()

                    Text(String(format: "%.1f mi", data.miles))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(String(format: "$%.2f", data.deduction))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                        .frame(width: 70, alignment: .trailing)
                }
            }
        }
        .padding()
        .glassCard()
    }
}

#Preview {
    NavigationStack {
        SummaryView()
    }
    .modelContainer(for: Trip.self, inMemory: true)
}
