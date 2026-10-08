import UIKit

/// Spec 220/534/550 — cihaz yeteneği ve global konfigürasyon.
enum AppConfiguration {

    static var isDebugBuild: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// Spec 268 — düşük cihazlarda efekt yoğunluğu düşür.
    enum DeviceClass: String { case low, mid, high }

    static var deviceClass: DeviceClass {
        let memory = ProcessInfo.processInfo.physicalMemory
        if memory < 2_500_000_000 { return .low }
        if memory < 5_000_000_000 { return .mid }
        return .high
    }

    /// Parçacık / görsel efekt yoğunluk çarpanı.
    static var effectBudget: CGFloat {
        switch deviceClass {
        case .low: return 0.4
        case .mid: return 0.8
        case .high: return 1.0
        }
    }

    static var appVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return v ?? "0.1"
    }

    static func configure() {
        // Spec 466 — açılışta mümkün olduğunca az iş.
        UIDevice.current.isBatteryMonitoringEnabled = true
        // Spec 330/331 — denge değerleri config'ten yüklenir (kod yeniden derlenmeden ayar).
        BalanceConfig.load()
    }
}
