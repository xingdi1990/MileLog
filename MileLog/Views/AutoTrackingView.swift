//
//  AutoTrackingView.swift
//  MileLog
//
//  Created by Xing Di on 1/23/26.
//

import SwiftUI
import CoreLocation
import CoreMotion

struct AutoTrackingView: View {
    @ObservedObject var detectionManager: TripDetectionManager

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            ScrollView {
                VStack(spacing: 20) {
                    // Main toggle card
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Auto Trip Detection")
                                    .font(.headline)
                                Text("Automatically track trips when driving is detected")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $detectionManager.isEnabled)
                                .labelsHidden()
                        }

                        if !detectionManager.hasRequiredPermissions && detectionManager.isEnabled {
                            PermissionWarningView(detectionManager: detectionManager)
                        }
                    }
                    .padding()
                    .glassCard()

                    // Status card
                    StatusCard(detectionManager: detectionManager)

                    // Permissions card
                    PermissionsCard(detectionManager: detectionManager)

                    // How it works card
                    HowItWorksCard()

                    // Debug card (only in DEBUG builds)
                    #if DEBUG
                    DebugCard(detectionManager: detectionManager)
                    #endif
                }
                .padding()
            }
        }
        .navigationTitle("Auto Tracking")
        .onAppear {
            detectionManager.updateAuthStatus()
        }
    }
}

struct PermissionWarningView: View {
    @ObservedObject var detectionManager: TripDetectionManager

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Background Access Required")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Text("Auto-tracking needs \"Always\" location permission to detect trips while the app is in the background.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Update in Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct StatusCard: View {
    @ObservedObject var detectionManager: TripDetectionManager

    var statusColor: Color {
        switch detectionManager.state {
        case .idle: return .secondary
        case .detecting: return .orange
        case .tracking: return .green
        case .saving: return .blue
        }
    }

    var statusIcon: String {
        switch detectionManager.state {
        case .idle: return "moon.zzz.fill"
        case .detecting: return "car.side.front.open.fill"
        case .tracking: return "location.fill"
        case .saving: return "square.and.arrow.down.fill"
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: statusIcon)
                    .font(.title2)
                    .foregroundStyle(statusColor)
                    .symbolEffect(.pulse, isActive: detectionManager.state == .tracking)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Status")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(detectionManager.state.rawValue)
                        .font(.headline)
                        .foregroundStyle(statusColor)
                }
                Spacer()
            }

            if detectionManager.state == .tracking {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Current Trip")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.2f miles", detectionManager.currentDistance))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                    }
                    Spacer()
                    Image(systemName: "car.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.green.opacity(0.5))
                }
            }

            if let error = detectionManager.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding()
        .glassCard()
    }
}

struct PermissionsCard: View {
    @ObservedObject var detectionManager: TripDetectionManager

    var locationStatus: (icon: String, color: Color, text: String) {
        switch detectionManager.locationAuthStatus {
        case .authorizedAlways:
            return ("checkmark.circle.fill", .green, "Always")
        case .authorizedWhenInUse:
            return ("exclamationmark.circle.fill", .orange, "When In Use (upgrade needed)")
        case .denied, .restricted:
            return ("xmark.circle.fill", .red, "Denied")
        case .notDetermined:
            return ("questionmark.circle.fill", .secondary, "Not Set")
        @unknown default:
            return ("questionmark.circle.fill", .secondary, "Unknown")
        }
    }

    var motionStatus: (icon: String, color: Color, text: String) {
        switch detectionManager.motionAuthStatus {
        case .authorized:
            return ("checkmark.circle.fill", .green, "Authorized")
        case .denied:
            return ("xmark.circle.fill", .red, "Denied")
        case .restricted:
            return ("exclamationmark.circle.fill", .orange, "Restricted")
        case .notDetermined:
            return ("questionmark.circle.fill", .secondary, "Not Set")
        @unknown default:
            return ("questionmark.circle.fill", .secondary, "Unknown")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Permissions")
                .font(.headline)

            HStack {
                Image(systemName: "location.fill")
                    .foregroundStyle(.blue)
                    .frame(width: 24)
                Text("Location")
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: locationStatus.icon)
                        .foregroundStyle(locationStatus.color)
                    Text(locationStatus.text)
                        .font(.caption)
                        .foregroundStyle(locationStatus.color)
                }
            }

            HStack {
                Image(systemName: "figure.walk")
                    .foregroundStyle(.orange)
                    .frame(width: 24)
                Text("Motion & Fitness")
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: motionStatus.icon)
                        .foregroundStyle(motionStatus.color)
                    Text(motionStatus.text)
                        .font(.caption)
                        .foregroundStyle(motionStatus.color)
                }
            }

            if detectionManager.locationAuthStatus == .notDetermined ||
               detectionManager.motionAuthStatus == .notDetermined {
                Button {
                    detectionManager.requestPermissions()
                } label: {
                    HStack {
                        Image(systemName: "hand.raised.fill")
                        Text("Request Permissions")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            if detectionManager.locationAuthStatus == .denied ||
               detectionManager.motionAuthStatus == .denied {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Image(systemName: "gear")
                        Text("Open Settings")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .glassCard()
    }
}

struct HowItWorksCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("How It Works", systemImage: "info.circle")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                StepRow(number: 1, icon: "figure.walk", text: "Motion sensors detect automotive activity")
                StepRow(number: 2, icon: "clock.fill", text: "Driving confirmed after 30 seconds")
                StepRow(number: 3, icon: "location.fill", text: "GPS tracks your route")
                StepRow(number: 4, icon: "square.and.arrow.down.fill", text: "Trip auto-saves when driving stops")
            }
        }
        .padding()
        .glassCard()
    }
}

struct StepRow: View {
    let number: Int
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 28, height: 28)
                Text("\(number)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.green)
            }

            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#if DEBUG
struct DebugCard: View {
    @ObservedObject var detectionManager: TripDetectionManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "ant.fill")
                    .foregroundStyle(.purple)
                Text("Debug Mode")
                    .font(.headline)
                Spacer()
                Toggle("", isOn: $detectionManager.isDebugMode)
                    .labelsHidden()
                    .tint(.purple)
            }

            if detectionManager.isDebugMode {
                Text("Simulate trips without actually driving. Uses fake location data.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                switch detectionManager.state {
                case .idle, .detecting:
                    Button {
                        detectionManager.debugStartSimulatedTrip()
                    } label: {
                        HStack {
                            Image(systemName: "car.fill")
                            Text("Start Simulated Trip")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                case .tracking:
                    VStack(spacing: 12) {
                        HStack {
                            Text("Simulating drive...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.2f mi", detectionManager.currentDistance))
                                .font(.headline)
                                .foregroundStyle(.green)
                        }

                        HStack(spacing: 12) {
                            Button {
                                detectionManager.debugAddMiles(1.0)
                            } label: {
                                Text("+1 mi")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            Button {
                                detectionManager.debugAddMiles(5.0)
                            } label: {
                                Text("+5 mi")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            Button {
                                detectionManager.debugAddMiles(10.0)
                            } label: {
                                Text("+10 mi")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }

                        Button {
                            detectionManager.debugStopSimulatedTrip()
                        } label: {
                            HStack {
                                Image(systemName: "stop.fill")
                                Text("Stop & Save Trip")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }

                case .saving:
                    HStack {
                        ProgressView()
                        Text("Saving trip...")
                            .font(.caption)
                    }
                }
            }
        }
        .padding()
        .background(Color.purple.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
#endif

#Preview {
    NavigationStack {
        AutoTrackingView(detectionManager: TripDetectionManager())
    }
}
