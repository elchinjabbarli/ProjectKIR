import SpriteKit

/// Su seviyesi kontrolü — spec 23, 37, 256.
/// Üç hazır seviye: LOW / MID / HIGH. Gerçek akışkan simülasyonu yok (spec 23).
final class ValveNode: InteractiveObject {

    enum WaterLevel: String, Codable {
        case low, mid, high
    }

    let targetWaterID: String
    let targetLevel: WaterLevel
    private(set) var isOpen = false
    private let wheel: SKShapeNode
    private let stem: SKShapeNode
    private var sceneRef: GameScene?
    private let freq: ResonanceFrequency

    override var acceptedFrequency: ResonanceFrequency { freq }
    override var isInteractiveActive: Bool { !isOpen }
    override var stateLabel: String { isOpen ? "AKIŞ" : "KAPALI" }

    init(entityID: String, waterID: String, level: WaterLevel, frequency: ResonanceFrequency = .deep) {
        self.targetWaterID = waterID
        self.targetLevel = level
        self.freq = frequency
        wheel = SKShapeNode(circleOfRadius: 20)
        wheel.fillColor = KIRPalette.rust
        wheel.strokeColor = KIRPalette.ash
        wheel.lineWidth = 3
        stem = SKShapeNode(rectOf: CGSize(width: 8, height: 26), cornerRadius: 2)
        stem.fillColor = KIRPalette.ash
        stem.strokeColor = KIRPalette.ash
        stem.position = CGPoint(x: 0, y: 14)
        super.init(entityID: entityID)
        addChild(stem)
        addChild(wheel)
        attachFrequencyMark(color: KIRPalette.color(for: freq), pattern: freq.patternLabel)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) kullanılmıyor") }

    func attachScene(_ scene: GameScene) { sceneRef = scene }

    override func receiveResonance(_ pulse: ResonancePulse) {
        guard !isOpen else { return }
        isOpen = true
        sceneRef?.audio.playValve()
        sceneRef?.haptics.machine()
        // Vana çarkı döner — çevresel tepki (spec 708).
        wheel.run(SKAction.repeatForever(SKAction.rotate(byAngle: .pi, duration: 1.4)))
        sceneRef?.setWaterLevel(waterID: targetWaterID, level: targetLevel)
    }

    override func receiveWrongFrequency(_ pulse: ResonancePulse) {
        ResonanceVisuals.wrongFrequencyRipple(node: self, color: KIRPalette.color(for: pulse.frequency))
        sceneRef?.audio.playWrongFrequency()
    }

    func reset() {
        isOpen = false
        wheel.removeAllActions()
        wheel.zRotation = 0
    }
}
