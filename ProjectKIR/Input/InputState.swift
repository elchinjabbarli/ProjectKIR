import Foundation

/// Tüm girdi kaynaklarının doldurduğu birleşik model — spec 80 (Input Abstraction).
/// Girdi mimarisi tek noktadan: dokunmatik, klavye ve kontrolcü bunu üretir,
/// PlayerController bunu tüketir.
struct InputState {
    // Hareket
    var moveX: CGFloat = 0

    // Zıplama
    var jumpHeld = false
    var jumpPressedThisFrame = false

    // Eğilme (low-ceiling — spec 56)
    var crouchHeld = false

    // Rezonans — spec 17/384: hold ile şarj, bırak → puls.
    var chargeHeld = false
    var chargeReleasedThisFrame = false
    var chargeJustStarted = false

    // Frekans geçişi — spec 384.
    var frequencyStep: Int = 0        // +1 / -1 döngüsel
    var frequencyDirect: ResonanceFrequency?

    // Duraklat / etkileşim / debug
    var pausePressedThisFrame = false
    var interactPressedThisFrame = false
    var debugTogglePressed = false

    /// Cinematic lock sırasında girdi yutulur — spec 261.
    var locked = false

    mutating func beginFrame() {
        jumpPressedThisFrame = false
        chargeReleasedThisFrame = false
        chargeJustStarted = false
        frequencyStep = 0
        frequencyDirect = nil
        pausePressedThisFrame = false
        interactPressedThisFrame = false
        debugTogglePressed = false
    }

    mutating func lock() {
        locked = true
        moveX = 0
        jumpHeld = false
        crouchHeld = false
        chargeHeld = false
    }

    /// Sinematik kilit bitti — girdi yeniden serbest (spec 261).
    mutating func unlock() {
        locked = false
    }
}
