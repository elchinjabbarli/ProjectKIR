import SpriteKit

/// Frekans kilidi olan kapı — spec 252, 34 (ilk bulmaca).
/// Doğru frekansta açılır; opsiyonel sıra listesi (L04: A→B→C) ve otomatik kapanma.
final class DoorNode: InteractiveObject {

    struct Config {
        var frequency: ResonanceFrequency = .deep
        var sequence: [ResonanceFrequency] = []   // boşsa tek puls yeter
        var openDuration: Double = 1.3
        var autoClose = false
        var staysOpen = true
        var width: CGFloat = 60
        var height: CGFloat = 170
    }

    let config: Config
    private(set) var isOpen = false
    private var sequenceProgress = 0
    private var autoCloseTimer: Double = 0

    private let panel: SKShapeNode
    private var sceneRef: GameScene?

    override var acceptedFrequency: ResonanceFrequency { config.frequency }
    override var isInteractiveActive: Bool { !isOpen }
    override var stateLabel: String { isOpen ? "AÇIK" : "KİLİTLİ" }

    init(entityID: String, config: Config) {
        self.config = config
        panel = SKShapeNode(rectOf: CGSize(width: config.width, height: config.height), cornerRadius: 4)
        panel.fillColor = KIRPalette.ash
        panel.strokeColor = KIRPalette.rust
        panel.lineWidth = 2
        super.init(entityID: entityID)
        addChild(panel)

        let freq = config.sequence.first ?? config.frequency
        attachFrequencyMark(color: KIRPalette.color(for: freq), pattern: freq.patternLabel)

        let body = SKPhysicsBody(rectangleOf: CGSize(width: config.width, height: config.height))
        body.categoryBitMask = PhysicsCategory.world
        body.collisionBitMask = PhysicsCategory.player | PhysicsCategory.debris
        body.contactTestBitMask = PhysicsCategory.none
        body.isDynamic = false
        body.affectedByGravity = false
        physicsBody = body
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) kullanılmıyor") }

    func attachScene(_ scene: GameScene) { sceneRef = scene }

    override func receiveResonance(_ pulse: ResonancePulse) {
        guard !isOpen else { return }
        ResonanceVisuals.shake(node: self, strength: 3)

        // Sıralı kapı — spec 42: A→B→C.
        if !config.sequence.isEmpty {
            let expected = config.sequence[sequenceProgress]
            if pulse.frequency == expected {
                sequenceProgress += 1
                sceneRef?.audio.playSequenceTick(pulse.frequency, index: sequenceProgress)
                panel.strokeColor = KIRPalette.color(for: expected)
                if sequenceProgress >= config.sequence.count {
                    open()
                } else {
                    // Sıradaki frekansı görsel olarak göster.
                    let next = config.sequence[sequenceProgress]
                    childNode(withName: "freqMark")?.run(SKAction.fadeAlpha(to: 0.2, duration: 0.15))
                    updateMark(for: next)
                }
            } else {
                // Yanlış sıra → görünür reset (spec 386).
                sequenceProgress = 0
                sceneRef?.audio.playWrongFrequency()
                let shake = SKAction.sequence([
                    SKAction.moveBy(x: -5, y: 0, duration: 0.05),
                    SKAction.moveBy(x: 5, y: 0, duration: 0.05)
                ])
                panel.run(shake)
                updateMark(for: config.sequence.first ?? config.frequency)
            }
            return
        }
        open()
    }

    private func updateMark(for f: ResonanceFrequency) {
        if let mark = childNode(withName: "freqMark") as? SKLabelNode {
            mark.text = f.patternLabel
            mark.fontColor = KIRPalette.color(for: f)
            mark.alpha = 1
        }
    }

    override func receiveWrongFrequency(_ pulse: ResonancePulse) {
        // Spec 34: yanlış frekansta çok hafif metalik thunk.
        ResonanceVisuals.wrongFrequencyRipple(node: self, color: KIRPalette.color(for: pulse.frequency))
        sceneRef?.audio.playWrongFrequency()
    }

    private func open() {
        guard !isOpen else { return }
        isOpen = true
        sceneRef?.audio.playDoorOpen(acceptedFrequency)
        sceneRef?.haptics.doorRumble()
        // Yukarı kayarak açılır (mekanik his — spec 705).
        let move = SKAction.moveBy(x: 0, y: config.height + 8, duration: config.openDuration)
        move.timingMode = .easeInEaseOut
        panel.run(SKAction.group([move, SKAction.fadeAlpha(to: 0.25, duration: config.openDuration)]))
        physicsBody = nil
        if config.autoClose { autoCloseTimer = 3.5 }
    }

    private func close() {
        isOpen = false
        sequenceProgress = 0
        let move = SKAction.moveBy(x: 0, y: -(config.height + 8), duration: 0.5)
        panel.run(SKAction.group([move, SKAction.fadeAlpha(to: 1, duration: 0.4)]))
        restoreBody()
        sceneRef?.audio.playDoorClose()
    }

    private func restoreBody() {
        let body = SKPhysicsBody(rectangleOf: CGSize(width: config.width, height: config.height))
        body.categoryBitMask = PhysicsCategory.world
        body.collisionBitMask = PhysicsCategory.player | PhysicsCategory.debris
        body.isDynamic = false
        body.affectedByGravity = false
        physicsBody = body
        // Kapı panel yukarı taşındı; konum geri.
        panel.position = .zero
    }

    func update(dt: TimeInterval) {
        if isOpen && config.autoClose {
            autoCloseTimer -= dt
            if autoCloseTimer <= 0 { close() }
        }
    }

    /// Save/respawn için başlangıç durumuna dön (spec 460).
    func reset() {
        removeAllActions()
        panel.removeAllActions()
        panel.position = .zero
        panel.alpha = 1
        isOpen = false
        sequenceProgress = 0
        restoreBody()
        updateMark(for: config.sequence.first ?? config.frequency)
    }

    /// Restore: önceden açılmışsa sessizce açık kal (spec 461).
    func reopenSilently() {
        guard !isOpen else { return }
        isOpen = true
        panel.position = CGPoint(x: 0, y: config.height + 8)
        panel.alpha = 0.25
        physicsBody = nil
    }
}
