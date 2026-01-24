//
//  TripDetectionManager.swift
//  MileLog
//
//  Created by Xing Di on 1/23/26.
//

import Foundation
import CoreMotion
import CoreLocation
import SwiftData
import Combine
import UIKit

enum TripDetectionState: String {
    case idle = "Waiting"
    case detecting = "Detecting..."
    case tracking = "Tracking"
    case saving = "Saving..."
}

@MainActor
class TripDetectionManager: NSObject, ObservableObject {
    @Published var isEnabled: Bool = false {
        didSet {
            if isEnabled {
                startMonitoring()
            } else {
                stopMonitoring()
            }
            UserDefaults.standard.set(isEnabled, forKey: "autoTrackingEnabled")
        }
    }

    @Published var state: TripDetectionState = .idle
    @Published var currentDistance: Double = 0
    @Published var errorMessage: String?
    @Published var locationAuthStatus: CLAuthorizationStatus = .notDetermined
    @Published var motionAuthStatus: CMAuthorizationStatus = .notDetermined

    private var activityManager: CMMotionActivityManager?
    private var locationManager: CLLocationManager?
    private var modelContext: ModelContext?

    // Trip tracking state
    private var tripStartTime: Date?
    private var tripLocations: [CLLocation] = []
    private var detectionTimer: Timer?
    private var drivingConfirmationCount = 0
    private let requiredConfirmations = 3 // 30 seconds (10 sec intervals)

    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    override init() {
        super.init()

        // Skip Core Motion/Location setup in preview environment
        guard !ProcessInfo.processInfo.environment.keys.contains("XCODE_RUNNING_FOR_PREVIEWS") else {
            return
        }

        activityManager = CMMotionActivityManager()
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        locationManager?.pausesLocationUpdatesAutomatically = false
        locationManager?.distanceFilter = 10 // Update every 10 meters

        // Restore saved state - don't auto-enable on launch to avoid permission issues
        // isEnabled = UserDefaults.standard.bool(forKey: "autoTrackingEnabled")
        updateAuthStatus()
    }

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    func updateAuthStatus() {
        guard !isPreview else { return }
        locationAuthStatus = locationManager?.authorizationStatus ?? .notDetermined
        motionAuthStatus = CMMotionActivityManager.authorizationStatus()
    }

    func requestPermissions() {
        locationManager?.requestAlwaysAuthorization()
    }

    var hasRequiredPermissions: Bool {
        let locationOK = locationAuthStatus == .authorizedAlways  // Background tracking requires Always authorization
        let motionOK = motionAuthStatus == .authorized
        return locationOK && motionOK
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        guard !isPreview else { return }
        guard CMMotionActivityManager.isActivityAvailable() else {
            errorMessage = "Motion activity not available on this device"
            return
        }

        errorMessage = nil
        state = .idle

        // Start activity monitoring
        activityManager?.startActivityUpdates(to: .main) { [weak self] activity in
            guard let self = self, let activity = activity else { return }
            Task { @MainActor in
                self.handleActivityUpdate(activity)
            }
        }
    }

    private func stopMonitoring() {
        activityManager?.stopActivityUpdates()
        locationManager?.stopUpdatingLocation()
        detectionTimer?.invalidate()
        detectionTimer = nil

        if state == .tracking {
            saveCurrentTrip()
        }

        state = .idle
        currentDistance = 0
        tripLocations = []
        drivingConfirmationCount = 0
    }

    private func handleActivityUpdate(_ activity: CMMotionActivity) {
        switch state {
        case .idle:
            if activity.automotive && activity.confidence != .low {
                state = .detecting
                drivingConfirmationCount = 1
                startDetectionTimer()
            }

        case .detecting:
            if activity.automotive && activity.confidence != .low {
                drivingConfirmationCount += 1
                if drivingConfirmationCount >= requiredConfirmations {
                    startTracking()
                }
            } else if !activity.automotive {
                // Reset if not driving
                state = .idle
                drivingConfirmationCount = 0
                detectionTimer?.invalidate()
            }

        case .tracking:
            if !activity.automotive && activity.stationary && activity.confidence != .low {
                // Stopped driving
                saveCurrentTrip()
            }

        case .saving:
            break
        }
    }

    private func startDetectionTimer() {
        detectionTimer?.invalidate()
        detectionTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            // Timer keeps running to check activity confirmations
        }
    }

    private func startTracking() {
        detectionTimer?.invalidate()
        state = .tracking
        tripStartTime = Date()
        tripLocations = []
        currentDistance = 0

        guard let manager = locationManager else { return }

        // Check for Always authorization before enabling background updates
        // Note: allowsBackgroundLocationUpdates requires:
        // 1. CLAuthorizationStatus.authorizedAlways
        // 2. UIBackgroundModes array containing "location" in Info.plist
        let currentAuthStatus = manager.authorizationStatus
        if currentAuthStatus == .authorizedAlways {
            // Check if UIBackgroundModes contains "location"
            if let backgroundModes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String],
               backgroundModes.contains("location") {
                manager.allowsBackgroundLocationUpdates = true
            }
        }

        manager.startUpdatingLocation()
    }

    private func saveCurrentTrip() {
        guard let modelContext = modelContext,
              currentDistance > 0.1 else { // Minimum 0.1 miles
            state = .idle
            currentDistance = 0
            tripLocations = []
            locationManager?.stopUpdatingLocation()
            return
        }

        state = .saving

        let trip = Trip(
            date: tripStartTime ?? Date(),
            startOdometer: 0,
            endOdometer: 0,
            distance: currentDistance,
            category: .unclassified,
            purpose: "Auto-detected trip",
            notes: "Automatically recorded"
        )
        trip.isAutoDetected = true

        modelContext.insert(trip)

        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to save trip: \(error.localizedDescription)"
        }

        // Reset state
        state = .idle
        currentDistance = 0
        tripLocations = []
        tripStartTime = nil
        locationManager?.stopUpdatingLocation()

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

// MARK: - CLLocationManagerDelegate

extension TripDetectionManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            for location in locations {
                guard location.horizontalAccuracy < 50 else { continue } // Skip inaccurate readings

                if let lastLocation = tripLocations.last {
                    let distance = location.distance(from: lastLocation)
                    currentDistance += distance / 1609.34 // Convert meters to miles
                }
                tripLocations.append(location)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            errorMessage = "Location error: \(error.localizedDescription)"
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            updateAuthStatus()
        }
    }
}
