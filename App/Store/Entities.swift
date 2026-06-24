import Foundation
import SwiftData
import BatteryCore

/// SwiftData persistence model for a device profile.
@Model
final class DeviceProfileEntity {
    @Attribute(.unique) var serial: String
    var model: String
    var codename: String
    var manufacturer: String

    var label: String
    var designCapacityMAh: Int?
    var firstUseDate: Date?
    var cellManufactureDate: Date?
    /// Raw value of `BatteryChemistry`; defaulted so SwiftData migrates older stores.
    var chemistryRaw: String = BatteryChemistry.graphite.rawValue

    @Relationship(deleteRule: .cascade, inverse: \BatterySampleEntity.device)
    var samples: [BatterySampleEntity] = []

    init(profile: DeviceProfile) {
        self.serial = profile.identity.serial
        self.model = profile.identity.model
        self.codename = profile.identity.codename
        self.manufacturer = profile.identity.manufacturer
        self.label = profile.label
        self.designCapacityMAh = profile.designCapacityMAh
        self.firstUseDate = profile.firstUseDate
        self.cellManufactureDate = profile.cellManufactureDate
        self.chemistryRaw = profile.chemistry.rawValue
    }

    func apply(_ profile: DeviceProfile) {
        label = profile.label
        designCapacityMAh = profile.designCapacityMAh
        firstUseDate = profile.firstUseDate
        cellManufactureDate = profile.cellManufactureDate
        chemistryRaw = profile.chemistry.rawValue
    }

    var identity: DeviceIdentity {
        DeviceIdentity(serial: serial, model: model, codename: codename, manufacturer: manufacturer)
    }

    var asProfile: DeviceProfile {
        DeviceProfile(identity: identity, label: label, designCapacityMAh: designCapacityMAh,
                      firstUseDate: firstUseDate, cellManufactureDate: cellManufactureDate,
                      chemistry: BatteryChemistry(rawValue: chemistryRaw) ?? .graphite)
    }
}

/// SwiftData persistence model for a single battery sample.
@Model
final class BatterySampleEntity {
    var sampleID: UUID
    var deviceSerial: String
    var timestamp: Date
    var levelPercent: Int
    var voltage: Double?
    var temperatureC: Double?
    var chargeCounterMAh: Double?
    var currentNowMA: Double?
    var healthPercent: Double?
    var bsoh: Double?
    var cycleCount: Int?
    var estimatedFullCapacityMAh: Double?

    var device: DeviceProfileEntity?

    init(sample: BatterySample) {
        self.sampleID = sample.id
        self.deviceSerial = sample.deviceSerial
        self.timestamp = sample.timestamp
        self.levelPercent = sample.levelPercent
        self.voltage = sample.voltage
        self.temperatureC = sample.temperatureC
        self.chargeCounterMAh = sample.chargeCounterMAh
        self.currentNowMA = sample.currentNowMA
        self.healthPercent = sample.healthPercent
        self.bsoh = sample.bsoh
        self.cycleCount = sample.cycleCount
        self.estimatedFullCapacityMAh = sample.estimatedFullCapacityMAh
    }

    var asSample: BatterySample {
        BatterySample(id: sampleID, deviceSerial: deviceSerial, timestamp: timestamp,
                      levelPercent: levelPercent, voltage: voltage, temperatureC: temperatureC,
                      chargeCounterMAh: chargeCounterMAh, currentNowMA: currentNowMA,
                      healthPercent: healthPercent, bsoh: bsoh, cycleCount: cycleCount,
                      estimatedFullCapacityMAh: estimatedFullCapacityMAh)
    }
}
