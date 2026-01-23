//
//  SettingsView.swift
//  MileLog
//
//  Created by Xing Di on 1/23/26.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage(SettingsKeys.mileageRate) private var mileageRate: Double = SettingsKeys.defaultRate
    @State private var rateText: String = ""
    @FocusState private var isEditing: Bool

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            ScrollView {
                VStack(spacing: 20) {
                    // Mileage rate card
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Mileage Rate", systemImage: "dollarsign.circle")
                            .font(.headline)

                        Text("Set the IRS standard mileage rate for tax deductions. The 2024 rate is $0.67 per mile.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            Text("$")
                                .font(.title2)
                                .fontWeight(.semibold)

                            TextField("0.67", text: $rateText)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                                .focused($isEditing)
                                .onChange(of: rateText) { _, newValue in
                                    if let value = Double(newValue), value >= 0 {
                                        mileageRate = value
                                    }
                                }

                            Text("per mile")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .glassCard()

                    // Current rate display
                    VStack(spacing: 8) {
                        Text("Current Rate")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(String(format: "$%.3f/mile", mileageRate))
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .glassCard()

                    // Info card
                    VStack(alignment: .leading, spacing: 12) {
                        Label("About Mileage Rates", systemImage: "info.circle")
                            .font(.headline)

                        Text("The IRS sets standard mileage rates annually for calculating the deductible costs of operating a vehicle for business purposes.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("Check irs.gov for the current year's official rate.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .glassCard()
                }
                .padding()
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            rateText = String(format: "%.3f", mileageRate)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isEditing = false
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
