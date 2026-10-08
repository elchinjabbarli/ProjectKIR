import SpriteKit

/// Tüm etkileşimli dünya nesnelerinin tabanı — spec 251 (Interaction Types).
/// JSON'dan gelir, rezonansa tepki verir, görsel dili frekans kodlaması taşır.
class InteractiveObject: SKNode, ResonanceReactive {

    let entityID: String
    var acceptedFrequency: ResonanceFrequency { .deep }
    var resonanceSensitivity: Float { 0.8 }
    var resonatesWithAnyFrequency = true

    /// Bağlı olduğu nesneler (zincir — spec 20/258).
    var linkedIDs: [String] = []

    /// Nesne şu an tepki verebilir mi (kapı açıksa vb.).
    var isInteractiveActive = true

    /// Görsel durum etiketi (debug).
    var stateLabel: String { "" }

    private var consumedPulseIdentities: Set<UInt64> = []

    init(entityID: String) {
        self.entityID = entityID
        super.init()
        zPosition = 20
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) kullanılmıyor") }

    func receiveResonance(_ pulse: ResonancePulse) {
        // Alt sınıf doldurur.
    }

    override var description: String {
        return "\(type(of: self))[\(entityID)] \(stateLabel)"
    }

    // Tekrar tetiklenme koruması — spec 388.
    func markPulseConsumed(identity: UInt64) {
        consumedPulseIdentities.insert(identity)
    }

    func hasConsumedPulse(identity: UInt64) -> Bool {
        return consumedPulseIdentities.contains(identity)
    }

    func resetPulseMemory() {
        consumedPulseIdentities.removeAll()
    }

    /// Görsel frekans işareti — spec 199/200: renk + biçim.
    func attachFrequencyMark(color: SKColor, pattern: String, above: CGFloat = 46) {
        let mark = SKLabelNode.caption(pattern, size: 13, color: color)
        mark.position = CGPoint(x: 0, y: above)
        mark.name = "freqMark"
        addChild(mark)
        let line = SKShapeNode(rectOf: CGSize(width: 30, height: 3), cornerRadius: 1.5)
        line.fillColor = color
        line.strokeColor = color
        line.position = CGPoint(x: 0, y: above + 12)
        line.name = "freqMarkLine"
        addChild(line)
    }

    /// Vurgu — oyuncu menzildeyken parlar (spec 146).
    func setHighlighted(_ on: Bool) {
        childNode(withName: "freqMark")?.alpha = on ? 1 : 0.45
    }
}
