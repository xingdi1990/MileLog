//
//  TripRowView.swift
//  MileLog
//
//  Created by Xing Di on 1/23/26.
//

import SwiftUI

struct TripRowView: View {
    let trip: Trip

    private var categoryColor: Color {
        switch trip.category {
        case .unclassified: return .gray
        case .business: return .green
        case .personal: return .blue
        }
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }

    var body: some View {
        HStack(spacing: 16) {
            // Category indicator
            ZStack {
                Circle()
                    .fill(categoryColor)
                    .frame(width: 12, height: 12)

                if trip.isAutoDetected {
                    Image(systemName: "location.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.white)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(trip.purpose.isEmpty ? "Trip" : trip.purpose)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if trip.isAutoDetected {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(dateFormatter.string(from: trip.date))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.1f mi", trip.distance))
                    .font(.headline)
                    .foregroundStyle(.primary)

                switch trip.category {
                case .business:
                    Text(String(format: "$%.2f", trip.deductibleAmount))
                        .font(.subheadline)
                        .foregroundStyle(.green)
                case .personal:
                    Text(trip.category.rawValue)
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                case .unclassified:
                    Text(trip.category.rawValue)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .glassCard()
    }
}

#Preview {
    ZStack {
        LiquidGlassBackground()
        TripRowView(trip: Trip(
            date: .now,
            distance: 25.5,
            category: .business,
            purpose: "Client Meeting"
        ))
        .padding()
    }
}
