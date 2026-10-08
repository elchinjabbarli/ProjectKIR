import SpriteKit

/// Rezonans köprüsü — spec 22: Edge frekansı bazı yüzeyleri geçici görünür kılar.
/// Aktif pencere içinde platform sağlam olur; süre dolunca söner.
final class ResonanceBridgeNode: InteractiveObject {

    let length: CGFloat
    let duration: Double
    private(set) var isActive = false
    private var activeTimer: Double = 0
    private let slab: SKShapeNode
    private var sceneRef: GameScene?

    override var acceptedFrequency: ResonanceFrequency { .edge }
    override var isInteractiveActive: Bool { !isActive }
    override var stateLabel: String { isActive ? "KÖPRÜ" : "GİZLİ" }

    init(entityID: String, length: CGFloat, angle: CGFloat = 0, duration: Double = 4.5) {
        self.length = length
        self.duration = duration
        slab = SKShapeNode(rectOf: CGSize(width: length, height: 12), cornerRadius: 4)
        slab.fillColor = KIRPalette.edgeColor.withAlphaComponent(0.12)
        slab.strokeColor = KIRPalette.edgeColor.withAlphaComponent(0.35)
        slab.lineWidth = 1.5
        super.init(entityID: entityID)
        zRotation = angle
        addChild(slab)
        attachFrequencyMark(color: KIRPalette.edgeColor,
                            pattern: ResonanceFrequency.edge.patternLabel, above: 24)
        // Başlangıçta kenar ipucu: çok soluk damar (spec 22: tamamen görünmez değil).
        physicsBody = nil
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) kullanılmıyor") }

    func attachScene(_ scene: GameScene) { sceneRef = scene }

    override func receiveResonance(_ pulse: ResonancePulse) {
        guard !isActive else { return }
        isActive = true
        activeTimer = duration
        sceneRef?.audio.playBridgeMaterialize()
        sceneRef?.haptics.light()

        // Cam damarı belirginleşir — spec 22: dünya fiziğiyle ilişkili görünüm.
        let body = SKPhysicsBody(rectangleOf: CGSize(width: length, height: 14))
        body.categoryBitMask = PhysicsCategory.interactive
        body.collisionBitMask = PhysicsCategory.player
        body.isDynamic = false
        body.affectedByGravity = false
        body.friction = 0.9
        physicsBody = body

        slab.fillColor = KIRPalette.edgeColor.withAlphaComponent(0.5)
        slab.strokeColor = KIRPalette.edgeColor
        slab.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.75, duration: 0.30),
            SKAction.fadeAlpha(to: 1.0, duration: 0.30)
        ])))
    }

    override func receiveWrongFrequency(_ pulse: ResonancePulse) {
        // Edge dışı frekanslar köprüyü sadece titretir (spec 385).
        ResonanceVisuals.shake(node: slab, strength: 2)
        sceneRef?.audio.playWrongFrequency()
    }

    func update(dt: TimeInterval) {
        guard isActive else { return }
        activeTimer -= dt
        if activeTimer <= 0.8 && activeTimer > 0 {
            // Sönmeden önce uyarı titremesi.
            slab.alpha = activeTimer.truncatingRemainder(dividingBy: 0.2) < 0.1 ? 0.4 : 1.0
        }
        if activeTimer <= 0 {
            deactivate()
        }
    }

    private func deactivate() {
        isActive = false
        physicsBody = nil
        slab.removeAllActions()
        slab.fillColor = KIRPalette.edgeColor.withAlphaComponent(0.12)
        slab.strokeColor = KIRPalette.edgeColor.withAlphaComponent(0.35)
        slab.alpha = 1
        sceneRef?.audio.playBridgeFade()
    }

    func reset() {
        activeTimer = 0
        deactivate()
    }
}
