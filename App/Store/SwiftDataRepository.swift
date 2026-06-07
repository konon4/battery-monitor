import Foundation
import SwiftData
import BatteryCore

/// SwiftData-backed ``SampleRepository``, bound to the main context.
///
/// Battery captures are infrequent and small, so a main-context repository keeps the code
/// simple and correct; the Repository protocol still isolates the rest of the app from
/// SwiftData (and lets tests use the in-memory implementation).
@MainActor
final class SwiftDataRepository: SampleRepository {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    private func entity(forSerial serial: String) throws -> DeviceProfileEntity? {
        var d = FetchDescriptor<DeviceProfileEntity>(predicate: #Predicate { $0.serial == serial })
        d.fetchLimit = 1
        return try context.fetch(d).first
    }

    func profiles() throws -> [DeviceProfile] {
        try context.fetch(FetchDescriptor<DeviceProfileEntity>()).map(\.asProfile)
    }

    func upsert(profile: DeviceProfile) throws {
        if let existing = try entity(forSerial: profile.id) {
            existing.apply(profile)
        } else {
            context.insert(DeviceProfileEntity(profile: profile))
        }
        try context.save()
    }

    func allSamples() throws -> [BatterySample] {
        try context.fetch(FetchDescriptor<BatterySampleEntity>()).map(\.asSample)
    }

    func samples(forDevice serial: String) throws -> [BatterySample] {
        let d = FetchDescriptor<BatterySampleEntity>(
            predicate: #Predicate { $0.deviceSerial == serial },
            sortBy: [SortDescriptor(\.timestamp)])
        return try context.fetch(d).map(\.asSample)
    }

    func add(sample: BatterySample) throws {
        let entity = BatterySampleEntity(sample: sample)
        entity.device = try self.entity(forSerial: sample.deviceSerial)
        context.insert(entity)
        try context.save()
    }

    func hasSample(forDevice serial: String, near date: Date, window: TimeInterval) throws -> Bool {
        let lower = date.addingTimeInterval(-window)
        let upper = date.addingTimeInterval(window)
        var d = FetchDescriptor<BatterySampleEntity>(
            predicate: #Predicate { $0.deviceSerial == serial && $0.timestamp >= lower && $0.timestamp <= upper })
        d.fetchLimit = 1
        return try !context.fetch(d).isEmpty
    }
}
