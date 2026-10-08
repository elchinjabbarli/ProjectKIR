import SpriteKit

/// Rezonans aynası — spec 21/254: gelen sinyali 90° yönlendirir.
/// Pulse aynaya çarpınca yeni bir puls üretilir (yön: mirror açısına göre).
final class MirrorNode: InteractiveObject {

    enum Orientation: String, Codable {
        case up       // yatay gelen → yukarı gider
        case down
        case left
        case right
    }

    var orientation: Orientation
    private let initialOrientation: Orientation   // checkpoint restore için (spec 461)
    private let plate: SKShapeNode
    private var sceneRef: GameScene?

    override var acceptedFrequency: ResonanceFrequency { .edge }
    override var resonanceSensitivity: Float { 0.9 }
    override var isInteractiveActive: Bool { true }
    override var stateLabel: String { "AYNA \(orientation.rawValue)" }

    /// Ayna her frekansta tepki verir (yön değiştirir) — spec 21.
    override var resonatesWithAnyFrequency: Bool { true }

    init(entityID: String, orientation: Orientation) {
        self.orientation = orientation
        self.initialOrientation = orientation
        plate = SKShapeNode(rectOf: CGSize(width: 8, height: 56), cornerRadius: 3)
        plate.fillColor = KIRPalette.dirtyWhite
        plate.strokeColor = KIRPalette.edgeColor
        plate.lineWidth = 2
        super.init(entityID: entityID)
        addChild(plate)
        attachFrequencyMark(color: KIRPalette.edgeColor, pattern: ResonanceFrequency.edge.patternLabel)
        applyOrientation(orientation)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) kullanılmıyor") }

    func attachScene(_ scene: GameScene) { sceneRef = scene }

    private func applyOrientation(_ o: Orientation) {
        let angle: CGFloat
        switch o {
        case .up: angle = 0
        case .right: angle = -.pi / 2
        case .down: angle = .pi
        case .left: angle = .pi / 2
        }
        plate.zRotation = angle
    }

    override func receiveResonance(_ pulse: ResonancePulse) {
        rotate()
    }

    override func receiveWrongFrequency(_ pulse: ResonancePulse) {
        // Ayna her frekansta döner ama yönü yalnızca edge hassasiyetinde net değiştirir.
        rotate()
    }

    /// Bir puls geldi → 90° dön (spec 21: doğru açıda yukarı yönelir).
    func rotate() {
        let next: Orientation
        switch orientation {
        case .up: next = .right
        case .right: next = .down
        case .down: next = .left
        case .left: next = .up
        }
        orientation = next
        applyOrientation(next)
        sceneRef?.audio.playMirrorRotate()
        sceneRef?.haptics.light()
    }

    /// Pulsu yönlendir: ayna yönelimi yönü belirler (spec 21).
    func deflect(direction: CGVector) -> CGVector {
        switch orientation {
        case .up: return CGVector(dx: 0, dy: 1)
        case .down: return CGVector(dx: 0, dy: -1)
        case .left: return CGVector(dx: -1, dy: 0)
        case .right: return CGVector(dx: 1, dy: 0)
        }
    }

    func reset() {
        // Checkpoint restore — başlangıç yönelimine dön (spec 461).
        orientation = initialOrientation
        applyOrientation(initialOrientation)
    }
}
