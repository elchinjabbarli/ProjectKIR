import SpriteKit

/// Ayarlar — spec 117/371/372: ses seviyeleri + erişilebilirlik.
final class SettingsOverlay: SKNode {

    var onClose: (() -> Void)?

    private let panel: SKShapeNode
    private let coordinator: GameCoordinator
    private var sliders: [(label: SKLabelNode, key: String, node: SKShapeNode, value: Float)] = []
    private var toggles: [(label: SKLabelNode, key: String, node: SKShapeNode)] = []
    private let closeButton: SKLabelNode

    init(size: CGSize, coordinator: GameCoordinator) {
        self.coordinator = coordinator
        panel = SKShapeNode(rectOf: CGSize(width: 480, height: 460), cornerRadius: 14)
        panel.fillColor = SKColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 0.97)
        panel.strokeColor = KIRPalette.dirtyWhite.withAlphaComponent(0.3)
        panel.lineWidth = 2

        let dim = SKShapeNode(rectOf: CGSize(width: 6000, height: 4000))
        dim.fillColor = SKColor(white: 0, alpha: 0.62)
        dim.strokeColor = SKColor.clear

        closeButton = SKLabelNode.caption("✕ \(KIRStrings.back)", size: 20, color: KIRPalette.amber)
        closeButton.position = CGPoint(x: 0, y: -190)

        super.init()
        zPosition = 995
        isUserInteractionEnabled = true
        addChild(dim)
        addChild(panel)
        panel.addChild(closeButton)

        let title = SKLabelNode.caption(KIRStrings.settings.uppercased(), size: 26, color: KIRPalette.dirtyWhite)
        title.position = CGPoint(x: 0, y: 180)
        panel.addChild(title)

        buildSliders()
        buildToggles()
        refresh()
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) kullanılmıyor") }

    // MARK: - Kaydırıcılar (basit dokunmatik alan — sağa/sola)
    private func buildSliders() {
        let s = coordinator.settings
        let defs: [(String, String, Float)] = [
            (KIRStrings.masterVolume, "master", s.masterVolume),
            (KIRStrings.musicVolume, "music", s.musicVolume),
            (KIRStrings.sfxVolume, "sfx", s.sfxVolume)
        ]
        for (i, def) in defs.enumerated() {
            let y = CGFloat(120 - i * 56)
            let label = SKLabelNode.caption(def.0, size: 18, color: KIRPalette.dirtyWhite)
            label.position = CGPoint(x: 0, y: y + 18)
            label.horizontalAlignmentMode = .center
            panel.addChild(label)

            let track = SKShapeNode(rectOf: CGSize(width: 260, height: 6), cornerRadius: 3)
            track.fillColor = KIRPalette.ash.withAlphaComponent(0.5)
            track.strokeColor = SKColor.clear
            track.position = CGPoint(x: 0, y: y - 6)
            track.name = "track_\(def.1)"
            panel.addChild(track)

            let knob = SKShapeNode(circleOfRadius: 11)
            knob.fillColor = KIRPalette.amber
            knob.strokeColor = KIRPalette.dirtyWhite
            knob.position = CGPoint(x: -130 + CGFloat(def.2) * 260, y: y - 6)
            panel.addChild(knob)
            sliders.append((label: label, key: def.1, node: knob, value: def.2))
        }
    }

    private func buildToggles() {
        let s = coordinator.settings
        let defs: [(String, String, Bool)] = [
            (KIRStrings.subtitlesOn, "subs", s.subtitlesEnabled),
            (KIRStrings.hapticsOn, "haptics", s.hapticsEnabled),
            (KIRStrings.reduceMotion, "motion", s.reduceMotion)
        ]
        for (i, def) in defs.enumerated() {
            let y = CGFloat(-58 - i * 46)
            let label = SKLabelNode.caption(def.0, size: 18, color: KIRPalette.dirtyWhite)
            label.position = CGPoint(x: -50, y: y)
            label.horizontalAlignmentMode = .left
            panel.addChild(label)

            let box = SKShapeNode(rectOf: CGSize(width: 30, height: 18), cornerRadius: 4)
            box.fillColor = def.2 ? KIRPalette.amber : KIRPalette.ash.withAlphaComponent(0.4)
            box.strokeColor = KIRPalette.dirtyWhite.withAlphaComponent(0.5)
            box.position = CGPoint(x: 170, y: y)
            panel.addChild(box)
            toggles.append((label: label, key: def.1, node: box))
        }
    }

    private func refresh() {
        let s = coordinator.settings
        for (_, key, knob, _) in sliders {
            let v: Float = key == "master" ? s.masterVolume : (key == "music" ? s.musicVolume : s.sfxVolume)
            knob.position.x = -130 + CGFloat(v) * 260
        }
        for (_, key, box) in toggles {
            let on = key == "subs" ? s.subtitlesEnabled : (key == "haptics" ? s.hapticsEnabled : s.reduceMotion)
            box.fillColor = on ? KIRPalette.amber : KIRPalette.ash.withAlphaComponent(0.4)
        }
    }

    // MARK: - Dokunma
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let p = t.location(in: panel)

        // Kapat.
        if abs(p.x - closeButton.position.x) < 140 && abs(p.y - closeButton.position.y) < 26 {
            coordinator.audio.playUIBack()
            onClose?()
            removeFromParent()
            return
        }

        // Kaydırıcılar.
        for (i, slot) in sliders.enumerated() where abs(p.y - slot.node.position.y) < 40 {
            let v = Float(Math2D.clamp((p.x + 130) / 260, 0, 1))
            var s = coordinator.settings
            switch slot.key {
            case "master": s.masterVolume = v
            case "music": s.musicVolume = v
            default: s.sfxVolume = v
            }
            coordinator.applySettings(s)
            sliders[i].value = v
            refresh()
            // Spec 371 — önizleme sesi.
            if slot.key == "sfx" { coordinator.audio.playUIClick() }
            return
        }

        // Anahtarlar.
        for slot in toggles where abs(p.x - slot.node.position.x) < 40 && abs(p.y - slot.node.position.y) < 30 {
            var s = coordinator.settings
            switch slot.key {
            case "subs": s.subtitlesEnabled.toggle()
            case "haptics": s.hapticsEnabled.toggle()
            default: s.reduceMotion.toggle()
            }
            coordinator.applySettings(s)
            refresh()
            coordinator.audio.playUIClick()
            return
        }
    }
}
