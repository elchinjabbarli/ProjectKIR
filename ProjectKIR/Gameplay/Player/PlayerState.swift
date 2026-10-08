import Foundation

/// Oyuncu lokomasyon durumları — spec 471/472.
enum PlayerLocomotion: Equatable {
    case idle
    case running
    case airborne
    case crouching
    case dead
    case cinematicLocked
}

/// Rezonans cihazı durumu — spec 17 (Charge/FullCharge/Release), 478-481.
enum ResonanceChargeState: Equatable {
    case idle
    case charging(progress: Double)
    case release
}

/// Tek karelik oyuncu gözlemi (movement + animator buna göre çalışır).
struct PlayerSnapshot {
    var locomotion: PlayerLocomotion = .idle
    var facingRight = true
    var grounded = false
    var charging = false
    var chargeProgress: Double = 0
    var chargeFull = false
    var inWater = false
}
