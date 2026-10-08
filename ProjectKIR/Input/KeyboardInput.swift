import SpriteKit
import UIKit
import GameController

/// Klavye (simülatör/Mac) ve GameController desteği — spec 79.
final class KeyboardInput {

    // Klavye durumu
    private var heldLeft = false
    private var heldRight = false
    private var keyJump = false
    private var keyCrouch = false
    private var keyCharge = false

    // Kontrolcü önceki kare durumu (edge detection)
    private var padFreqNegHeld = false
    private var padFreqPosHeld = false
    private var padPauseHeld = false
    private var padJumpWasDown = false
    private var padChargeWasDown = false

    init() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleControllerConnect),
            name: .GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleControllerDisconnect),
            name: .GCControllerDidDisconnect, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleControllerConnect() {
        KIRLog.info("GameController bağlandı.")
    }

    @objc private func handleControllerDisconnect() {
        // Spec 366 — kopma anında oyun duraklatılır.
        KIRLog.warn("GameController koptu.")
        NotificationCenter.default.post(name: .kirControllerDisconnected, object: nil)
    }

    /// UIKeyCommand / NSEvent key-down.
    func keyDown(_ code: String) {
        switch code {
        case "a", "A", "ArrowLeft": heldLeft = true
        case "d", "D", "ArrowRight": heldRight = true
        case "w", "W", "ArrowUp", " ": keyJump = true
        case "s", "S", "ArrowDown": keyCrouch = true
        case "j", "J": keyCharge = true
        case "escape", "p", "P": NotificationCenter.default.post(name: .kirTogglePause, object: nil)
        case "q", "Q": NotificationCenter.default.post(name: .kirFrequencyStep, object: -1)
        case "e", "E": NotificationCenter.default.post(name: .kirFrequencyStep, object: 1)
        default: break
        }
    }

    func keyUp(_ code: String) {
        switch code {
        case "a", "A", "ArrowLeft": heldLeft = false
        case "d", "D", "ArrowRight": heldRight = false
        case "w", "W", "ArrowUp", " ": keyJump = false
        case "s", "S", "ArrowDown": keyCrouch = false
        case "j", "J": keyCharge = false
        default: break
        }
    }

    /// Her karede InputState'i güncelle — dokunmatikten sonra çağrılır
    /// (klavye/controller dokunmatik boşluğu doldurur).
    func poll(into input: inout InputState) {
        var mx: CGFloat = 0
        if heldLeft { mx -= 1 }
        if heldRight { mx += 1 }
        if mx != 0 { input.moveX = mx }
        if keyJump { input.jumpHeld = true }
        if keyCrouch { input.crouchHeld = true }
        if keyCharge { input.chargeHeld = true }
        pollGamepad(into: &input, keyboardActive: mx != 0 || keyJump || keyCharge)
    }

    private func pollGamepad(into input: inout InputState, keyboardActive: Bool) {
        guard let pad = GCController.controllers().first,
              let gp = pad.extendedGamepad else { return }

        let lx = CGFloat(gp.leftThumbstick.xAxis.value)
        if abs(lx) > 0.18 && !keyboardActive {
            input.moveX = lx
        }
        let padJump = gp.buttonA.isPressed
        let padCrouch = gp.buttonB.isPressed || gp.leftThumbstick.yAxis.value < -0.5
        let padCharge = gp.rightTrigger.value > 0.35

        if padJump { input.jumpHeld = true }
        if padCrouch { input.crouchHeld = true }
        if padCharge { input.chargeHeld = true }

        let lb = gp.leftShoulder.isPressed
        let rb = gp.rightShoulder.isPressed
        if lb && !padFreqNegHeld { NotificationCenter.default.post(name: .kirFrequencyStep, object: -1) }
        if rb && !padFreqPosHeld { NotificationCenter.default.post(name: .kirFrequencyStep, object: 1) }
        padFreqNegHeld = lb
        padFreqPosHeld = rb

        let menu = gp.buttonMenu.isPressed
        if menu && !padPauseHeld { NotificationCenter.default.post(name: .kirTogglePause, object: nil) }
        padPauseHeld = menu
    }
}

extension Notification.Name {
    static let kirTogglePause = Notification.Name("kir.input.togglePause")
    static let kirFrequencyStep = Notification.Name("kir.input.frequencyStep")
    static let kirFrequencyDirect = Notification.Name("kir.input.frequencyDirect")
    static let kirControllerDisconnected = Notification.Name("kir.input.controllerDisconnected")
}
