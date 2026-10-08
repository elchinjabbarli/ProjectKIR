import SpriteKit

/// Debug overlay — spec 156/157/424-431.
/// FPS, durum, aktif sistemler, level atlama. Yalnızca DEBUG build'de görünür.
final class DebugOverlay: SKNode {

    private let info: SKLabelNode
    private var timer: Double = 0
    private var visible = AppConfiguration.isDebugBuild
    private var frameCount = 0
    private var fps: Int = 0

    var extraInfo: String = ""

    override init() {
        info = SKLabelNode(text: "")
        info.fontName = "Menlo"
        info.fontSize = 11
        info.fontColor = SKColor(red: 0.4, green: 1.0, blue: 0.5, alpha: 0.85)
        info.horizontalAlignmentMode = .left
        info.verticalAlignmentMode = .top
        info.numberOfLines = 8
        super.init()
        name = NodeNames.debugLayer
        zPosition = 970
        isHidden = !visible
        addChild(info)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) kullanılmıyor") }

    func layout(for size: CGSize) {
        let safe = SceneRouter.safeInsets
        // Kamera çocuğu: sol üst köşe = (-w/2, h/2).
        info.position = CGPoint(x: -size.width / 2 + 12 + safe.left,
                                y: size.height / 2 - 12 - safe.top)
    }

    func toggle() {
        visible.toggle()
        isHidden = !visible
    }

    /// Üç parmak dokunuş da toggle yapabilir (spec 244).
    func handleTouchCount(_ count: Int) {
        if count >= 3 { toggle() }
    }

    func update(dt: Double, scene: GameScene) {
        guard visible else { return }
        frameCount += 1
        timer += dt
        if timer >= 0.5 {
            fps = Int(Double(frameCount) / timer)
            frameCount = 0
            timer = 0
        }
        let pb = scene.playerNode.physicsBody
        info.text = """
        FPS \(fps) | nodes \(scene.children.count) | state \(scene.coordinator.state.rawValue)
        pos \(Int(scene.playerNode.position.x)),\(Int(scene.playerNode.position.y)) vel \(Int(pb?.velocity.dx ?? 0)),\(Int(pb?.velocity.dy ?? 0))
        freq \(ResonanceSystem.shared.currentFrequency.rawValue) pulses \(ResonanceSystem.shared.pulses.count)
        cp \(scene.checkpointManager.activeCheckpointID ?? "-") interact \(scene.interactiveObjects.count)
        \(extraInfo)
        """
    }
}
