import SpriteKit

/// Rezonans alıcısı — zincir halkası (spec 20/257/258).
/// Doğru frekansta tetiklenir, bağlı olduğu cihazları uyandırır (event system).
final class ReceiverNode: InteractiveObject {

    let frequency: ResonanceFrequency
    private(set) var triggered = false
    private let core: SKShapeNode
    private let ring: SKShapeNode
    private var sceneRef: GameScene?

    override var acceptedFrequency: ResonanceFrequency { frequency }
    override var isInteractiveActive: Bool { !triggered }
    override var stateLabel: String { triggered ? "AKTİF" : "PASİF" }

    init(entityID: String, frequency: ResonanceFrequency, linkedIDs: [String] = []) {
        self.frequency = frequency
        self.linkedIDs = linkedIDs
        core = SKShapeNode(circleOfRadius: 14)
        core.fillColor = KIRPalette.ash
        core.strokeColor = KIRPalette.color(for: frequency)
        core.lineWidth = 3
        ring = SKShapeNode(circleOfRadius: 26)
        ring.fillColor = SKColor.clear
        ring.strokeColor = KIRPalette.color(for: frequency).withAlphaComponent(0.35)
        ring.lineWidth = 1.5
        super.init(entityID: entityID)
        addChild(ring)
        addChild(core)
        attachFrequencyMark(color: KIRPalette.color(for: frequency), pattern: frequency.patternLabel, above: 44)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) kullanılmıyor") }

    func attachScene(_ scene: GameScene) { sceneRef = scene }

    override func receiveResonance(_ pulse: ResonancePulse) {
        guard !triggered else { return }
        triggered = true
        sceneRef?.audio.playReceiverTrigger(frequency)
        sceneRef?.haptics.machine()

        core.fillColor = KIRPalette.color(for: frequency)
        ring.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.group([SKAction.scale(to: 1.35, duration: 0.6), SKAction.fadeAlpha(to: 0.4, duration: 0.6)]),
            SKAction.group([SKAction.scale(to: 1.0, duration: 0.6), SKAction.fadeAlpha(to: 0.9, duration: 0.6)])
        ])))

        // Zincir — spec 20: bağlı cihazlara sinyal gönder.
        sceneRef?.triggerChain(from: self, frequency: frequency)
    }

    override func receiveWrongFrequency(_ pulse: ResonancePulse) {
        ResonanceVisuals.wrongFrequencyRipple(node: self, color: KIRPalette.color(for: pulse.frequency))
        sceneRef?.audio.playWrongFrequency()
    }

    func reset() {
        triggered = false
        ring.removeAllActions()
        ring.setScale(1)
        ring.alpha = 1
        core.fillColor = KIRPalette.ash
    }
}
