import SpriteKit

/// Jenerik — spec 215/567/568: basit liste, sade müzik, dokunla atla.
final class CreditsScene: SKScene {

    var coordinator: GameCoordinator!
    private let fromMenu: Bool
    private var lines: [SKLabelNode] = []
    private var elapsed: TimeInterval = 0

    init(size: CGSize, fromMenu: Bool) {
        self.fromMenu = fromMenu
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) kullanılmıyor") }

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(white: 0.02, alpha: 1)

        let content: [(String, CGFloat, SKColor)] = [
            (KIRStrings.gameTitle, 44, KIRPalette.dirtyWhite),
            ("", 20, SKColor.clear),
            ("tasarım · kod · ses", 20, KIRPalette.ash),
            ("PROJECT KIR ekibi", 18, KIRPalette.ash),
            ("", 20, SKColor.clear),
            ("Türkçe yerelleştirme", 18, KIRPalette.ash),
            ("", 20, SKColor.clear),
            ("tüm sesler prosedürel olarak", 17, KIRPalette.ash),
            ("oyun içinde sentezlendi", 17, KIRPalette.ash),
            ("", 20, SKColor.clear),
            ("bu yapı dünyada yalnız değildi", 18, KIRPalette.ash),
            ("", 20, SKColor.clear),
            ("test eden herkese teşekkürler", 17, KIRPalette.ash),
            ("", 20, SKColor.clear),
            ("© 2026 PROJECT KIR", 15, KIRPalette.ash)
        ]

        let startY = -140.0
        for (i, item) in content.enumerated() {
            let l = SKLabelNode(text: item.0)
            l.fontName = i == 0 ? "AvenirNext-Bold" : "AvenirNext-Medium"
            l.fontSize = item.1
            l.fontColor = item.2
            l.position = CGPoint(x: size.width / 2, y: startY + CGFloat(content.count - i) * 46)
            addChild(l)
            lines.append(l)
        }

        let hint = SKLabelNode.caption(fromMenu ? "✕" : "", size: 18, color: KIRPalette.ash)
        hint.position = CGPoint(x: size.width / 2, y: 60)
        addChild(hint)
    }

    override func update(_ currentTime: TimeInterval) {
        elapsed += 1.0 / 60.0
        // Yavaş yukarı kayma.
        for l in lines {
            l.position.y += 0.55
        }
        if elapsed > 26 && !fromMenu {
            finishToMenu()
        }
        if elapsed > 40 {
            finishToMenu()
        }
    }

    private func finishToMenu() {
        coordinator.finishCredits()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if fromMenu {
            coordinator.launchFromMainMenu()
        } else if elapsed > 2 {
            finishToMenu()
        }
    }
}
