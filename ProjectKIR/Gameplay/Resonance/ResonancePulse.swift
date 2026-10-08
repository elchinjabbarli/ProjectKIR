import CoreGraphics
import Foundation

/// Spec 17 / 382 — yayılan rezonans pulsu: değer nesnesi.
/// Emitter'dan çıkar, sabit hızla ilerler, yarıçapı büyür, menzil dolunca söner.
struct ResonancePulse {
    let origin: CGPoint
    let direction: CGVector
    let frequency: ResonanceFrequency
    let strength: CGFloat          // 0–1, şarj süresine bağlı
    let maxRange: CGFloat
    let bounces: Int               // Ayna kırılımı sayacı — sonsuz ping-pong önlemi (spec 388)

    var radius: CGFloat = 0
    var alive = true

    init(origin: CGPoint, direction: CGVector, frequency: ResonanceFrequency,
         strength: CGFloat, maxRange: CGFloat, bounces: Int = 0) {
        self.origin = origin
        self.direction = direction
        self.frequency = frequency
        self.strength = strength
        self.maxRange = maxRange
        self.bounces = bounces
    }

    /// Pulsun o anki dalga cephesi.
    var wavefront: CGFloat { radius }

    /// Bir nokta bu pulsun etkisinde mi?
    func reaches(_ point: CGPoint) -> Bool {
        let d = Math2D.distance(origin, point)
        return d <= radius + 26 && d <= maxRange
    }

    mutating func advance(dt: TimeInterval) {
        radius += Tuning.pulseTravelSpeed * CGFloat(dt)
        if radius > maxRange { alive = false }
    }
}

/// Spec 27 — gürültü sistemi: ses olayı aynı zamanda oynanıştır.
struct SoundEvent {
    enum Category: String {
        case movement
        case mechanical
        case resonance
        case impact
        case environment
        case alarm
    }

    let position: CGPoint
    let intensity: Float
    let category: Category

    /// Spec 26 — tipik gürültü skorları.
    static func noiseScore(_ category: Category) -> Float {
        switch category {
        case .movement: return 0.05
        case .impact: return 0.15
        case .resonance: return 0.25
        case .mechanical: return 0.40
        case .environment: return 0.10
        case .alarm: return 0.80
        }
    }
}
