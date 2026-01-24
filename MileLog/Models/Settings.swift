//
//  Settings.swift
//  MileLog
//
//  Created by Xing Di on 1/23/26.
//

import Foundation
import SwiftUI

enum SettingsKeys {
    static let mileageRate = "mileageRate"
    static let defaultRate: Double = 0.67
}

struct SettingsManager {
    @AppStorage(SettingsKeys.mileageRate) static var mileageRate: Double = SettingsKeys.defaultRate
}
