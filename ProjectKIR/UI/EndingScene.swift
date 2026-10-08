import SpriteKit

/// Final sahnesi — spec 65/295/297: beyaza fade, gün doğumu, logo, menüye dönüş.
final class EndingScene: SKScene {

    var coordinator: GameCoordinator!
    private var elapsed: TimeInterval = 0
    private var phase = 0
    private let sky = SKShapeNode(rectOf: CGSize(width: 6000, height: 4000))
    private let title = SKLabelNode(text: KIRStrings.gameTitle)
    private let thanks = SKLabelNode.caption(KIRStrings.finalThanks, size: 22, color: KIRPalette.coal)

    override init(size: CGSize) {
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) kullanılmıyor") }

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(white: 0.03, alpha: 1)
        let cx = size.width / 2
        let cy = size.height / 2
        // Gökyüzü: karanlıktan şafağa.
        sky.fillColor = KIRPalette.coal
        sky.strokeColor = SKColor.clear
        sky.zPosition = -10
        sky.position = CGPoint(x: cx, y: cy)
        addChild(sky)

        // Ufuk çizgisi.
        let horizon = SKShapeNode(rectOf: CGSize(width: size.width * 2, height: 2))
        horizon.fillColor = KIRPalette.amber.withAlphaComponent(0.0)
        horizon.strokeColor = SKColor.clear
        horizon.position = CGPoint(x: cx, y: cy - 140)
        horizon.zPosition = -9
        horizon.name = "horizon"
        addChild(horizon)

        // Tesis silüeti önde.
        var seed = Noise(seed: 4242)
        for i in -14...14 {
            let h = 90 + CGFloat(seed.uniform(0, 260))
            let bar = SKShapeNode(rectOf: CGSize(width: 34, height: h))
            bar.fillColor = SKColor(white: 0.02, alpha: 1)
            bar.strokeColor = SKColor.clear
            bar.position = CGPoint(x: cx + CGFloat(i) * 76, y: cy - 140 + h / 2)
            bar.zPosition = -5
            bar.isAntialiased = false
            addChild(bar)
        }

        // Güneş.
        let sun = SKShapeNode(circleOfRadius: 46)
        sun.fillColor = KIRPalette.dirtyWhite
        sun.strokeColor = KIRPalette.dirtyWhite
        sun.position = CGPoint(x: cx, y: cy - 330)
        sun.zPosition = -8
        sun.alpha = 0
        sun.name = "sun"
        addChild(sun)

        title.fontName = "AvenirNext-Bold"
        title.fontSize = 60
        title.fontColor = KIRPalette.coal
        title.alpha = 0
        title.position = CGPoint(x: cx, y: cy + 40)
        addChild(title)

        thanks.alpha = 0
        thanks.position = CGPoint(x: cx, y: cy - 40)
        addChild(thanks)

        // Spec 315/602: final ses.
        coordinator.audio.playEndingAudio()
    }

    override func update(_ currentTime: TimeInterval) {
        elapsed += 1.0 / 60.0

        // Zaman çizelgesi (saniye):
        // 0-4: sessizlik + şafak başlar
        // 4-7: gün doğumu, ışık yükselir
        // 7+: beyaz ekran, logo belirir
        if elapsed < 4 {
            sky.fillColor = lerpColor(from: KIRPalette.coal, to: KIRPalette.ash,
                                      t: CGFloat(elapsed / 4))
        } else if phase == 0 {
            phase = 1
            let cx = size.width / 2
            let cy = size.height / 2
            if let sun = childNode(withName: "sun") {
                sun.run(SKAction.group([
                    SKAction.move(to: CGPoint(x: cx, y: cy - 120), duration: 3.0),
                    SKAction.fadeAlpha(to: 1, duration: 2.5),
                    SKAction.scale(to: 1.6, duration: 3.0)
                ]))
            }
        }
        if elapsed > 7 && phase == 1 {
            phase = 2
            run(SKAction.sequence([
                SKAction.wait(forDuration: 1.5),
                SKAction.run { [weak self] in
                    guard let self = self else { return }
                    self.backgroundColor = KIRPalette.dirtyWhite
                    self.sky.fillColor = KIRPalette.dirtyWhite
                    self.title.fontColor = SKColor(white: 0.08, alpha: 1)
                    self.title.run(SKAction.fadeAlpha(to: 1, duration: 1.2))
                    self.thanks.run(SKAction.sequence([
                        SKAction.wait(forDuration: 1.4),
                        SKAction.fadeAlpha(to: 0.75, duration: 1.0)
                    ]))
                },
                SKAction.wait(forDuration: 5.0),
                SKAction.run { [weak self] in
                    guard let self = self else { return }
                    // Spec 597: jenerikten menüye dönüş.
                    let cr = CreditsScene(size: self.size, fromMenu: false)
                    cr.coordinator = self.coordinator
                    SceneRouter.present(cr, withFadeDuration: 1.0)
                }
            ]))
        }
    }

    /// Skipt et — spec 599.
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if elapsed > 2 {
            let cr = CreditsScene(size: size, fromMenu: false)
            cr.coordinator = coordinator
            SceneRouter.present(cr, withFadeDuration: 0.6)
        }
    }

    private func lerpColor(from a: SKColor, to b: SKColor, t: CGFloat) -> SKColor {
        var ra: CGFloat = 0, ga: CGFloat = 0, ba: CGFloat = 0, aa: CGFloat = 0
        var rb: CGFloat = 0, gb: CGFloat = 0, bb: CGFloat = 0, ab: CGFloat = 0
        a.getRed(&ra, green: &ga, blue: &ba, alpha: &aa)
        b.getRed(&rb, green: &gb, blue: &bb, alpha: &ab)
        return SKColor(red: Math2D.lerp(ra, rb, t),
                       green: Math2D.lerp(ga, gb, t),
                       blue: Math2D.lerp(ba, bb, t),
                       alpha: 1)
    }
}
