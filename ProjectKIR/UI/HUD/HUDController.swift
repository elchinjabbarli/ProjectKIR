import SpriteKit

/// Oyun içi HUD — spec 149/150/151/422.
/// Frekans göstergesi, şarj halkası, checkpoint bildirimi, drone uyarı vinyeti.
/// Az öğe, temiz ekran (spec 151: No Clutter).
final class HUDController: SKNode {

    private let freqLabel: SKLabelNode
    private let freqDots: [SKShapeNode]
    private let saveIndicator: SKLabelNode
    private let vignette: SKShapeNode
    private var subtitleLabel: SKLabelNode
    private var subtitleTimer: Double = 0

    private var availableFrequencies: Set<ResonanceFrequency> = Set(ResonanceFrequency.allCases)

    override init() {
        freqLabel = SKLabelNode.caption("DEEP", size: 15, color: KIRPalette.deepColor)
        freqDots = ResonanceFrequency.allCases.map { f in
            let d = SKShapeNode(circleOfRadius: 5)
            d.fillColor = KIRPalette.color(for: f)
            d.strokeColor = KIRPalette.color(for: f)
            return d
        }
        saveIndicator = SKLabelNode.caption(KIRStrings.checkpointSaved, size: 15, color: KIRPalette.amber)
        saveIndicator.alpha = 0
        vignette = SKShapeNode(rectOf: CGSize(width: 6000, height: 4000))
        vignette.fillColor = SKColor(red: 0.7, green: 0.12, blue: 0.08, alpha: 1)
        vignette.strokeColor = SKColor.clear
        vignette.alpha = 0
        vignette.zPosition = 930
        subtitleLabel = SKLabelNode.caption("", size: 17, color: KIRPalette.dirtyWhite)
        subtitleLabel.alpha = 0
        subtitleLabel.zPosition = 960
        subtitleLabel.preferredMaxLayoutWidth = 800
        super.init()
        name = NodeNames.hud
        zPosition = 940
        addChild(vignette)
        addChild(freqLabel)
        for (i, d) in freqDots.enumerated() {
            d.position = CGPoint(x: CGFloat(i - 1) * 16, y: -18)
            addChild(d)
        }
        addChild(saveIndicator)
        addChild(subtitleLabel)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) kullanılmıyor") }

    /// Kamera çocuğu olduğundan merkez-merkezli koordinatlar (origin = ekran merkezi).
    func layout(for size: CGSize) {
        let safe = SceneRouter.safeInsets
        freqLabel.position = CGPoint(x: 0, y: size.height / 2 - 46 - safe.top)
        freqLabel.horizontalAlignmentMode = .center
        for (i, d) in freqDots.enumerated() {
            d.position = CGPoint(x: CGFloat(i - 1) * 16, y: size.height / 2 - 66 - safe.top)
        }
        saveIndicator.position = CGPoint(x: 0, y: -size.height / 2 + 90)
        subtitleLabel.position = CGPoint(x: 0, y: -size.height / 2 + 130)
    }

    /// Kademeli frekans tanıtımı — kilitli frekans noktaları söner (spec 894/149).
    func setAvailableFrequencies(_ fs: [ResonanceFrequency]) {
        availableFrequencies = Set(fs)
        if availableFrequencies.isEmpty { availableFrequencies = [.deep] }
    }

    func updateFrequency(_ f: ResonanceFrequency, selected: Bool = true) {
        freqLabel.text = f.shortLabel
        freqLabel.fontColor = KIRPalette.color(for: f)
        let selIdx = ResonanceFrequency.allCases.firstIndex(of: f)
        for (i, d) in freqDots.enumerated() {
            // freqDots, ResonanceFrequency.allCases sırasıyla kurulur — indeksler hizalıdır.
            let unlocked = availableFrequencies.contains(ResonanceFrequency.allCases[i])
            d.isHidden = !unlocked
            d.setScale(i == selIdx ? 1.3 : 0.8)
            d.alpha = unlocked ? (i == selIdx ? 1 : 0.35) : 0
        }
    }

    /// Spec 422 — kayıt göstergesi.
    func showSaveIndicator() {
        saveIndicator.run(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.9, duration: 0.3),
            SKAction.wait(forDuration: 1.6),
            SKAction.fadeAlpha(to: 0, duration: 0.8)
        ]))
    }

    /// Drone alarmı — vinyet (spec 398).
    func setAlertLevel(_ level: Float) {
        vignette.alpha = CGFloat(level) * 0.22
    }

    /// Radyo parçası altyazısı — spec 340.
    func showSubtitle(_ text: String, duration: Double) {
        subtitleLabel.text = text
        subtitleTimer = duration
        subtitleLabel.removeAllActions()
        subtitleLabel.run(SKAction.fadeAlpha(to: 0.95, duration: 0.4))
    }

    func update(dt: TimeInterval) {
        if subtitleTimer > 0 {
            subtitleTimer -= dt
            if subtitleTimer <= 0 {
                subtitleLabel.run(SKAction.fadeAlpha(to: 0, duration: 0.6))
            }
        }
    }
}
