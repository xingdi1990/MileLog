//
//  SettingsView.swift
//  MileLog
//
//  Created by Xing Di on 1/23/26.
//

import SwiftUI
import UIKit

// UIKit-backed text field with a Done button above the decimal pad
private struct DecimalTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.keyboardType = .decimalPad
        textField.borderStyle = .roundedRect
        textField.font = .preferredFont(forTextStyle: .body)
        textField.delegate = context.coordinator

        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(title: "Done", style: .done, target: context.coordinator, action: #selector(Coordinator.doneTapped))
        toolbar.items = [spacer, done]
        textField.inputAccessoryView = toolbar

        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: DecimalTextField
        init(_ parent: DecimalTextField) { self.parent = parent }

        @objc func doneTapped() {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let current = textField.text ?? ""
            guard let stringRange = Range(range, in: current) else { return false }
            parent.text = current.replacingCharacters(in: stringRange, with: string)
            return false
        }
    }
}

struct SettingsView: View {
    @AppStorage(SettingsKeys.mileageRate) private var mileageRate: Double = SettingsKeys.defaultRate
    @State private var rateText: String = ""

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

                            DecimalTextField(text: $rateText, placeholder: "0.67")
                                .frame(width: 100, height: 34)
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
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("Settings")
        .onAppear {
            rateText = String(format: "%.3f", mileageRate)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
