//
//  HysteriaPortHopping.swift
//  Anywhere
//

import Foundation

struct HysteriaPortHopping: Codable, Hashable, Sendable {
    static let defaultIntervalSeconds = 30

    let portsSpec: String
    let intervalSeconds: Int

    static func make(spec: String, intervalSeconds: Int?) -> HysteriaPortHopping? {
        let trimmed = spec.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let interval = max(1, intervalSeconds ?? defaultIntervalSeconds)
        return HysteriaPortHopping(portsSpec: trimmed, intervalSeconds: interval)
    }
}