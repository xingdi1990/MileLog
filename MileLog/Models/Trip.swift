//
//  Trip.swift
//  MileLog
//
//  Created by Xing Di on 1/23/26.
//

import Foundation
import SwiftData

enum TripCategory: String, Codable, CaseIterable {
    case unclassified = "Unclassified"
    case business = "Business"
    case personal = "Personal"

    var color: String {
        switch self {
        case .unclassified: return "gray"
        case .business: return "green"
        case .personal: return "blue"
        }
    }
}

@Model
final class Trip {
    var id: UUID
    var date: Date
    var startOdometer: Double
    var endOdometer: Double
    var distance: Double
    var category: TripCategory
    var purpose: String
    var notes: String
    var isAutoDetected: Bool

    var deductibleAmount: Double {
        guard category == .business else { return 0 }
        let rate = UserDefaults.standard.double(forKey: SettingsKeys.mileageRate)
        let effectiveRate = rate > 0 ? rate : SettingsKeys.defaultRate
        return distance * effectiveRate
    }

    init(
        date: Date = .now,
        startOdometer: Double = 0,
        endOdometer: Double = 0,
        distance: Double? = nil,
        category: TripCategory = .unclassified,
        purpose: String = "",
        notes: String = "",
        isAutoDetected: Bool = false
    ) {
        self.id = UUID()
        self.date = date
        self.startOdometer = startOdometer
        self.endOdometer = endOdometer
        self.distance = distance ?? (endOdometer - startOdometer)
        self.category = category
        self.purpose = purpose
        self.notes = notes
        self.isAutoDetected = isAutoDetected
    }
}
