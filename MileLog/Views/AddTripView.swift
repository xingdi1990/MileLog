//
//  AddTripView.swift
//  MileLog
//
//  Created by Xing Di on 1/23/26.
//

import SwiftUI
import SwiftData

struct AddTripView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKeys.mileageRate) private var mileageRate: Double = SettingsKeys.defaultRate

    // Optional trip for editing mode
    var tripToEdit: Trip?

    var isEditing: Bool { tripToEdit != nil }

    @State private var date = Date()
    @State private var startOdometer = ""
    @State private var endOdometer = ""
    @State private var manualDistance = ""
    @State private var category: TripCategory = .unclassified
    @State private var purpose = ""
    @State private var notes = ""
    @State private var useManualDistance = false

    private var calculatedDistance: Double {
        if useManualDistance {
            return Double(manualDistance) ?? 0
        } else {
            let start = Double(startOdometer) ?? 0
            let end = Double(endOdometer) ?? 0
            return max(0, end - start)
        }
    }

    private var isValid: Bool {
        calculatedDistance > 0
    }

    var body: some View {
        if isEditing {
            // When editing (pushed via NavigationLink), don't wrap in NavigationStack
            formContent
        } else {
            // When adding (presented as sheet), use NavigationStack
            NavigationStack {
                formContent
            }
        }
    }

    private var formContent: some View {
        ZStack {
            LiquidGlassBackground()

            ScrollView {
                VStack(spacing: 20) {
                    // Date picker
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Date", systemImage: "calendar")
                            .font(.headline)
                        DatePicker("", selection: $date, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .glassCard()

                    // Distance input
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Distance", systemImage: "road.lanes")
                            .font(.headline)

                        Picker("Input Method", selection: $useManualDistance) {
                            Text("Odometer").tag(false)
                            Text("Manual").tag(true)
                        }
                        .pickerStyle(.segmented)

                        if useManualDistance {
                            TextField("Miles", text: $manualDistance)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            HStack(spacing: 16) {
                                VStack(alignment: .leading) {
                                    Text("Start")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    TextField("0", text: $startOdometer)
                                        .keyboardType(.decimalPad)
                                        .textFieldStyle(.roundedBorder)
                                }

                                Image(systemName: "arrow.right")
                                    .foregroundStyle(.secondary)

                                VStack(alignment: .leading) {
                                    Text("End")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    TextField("0", text: $endOdometer)
                                        .keyboardType(.decimalPad)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }
                        }

                        if calculatedDistance > 0 {
                            Text(String(format: "%.1f miles", calculatedDistance))
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                        }
                    }
                    .padding()
                    .glassCard()

                    // Category toggle (only show when editing)
                    if isEditing {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Category", systemImage: "tag")
                                .font(.headline)

                            HStack(spacing: 12) {
                                CategoryButton(
                                    title: "Business",
                                    icon: "briefcase.fill",
                                    color: .green,
                                    isSelected: category == .business
                                ) {
                                    withAnimation(.spring(response: 0.3)) {
                                        category = .business
                                    }
                                }

                                CategoryButton(
                                    title: "Personal",
                                    icon: "person.fill",
                                    color: .blue,
                                    isSelected: category == .personal
                                ) {
                                    withAnimation(.spring(response: 0.3)) {
                                        category = .personal
                                    }
                                }
                            }
                        }
                        .padding()
                        .glassCard()
                    }

                    // Purpose and notes
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Details", systemImage: "doc.text")
                            .font(.headline)

                        TextField("Purpose (e.g., Client meeting)", text: $purpose)
                            .textFieldStyle(.roundedBorder)

                        TextField("Notes (optional)", text: $notes, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...6)
                    }
                    .padding()
                    .glassCard()

                    // Deduction preview (only show when editing and business)
                    if isEditing && category == .business && calculatedDistance > 0 {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Estimated Deduction")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(String(format: "$%.2f", calculatedDistance * mileageRate))
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.green)
                            }
                            Spacer()
                            Text(String(format: "@ $%.2f/mi", mileageRate))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .glassCard()
                    }
                }
                .padding()
            }
        }
        .navigationTitle(isEditing ? "Edit Trip" : "Add Trip")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isEditing {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(isEditing ? "Update" : "Save") {
                    saveTrip()
                }
                .fontWeight(.semibold)
                .disabled(!isValid)
            }
        }
        .onAppear {
            if let trip = tripToEdit {
                date = trip.date
                startOdometer = trip.startOdometer > 0 ? String(format: "%.1f", trip.startOdometer) : ""
                endOdometer = trip.endOdometer > 0 ? String(format: "%.1f", trip.endOdometer) : ""
                // If auto-detected trip or no odometer readings, use manual distance mode
                if trip.isAutoDetected || (trip.startOdometer == 0 && trip.endOdometer == 0) {
                    useManualDistance = true
                    manualDistance = String(format: "%.1f", trip.distance)
                }
                category = trip.category
                purpose = trip.purpose
                notes = trip.notes
            }
        }
    }

    private func saveTrip() {
        if let trip = tripToEdit {
            // Update existing trip
            trip.date = date
            trip.startOdometer = Double(startOdometer) ?? 0
            trip.endOdometer = Double(endOdometer) ?? 0
            trip.distance = calculatedDistance
            trip.category = category
            trip.purpose = purpose
            trip.notes = notes
        } else {
            // Create new trip
            let trip = Trip(
                date: date,
                startOdometer: Double(startOdometer) ?? 0,
                endOdometer: Double(endOdometer) ?? 0,
                distance: calculatedDistance,
                category: category,
                purpose: purpose,
                notes: notes
            )
            modelContext.insert(trip)
        }

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        dismiss()
    }
}

struct CategoryButton: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? color.opacity(0.3) : Color.clear)
            .foregroundStyle(isSelected ? color : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? color : Color.secondary.opacity(0.3), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AddTripView()
        .modelContainer(for: Trip.self, inMemory: true)
}
