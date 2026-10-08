import SpriteKit

/// Placeholder animasyon — spec 74/75/472/473.
/// Texture yok; squash/stretch, eğim, nefes ve cihaz parlaması ile karakter hissi.
final class PlayerAnimator {

    private var breathePhase: Double = 0
    private var leanTarget: CGFloat = 0
    private var squash = false

    func update(dt: TimeInterval, node: PlayerNode, snapshot: PlayerSnapshot) {
        // Nefes — spec 96 (idle'da hafif görsel nefes)
        breathePhase += dt * 2.2
        let breathe = CGFloat(sin(breathePhase)) * 0.015

        // Koşu eğimi
        switch snapshot.locomotion {
        case .running: leanTarget = 0.10
        case .airborne: leanTarget = 0.02
        case .crouching: leanTarget = 0.0
        default: leanTarget = 0.03
        }
        let currentLean = node.zRotation
        node.zRotation = Math2D.lerp(currentLean, -leanTarget * (node.isFacingRight ? 1 : -1), CGFloat(dt) * 8)

        // Ölçek (squash & stretch)
        var sx: CGFloat = 1.0
        var sy: CGFloat = 1.0
        if snapshot.locomotion == .airborne {
            if node.physicsBody?.velocity.dy ?? 0 > 100 { sy = 1.06; sx = 0.95 }
            else { sy = 0.97; sx = 1.03 }
        } else if snapshot.locomotion == .crouching {
            sy = 0.62
        }
        if snapshot.charging { sy += 0.02 }
        node.yScale = Math2D.damp(node.yScale, sy, smoothing: 0.001, dt: CGFloat(dt)) + breathe * 0.4
        node.xScale = (node.isFacingRight ? 1 : -1) *
            Math2D.damp(abs(node.xScale), sx, smoothing: 0.001, dt: CGFloat(dt))

        // Cihaz parlaması — spec 17/150/480
        let color = KIRPalette.color(for: ResonanceSystem.shared.lastSelectedFrequency)
        node.deviceGlow(CGFloat(snapshot.chargeProgress), color: color)
        node.aimDevice(forward: snapshot.charging)
    }

    func triggerLand(node: PlayerNode, strength: CGFloat) {
        // Spec 12 — inişte kısa squash.
        node.yScale = max(0.55, 1 - min(0.4, strength / 2400))
        node.xScale = (node.isFacingRight ? 1 : -1) * min(1.3, 1 + min(0.3, strength / 2400))
    }

    func triggerJump(node: PlayerNode) {
        node.yScale = 1.12
        node.xScale = (node.isFacingRight ? 1 : -1) * 0.92
    }

    func triggerPulse(node: PlayerNode) {
        // Puls anında minik geri tepme hissi.
        let back = SKAction.sequence([
            SKAction.moveBy(x: node.isFacingRight ? -4 : 4, y: 0, duration: 0.06),
            SKAction.moveBy(x: node.isFacingRight ? 4 : -4, y: 0, duration: 0.10)
        ])
        node.device.run(back)
    }
}
