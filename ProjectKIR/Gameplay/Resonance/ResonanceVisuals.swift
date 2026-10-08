import SpriteKit

/// Rezonans görsel efektleri — spec 108/109/150.
/// Zarif dalga: distortion yerine genişleyen halka + partikül titremesi.
/// "Patlama değil, dalga." (spec 17)
enum ResonanceVisuals {

    /// Puls salınımda genişleyen halka.
    static func pulseRing(pulse: ResonancePulse, parent: SKNode) {
        let color = KIRPalette.color(for: pulse.frequency)
        let ring = SKShapeNode(circleOfRadius: 26)
        ring.position = pulse.origin
        ring.strokeColor = color.withAlphaComponent(0.85)
        ring.fillColor = SKColor.clear
        ring.lineWidth = 3
        ring.zPosition = 60
        parent.addChild(ring)

        let grow = SKAction.scale(to: max(1.2, pulse.maxRange / 26), duration: 0.75)
        grow.timingMode = .easeOut
        let fade = SKAction.fadeAlpha(to: 0, duration: 0.75)
        let grp = SKAction.group([grow, fade])
        ring.run(SKAction.sequence([grp, SKAction.removeFromParent()]))

        // İç ikinci halka — derinlik hissi.
        let inner = SKShapeNode(circleOfRadius: 12)
        inner.position = pulse.origin
        inner.strokeColor = color.withAlphaComponent(0.5)
        inner.fillColor = SKColor.clear
        inner.lineWidth = 6
        inner.zPosition = 59
        parent.addChild(inner)
        let g2 = SKAction.scale(to: max(0.8, pulse.maxRange / 40), duration: 0.5)
        g2.timingMode = .easeOut
        inner.run(SKAction.sequence([SKAction.group([g2, SKAction.fadeAlpha(to: 0, duration: 0.5)]),
                                     SKAction.removeFromParent()]))
    }

    /// Şarj göstergesi — oyuncunun etrafında minik halka (spec 150).
    static func chargeRing(player: PlayerNode, progress: CGFloat, color: SKColor) {
        if let old = player.childNode(withName: "chargeRing") {
            old.removeFromParent()
        }
        guard progress > 0.02 else { return }
        let r: CGFloat = 40 + 14 * (1 - progress)
        let ring = SKShapeNode(circleOfRadius: r)
        ring.name = "chargeRing"
        ring.strokeColor = color
        ring.fillColor = SKColor.clear
        ring.lineWidth = 2 + 3 * progress
        ring.zRotation = -CGFloat.pi / 2  // saat yönü dolan yay
        // Yay olarak çiz (doluluk oranı).
        let path = CGMutablePath()
        let start = -CGFloat.pi / 2
        let sweep = 2 * CGFloat.pi * progress
        path.addArc(center: .zero, radius: r, startAngle: start, endAngle: start + sweep, clockwise: false)
        ring.path = path
        player.addChild(ring)
        if progress >= 1 {
            ring.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.fadeAlpha(to: 0.5, duration: 0.18),
                SKAction.fadeAlpha(to: 1, duration: 0.18)
            ])))
        }
    }

    /// Nesne titreşimi — rezonans aldığında (spec 18).
    static func shake(node: SKNode, strength: CGFloat = 4) {
        let orig = node.position
        let a = SKAction.moveBy(x: strength, y: 0, duration: 0.04)
        let b = SKAction.moveBy(x: -strength * 2, y: 0, duration: 0.08)
        let c = SKAction.moveBy(x: strength, y: 0, duration: 0.04)
        node.run(SKAction.sequence([a, b, c, SKAction.move(to: orig, duration: 0.01)]))
    }

    /// Yanlış frekans — soluk tek titreme (spec 385).
    static func wrongFrequencyRipple(node: SKNode, color: SKColor) {
        let r = SKShapeNode(circleOfRadius: 18)
        r.strokeColor = color.withAlphaComponent(0.30)
        r.fillColor = SKColor.clear
        r.lineWidth = 2
        node.addChild(r)
        r.run(SKAction.sequence([
            SKAction.group([SKAction.scale(to: 2.2, duration: 0.35),
                            SKAction.fadeAlpha(to: 0, duration: 0.35)]),
            SKAction.removeFromParent()
        ]))
    }

    /// Zincir görselleştirmesi — spec 389: bağlı cihazlar arasında ışık damarı.
    static func chainBeam(from: CGPoint, to: CGPoint, color: SKColor, parent: SKNode) {
        let path = CGMutablePath()
        path.move(to: from)
        path.addLine(to: to)
        let beam = SKShapeNode(path: path)
        beam.strokeColor = color
        beam.lineWidth = 3
        beam.alpha = 0.9
        beam.zPosition = 55
        beam.run(SKAction.sequence([
            SKAction.group([SKAction.fadeAlpha(to: 0, duration: 0.45),
                            SKAction.scale(to: 0.92, duration: 0.45)]),
            SKAction.removeFromParent()
        ]))
        parent.addChild(beam)
    }
}
