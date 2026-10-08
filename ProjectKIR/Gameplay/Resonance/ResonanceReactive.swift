import Foundation

/// Spec 18 — rezonansa duyarlı tüm nesnelerin protokolü.
/// Kapılar, vanalar, aynalar, platformlar, köprüler bunu uygular.
protocol ResonanceReactive: AnyObject {
    /// Bu nesnenin cevap verdiği frekans.
    var acceptedFrequency: ResonanceFrequency { get }

    /// 0–1 duyarlılık — menzil/şiddet ölçeklemesi.
    var resonanceSensitivity: Float { get }

    /// Pulsta ne yapacak?
    func receiveResonance(_ pulse: ResonancePulse)

    /// Yanlış frekansta hafif tepki (spec 385).
    func receiveWrongFrequency(_ pulse: ResonancePulse)
}

extension ResonanceReactive {
    func receiveWrongFrequency(_ pulse: ResonancePulse) {
        // Varsayılan: çok hafif titreme, güçlü tepki yok (spec 18).
    }
}
