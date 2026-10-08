import SpriteKit
import UIKit

/// Ana menü — spec 116/213/214/305/664.
/// Koyu fon, yavaş nefes alan amber sinyal, minimal butonlar (Türkçe).
/// SKScene koordinatları: origin sol-alt (anchorPoint 0,0).
final class MainMenuScene: SKScene {

    var coordinator: GameCoordinator!
    private var buttons: [(label: SKLabelNode, action: () -> Void)] = []
    private var pulseTimer: Double = 0
    private var lastTime: TimeInterval = 0
    private let signal = SKShapeNode(circleOfRadius: 8)

    private var center: CGPoint { CGPoint(x: size.width / 2, y: size.height / 2) }

    override func didMove(to view: SKView) {
        backgroundColor = KIRPalette.coal
        scaleMode = .resizeFill

        // Uzak tesis silüeti (basit dikey çubuklar).
        var seed = Noise(seed: 99)
        for i in 0..<26 {
            let h = 120 + CGFloat(seed.uniform(0, 480))
            let bar = SKShapeNode(rectOf: CGSize(width: 20 + CGFloat(seed.uniform(0, 40)), height: h))
            bar.fillColor = KIRPalette.ash.withAlphaComponent(0.12)
            bar.strokeColor = SKColor.clear
            bar.position = CGPoint(x: CGFloat(i) * 62 - 140, y: h / 2)
            bar.isAntialiased = false
            addChild(bar)
        }

        // Başlık — spec 582.
        let title = SKLabelNode(text: KIRStrings.gameTitle)
        title.fontName = "AvenirNext-Bold"
        title.fontSize = 54
        title.fontColor = KIRPalette.dirtyWhite
        title.position = CGPoint(x: size.width / 2, y: size.height - 180)
        addChild(title)
        let subtitle = SKLabelNode.caption("—", size: 20, color: KIRPalette.ash)
        subtitle.position = CGPoint(x: size.width / 2, y: size.height - 220)
        addChild(subtitle)

        // Tek amber sinyal ışığı — oyunun motif özü (spec 623).
        signal.fillColor = KIRPalette.amber
        signal.strokeColor = KIRPalette.amber
        signal.position = CGPoint(x: size.width / 2 + 320, y: size.height / 2 + 60)
        addChild(signal)

        // Menüler.
        let newGame = makeButton(KIRStrings.newGame)
        let cont = makeButton(KIRStrings.continueGame)
        let settings = makeButton(KIRStrings.settings)
        let credits = makeButton(KIRStrings.credits)
        cont.alpha = coordinator.saveSystem.hasProgress ? 1 : 0.3

        let cx = size.width / 2
        let cy = size.height / 2
        newGame.position = CGPoint(x: cx, y: cy - 20)
        cont.position = CGPoint(x: cx, y: cy - 76)
        settings.position = CGPoint(x: cx, y: cy - 132)
        credits.position = CGPoint(x: cx, y: cy - 188)

        buttons = [
            (newGame, { [weak self] in
                guard let self = self else { return }
                self.coordinator.audio.playUIClick()
                self.coordinator.startNewGame()
            }),
            (cont, { [weak self] in
                guard let self = self else { return }
                guard self.coordinator.saveSystem.hasProgress else { return }
                self.coordinator.audio.playUIClick()
                self.coordinator.continueGame()
            }),
            (settings, { [weak self] in
                guard let self = self else { return }
                self.coordinator.audio.playUIClick()
                let so = SettingsOverlay(size: self.size, coordinator: self.coordinator)
                so.position = self.center
                self.addChild(so)
            }),
            (credits, { [weak self] in
                guard let self = self else { return }
                self.coordinator.audio.playUIClick()
                let cr = CreditsScene(size: self.size, fromMenu: true)
                cr.coordinator = self.coordinator
                SceneRouter.present(cr, withFadeDuration: 0.6)
            })
        ]

        // Spec 213: başlık ekranı sesi.
        coordinator.audio.setMusicState("calm")
        coordinator.audio.startAmbience(kind: "menu")
    }

    private func makeButton(_ text: String) -> SKLabelNode {
        let l = SKLabelNode.caption(text, size: 24, color: KIRPalette.dirtyWhite)
        addChild(l)
        return l
    }

    override func update(_ currentTime: TimeInterval) {
        // Sinyal ışığı yavaşça nefes alır (spec 664).
        if lastTime == 0 { lastTime = currentTime }
        let dt = currentTime - lastTime
        lastTime = currentTime
        pulseTimer += dt
        let s = 1 + sin(pulseTimer * 1.4) * 0.28
        signal.setScale(CGFloat(s))
        signal.alpha = 0.7 + CGFloat(sin(pulseTimer * 1.4)) * 0.2
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let p = t.location(in: self)
        for (label, action) in buttons {
            if abs(p.x - label.position.x) < 170 && abs(p.y - label.position.y) < 28 {
                action()
                return
            }
        }
    }
}
