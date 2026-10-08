import SpriteKit

/// Karşı ağırlık sistemi — spec 43/255: biri yükselirken diğeri iner.
/// Rezonans tetiklediğinde fren geçici çözülür, ağırlık düşer/taşınır.
final class CounterweightNode: InteractiveObject {

    let linkedID: String
    let travel: CGVector
    private(set) var engaged = false
    private let block: SKShapeNode
    private var sceneRef: GameScene?
    private var homePosition: CGPoint = .zero

    override var acceptedFrequency: ResonanceFrequency { .deep }
    override var isInteractiveActive: Bool { !engaged }
    override var stateLabel: String { engaged ? "TAKILI" : "FRENLİ" }

    init(entityID: String, linkedID: String, travel: CGVector, size: CGSize = CGSize(width: 54, height: 54)) {
        self.linkedID = linkedID
        self.travel = travel
        block = SKShapeNode(rectOf: size, cornerRadius: 6)
        block.fillColor = KIRPalette.rust
        block.strokeColor = KIRPalette.ash
        block.lineWidth = 3
        super.init(entityID: entityID)
        addChild(block)
        attachFrequencyMark(color: KIRPalette.deepColor, pattern: ResonanceFrequency.deep.patternLabel, above: 40)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) kullanılmıyor") }

    /// SKNode didMoveToParent()'i Xcode 15.4'te desteklemiyor — override kaldırıldı.
    /// Parent'a eklendiğinde manuel olarak çağrılır (GameScene init).
    func didMoveToParent() { homePosition = position }

    func attachScene(_ scene: GameScene) { sceneRef = scene }

    override func receiveResonance(_ pulse: ResonancePulse) {
        guard !engaged else { return }
        engaged = true
        sceneRef?.audio.playMachineStart()
        sceneRef?.haptics.machine()
        // Ağırlık hareket eder; bağlı partner ters yöne gider (LevelManager eşler).
        let move = SKAction.moveBy(x: travel.dx, y: travel.dy, duration: 1.6)
        move.timingMode = .easeInEaseOut
        run(move)
        childNode(withName: "freqMark")?.run(SKAction.fadeOut(withDuration: 0.4))
        // Çevreye gürültü — spec 27.
        sceneRef?.broadcastSound(SoundEvent(position: position, intensity: SoundEvent.noiseScore(.mechanical), category: .mechanical))
    }

    override func receiveWrongFrequency(_ pulse: ResonancePulse) {
        ResonanceVisuals.wrongFrequencyRipple(node: self, color: KIRPalette.color(for: pulse.frequency))
        sceneRef?.audio.playWrongFrequency()
    }

    func reset() {
        engaged = false
        removeAllActions()
        position = homePosition
        childNode(withName: "freqMark")?.alpha = 1
    }
}
