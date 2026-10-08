import SpriteKit

/// Duraklatma menüsü — spec 76/118/370.
/// Minimal: Sürdür / Ayarlar / Ana Menü.
final class PauseOverlay: SKNode {

    var onResume: (() -> Void)?
    var onMainMenu: (() -> Void)?
    var onRestartCheckpoint: (() -> Void)?

    private let panel: SKShapeNode
    private let dimmer: SKShapeNode
    private var buttons: [(label: SKLabelNode, action: () -> Void)] = []
    private let coordinator: GameCoordinator

    init(size: CGSize, coordinator: GameCoordinator) {
        self.coordinator = coordinator
        dimmer = SKShapeNode(rectOf: CGSize(width: 6000, height: 4000))
        dimmer.fillColor = SKColor(white: 0, alpha: 0.62)
        dimmer.strokeColor = SKColor.clear
        panel = SKShapeNode(rectOf: CGSize(width: 420, height: 360), cornerRadius: 14)
        panel.fillColor = SKColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 0.97)
        panel.strokeColor = KIRPalette.dirtyWhite.withAlphaComponent(0.3)
        panel.lineWidth = 2
        super.init()
        zPosition = 990
        isUserInteractionEnabled = true
        addChild(dimmer)
        addChild(panel)

        let title = SKLabelNode.caption(KIRStrings.pauseTitle, size: 30, color: KIRPalette.dirtyWhite)
        title.position = CGPoint(x: 0, y: 130)
        panel.addChild(title)

        let resume = makeButton(KIRStrings.resume)
        let settings = makeButton(KIRStrings.settings)
        let restart = makeButton(KIRStrings.restartCheckpoint)
        let menu = makeButton(KIRStrings.mainMenu)

        resume.position = CGPoint(x: 0, y: 62)
        settings.position = CGPoint(x: 0, y: 8)
        restart.position = CGPoint(x: 0, y: -46)
        menu.position = CGPoint(x: 0, y: -100)

        buttons = [
            (resume, { [weak self] in self?.onResume?() }),
            (settings, { [weak self] in self?.showSettings() }),
            (restart, { [weak self] in self?.onRestartCheckpoint?() }),
            (menu, { [weak self] in self?.onMainMenu?() })
        ]
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) kullanılmıyor") }

    private func makeButton(_ text: String) -> SKLabelNode {
        let l = SKLabelNode.caption(text, size: 21, color: KIRPalette.dirtyWhite)
        l.name = "btn_\(text)"
        addChild(l)
        return l
    }

    private func showSettings() {
        let settings = SettingsOverlay(size: scene?.size ?? CGSize(width: 1334, height: 750),
                                        coordinator: coordinator)
        settings.onClose = { [weak self] in self?.isHidden = false }
        isHidden = true
        parent?.addChild(settings)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let p = t.location(in: self)
        for (label, action) in buttons {
            if abs(p.x - label.position.x) < 190 && abs(p.y - label.position.y) < 26 {
                coordinator.audio.playUIClick()
                coordinator.haptics.light()
                action()
                return
            }
        }
    }
}
