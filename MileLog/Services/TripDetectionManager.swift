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

    // Debug mode
    #if DEBUG
    @Published var isDebugMode: Bool = false
    private var debugSimulationTimer: Timer?
    private var debugLastLocation: CLLocation?
    #endif

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

        // Only enable background updates if we have Always authorization
        // Setting this without Always permission causes a crash
        if locationAuthStatus == .authorizedAlways {
            locationManager?.allowsBackgroundLocationUpdates = true
        }
        locationManager?.startUpdatingLocation()
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
            category: .business,
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

    // MARK: - Debug Mode

    #if DEBUG
    func debugStartSimulatedTrip() {
        guard isDebugMode else { return }

        // Reset any existing state
        debugStopSimulation()

        state = .detecting
        errorMessage = nil

        // Quickly move to tracking after 1 second
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self, self.isDebugMode else { return }
            self.state = .tracking
            self.tripStartTime = Date()
            self.tripLocations = []
            self.currentDistance = 0

            // Start simulating location updates
            self.debugStartLocationSimulation()
        }
    }

    private func debugStartLocationSimulation() {
        // Simulate starting location (San Francisco)
        debugLastLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)

        // Update location every 2 seconds, simulating ~30 mph driving
        debugSimulationTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.debugSimulateLocationUpdate()
            }
        }
    }

    private func debugSimulateLocationUpdate() {
        guard state == .tracking, let lastLocation = debugLastLocation else { return }

        // Move roughly 0.015 miles (~80 feet) per update, simulating ~30 mph
        // Add some randomness to make it realistic
        let latChange = Double.random(in: 0.0001...0.0003)
        let lonChange = Double.random(in: 0.0001...0.0003)

        let newLocation = CLLocation(
            latitude: lastLocation.coordinate.latitude + latChange,
            longitude: lastLocation.coordinate.longitude + lonChange
        )

        let distance = newLocation.distance(from: lastLocation)
        currentDistance += distance / 1609.34 // Convert meters to miles

        tripLocations.append(newLocation)
        debugLastLocation = newLocation
    }

    func debugStopSimulatedTrip() {
        guard isDebugMode else { return }

        debugStopSimulation()

        if currentDistance > 0.1 {
            saveCurrentTrip()
        } else {
            state = .idle
            currentDistance = 0
            tripLocations = []
        }
    }

    private func debugStopSimulation() {
        debugSimulationTimer?.invalidate()
        debugSimulationTimer = nil
        debugLastLocation = nil
    }

    func debugAddMiles(_ miles: Double) {
        guard isDebugMode, state == .tracking else { return }
        currentDistance += miles
    }
    #endif
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
