import Foundation

/// Spec 182/183 — tek zaman kaynağı (Single Source of Truth).
/// Tüm sistemler buradan dt alır; gerçek zaman ile oyun zamanı ayrışır.
final class TimeService {

    private(set) var elapsed: TimeInterval = 0
    private(set) var deltaTime: TimeInterval = 0

    /// Spec 115/669 — ölüm geçişi gibi anlarda zaman yavaşlar.
    var timeScale: Double = 1.0

    /// Spec 226 — sabit adım birikimi.
    private(set) var fixedAccumulator: TimeInterval = 0
    let fixedStep: TimeInterval = 1.0 / 60.0

    private var lastWallTime: TimeInterval = 0
    private var hasLast = false

    func tick(wallTime: TimeInterval) {
        guard hasLast else {
            lastWallTime = wallTime
            hasLast = true
            deltaTime = fixedStep
            return
        }
        var dt = wallTime - lastWallTime
        lastWallTime = wallTime
        // Sekmeleri ve duraklamaları kırpar.
        dt = min(dt, 0.1)
        deltaTime = dt * timeScale
        elapsed += deltaTime
        fixedAccumulator += deltaTime
    }

    /// Sabit adım tüketicileri (fizik) accumulator'ı bu metodla boşaltır.
    func consumeFixedSteps(_ body: (TimeInterval) -> Void) {
        var steps = 0
        while fixedAccumulator >= fixedStep && steps < 5 {
            body(fixedStep)
            fixedAccumulator -= fixedStep
            steps += 1
        }
    }

    func reset() {
        hasLast = false
        fixedAccumulator = 0
        timeScale = 1.0
    }
}
