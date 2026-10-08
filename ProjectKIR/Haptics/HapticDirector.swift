import CoreHaptics
import UIKit

/// Dokunsal geri bildirim — spec 83/219.
/// CoreHaptics varsa zengin desen; yoksa UIFeedbackGenerator'a düşer.
final class HapticDirector {

    private var engine: CHHapticEngine?
    private var enabled = true
    private var supportsHaptics = false

    func start(enabled: Bool) {
        self.enabled = enabled
        supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        guard supportsHaptics else {
            KIRLog.info("CoreHaptics desteklenmiyor — UIFeedbackGenerator fallback.")
            return
        }
        do {
            engine = try CHHapticEngine()
            engine?.resetHandler = { [weak self] in
                try? self?.engine?.start()
            }
            try engine?.start()
        } catch {
            KIRLog.warn("Haptic engine başlatılamadı: \(error.localizedDescription)")
            engine = nil
        }
    }

    func setEnabled(_ on: Bool) { enabled = on }

    // MARK: - Kalıplar
    private func fire(intensity: Float, sharpness: Float, duration: Double) {
        guard enabled else { return }
        if let e = engine {
            let event = CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ], relativeTime: 0, duration: duration)
            if let pattern = try? CHHapticPattern(events: [event], parameters: []) {
                if let player = try? e.makePlayer(with: pattern) {
                    try? player.start(atTime: 0)
                }
            }
        } else {
            // Spec 219 — fallback.
            let style: UIImpactFeedbackGenerator.FeedbackStyle = intensity > 0.6 ? .heavy : (intensity > 0.3 ? .medium : .light)
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        }
    }

    func light() { fire(intensity: 0.25, sharpness: 0.6, duration: 0.05) }
    func medium() { fire(intensity: 0.5, sharpness: 0.5, duration: 0.08) }
    func chargeFull() { fire(intensity: 0.35, sharpness: 0.9, duration: 0.1) }

    /// Rezonans pulsu — güce göre.
    func pulse(power: Float) {
        fire(intensity: min(1, 0.3 + power * 0.6), sharpness: 0.2, duration: 0.2)
    }

    /// Kapı / makine — derin gümbürtü.
    func doorRumble() { fire(intensity: 0.8, sharpness: 0.1, duration: 0.35) }
    func machine() { fire(intensity: 0.6, sharpness: 0.15, duration: 0.3) }

    /// Checkpoint — yumuşak iki vuruş.
    func checkpoint() {
        fire(intensity: 0.3, sharpness: 0.4, duration: 0.08)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
            self?.fire(intensity: 0.45, sharpness: 0.3, duration: 0.1)
        }
    }

    /// Tehlike — sert.
    func danger() { fire(intensity: 0.9, sharpness: 0.8, duration: 0.15) }

    /// Ölüm — yükselen tek vuruş.
    func death() { fire(intensity: 0.7, sharpness: 0.2, duration: 0.5) }
}
