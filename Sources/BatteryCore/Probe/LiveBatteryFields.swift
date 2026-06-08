import Foundation

/// The live fields every Android device reports via `dumpsys battery`, with unit
/// conversion. Shared by the probes so each only adds its OEM-specific health source.
struct LiveBatteryFields {
    let level: Int
    let voltage: Double?
    let temperatureC: Double?
    let chargeCounterMAh: Double?
    let currentNowMA: Double?

    init(_ s: DumpsysScanner) {
        level = s.int("level") ?? 0
        voltage = s.double("voltage").map { $0 / 1000.0 }            // mV -> V
        temperatureC = s.double("temperature").map { $0 / 10.0 }     // 0.1°C -> °C
        chargeCounterMAh = s.double("Charge counter").map { $0 / 1000.0 } // µAh -> mAh
        currentNowMA = s.double("current now").map { $0 / 1000.0 }   // µA -> mA
    }
}
