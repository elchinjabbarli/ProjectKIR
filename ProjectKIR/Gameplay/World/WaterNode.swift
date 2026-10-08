import SpriteKit

/// Su kütlesi — spec 23/256: hazır seviyeler, yüzen platform, basit kaldırma kuvveti.
/// Görsel: yarı saydam soğuk mavi dikdörtgen + yüzey çizgisi.
final class WaterNode: InteractiveObject {

    let width: CGFloat
    private(set) var currentLevel: ValveNode.WaterLevel
    private let levelHeights: [ValveNode.WaterLevel: CGFloat]
    private let baseY: CGFloat

    private let surface: SKShapeNode
    private let bodyRect: SKShapeNode
    private var sceneRef: GameScene?

    /// Yüzeydeki yüzebilir platform (opsiyonel — spec 37: yüzen platform).
    private(set) var floatPlatform: PlatformNode?

    override var acceptedFrequency: ResonanceFrequency { .deep }
    override var resonatesWithAnyFrequency: Bool { false }
    override var isInteractiveActive: Bool { false }

    init(entityID: String, x: CGFloat, baseY: CGFloat, width: CGFloat,
         levels: [ValveNode.WaterLevel: CGFloat], start: ValveNode.WaterLevel) {
        self.width = width
        self.baseY = baseY
        self.currentLevel = start
        self.levelHeights = levels

        let startH = max(6, levels[start] ?? 0)
        baseHeight = startH
        bodyRect = SKShapeNode(rectOf: CGSize(width: width, height: startH), cornerRadius: 0)
        bodyRect.fillColor = KIRPalette.coldBlue.withAlphaComponent(0.38)
        bodyRect.strokeColor = KIRPalette.coldBlue.withAlphaComponent(0.55)
        bodyRect.lineWidth = 2

        surface = SKShapeNode(rectOf: CGSize(width: width, height: 4), cornerRadius: 2)
        surface.fillColor = KIRPalette.coldBlue.withAlphaComponent(0.85)
        surface.strokeColor = KIRPalette.coldBlue.withAlphaComponent(0.85)

        super.init(entityID: entityID)
        position = CGPoint(x: x, y: baseY)
        bodyRect.position = CGPoint(x: 0, y: startH / 2)
        addChild(bodyRect)
        surface.position = CGPoint(x: 0, y: startH)
        addChild(surface)
    }

    /// İlk inşa yüksekliği (yScale referansı).
    private let baseHeight: CGFloat

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) kullanılmıyor") }

    func attachScene(_ scene: GameScene) { sceneRef = scene }

    var surfaceY: CGFloat { return baseY + (levelHeights[currentLevel] ?? 0) }

    /// Su yüzeyi altında mı?
    func contains(_ point: CGPoint) -> Bool {
        return point.x > position.x - width / 2 && point.x < position.x + width / 2
            && point.y < surfaceY && point.y > baseY - 20
    }

    /// Su seviyesi değişimi — spec 23: smooth geçiş.
    func setLevel(_ level: ValveNode.WaterLevel) {
        currentLevel = level
        let h = max(6, levelHeights[level] ?? 0)
        let dur: TimeInterval = 1.1
        let targetScale = h / baseHeight
        bodyRect.run(SKAction.group([
            SKAction.move(to: CGPoint(x: 0, y: h / 2), duration: dur),
            SKAction.scaleY(to: targetScale, duration: dur)
        ]))
        surface.run(SKAction.move(to: CGPoint(x: 0, y: h), duration: dur))
        sceneRef?.audio.playWaterChange()
        // Yüzen platformu yüzeye çek.
        floatPlatform?.floatTo(y: surfaceY + 14)
    }

    /// Oyuncu suda mı? Kaldırma kuvveti uygula — spec 37.
    func applyBuoyancy(to player: PlayerNode) {
        guard contains(player.position) else { return }
        if let body = player.physicsBody, body.velocity.dy < 140 {
            body.velocity.dy += 950 // saniyelik yukarı itki parçası
            body.velocity.dy = min(body.velocity.dy, 320)
        }
    }

    func attachFloatPlatform(_ platform: PlatformNode) {
        floatPlatform = platform
        platform.floatTo(y: surfaceY + 14)
    }

    func reset(to level: ValveNode.WaterLevel) {
        currentLevel = level
        let h = max(6, levelHeights[level] ?? 0)
        bodyRect.removeAllActions()
        surface.removeAllActions()
        bodyRect.yScale = h / baseHeight
        bodyRect.position = CGPoint(x: 0, y: h / 2)
        surface.position = CGPoint(x: 0, y: h)
        if let p = floatPlatform { p.floatTo(y: surfaceY + 14) }
    }
}
