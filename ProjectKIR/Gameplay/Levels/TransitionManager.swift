import SpriteKit

/// Görsel geçişler — spec 136/669/670: yumuşak fade, ölüm kararması, bölüm akışı.
/// Perde, kameranın çocuğu olarak eklenir — dünya koordinatlarından etkilenmez.
final class TransitionManager {

    private weak var scene: GameScene?
    private let curtain: SKShapeNode

    init(scene: GameScene, camera: SKCameraNode) {
        self.scene = scene
        let size = CGSize(width: 6000, height: 4000)
        curtain = SKShapeNode(rectOf: size, cornerRadius: 0)
        curtain.fillColor = SKColor(white: 0, alpha: 1)
        curtain.strokeColor = SKColor.clear
        curtain.zPosition = 980
        curtain.alpha = 0
        curtain.isUserInteractionEnabled = true
        camera.addChild(curtain)
    }

    func fadeInFromBlack(duration: TimeInterval = 0.8) {
        curtain.alpha = 1
        curtain.run(SKAction.fadeAlpha(to: 0, duration: duration))
    }

    func fadeOutToBlack(duration: TimeInterval, completion: @escaping () -> Void) {
        curtain.run(SKAction.sequence([
            SKAction.fadeAlpha(to: 1, duration: duration),
            SKAction.run(completion)
        ]))
    }

    /// Ölüm — spec 669: kısa vurgu + kararma + boğulan ses.
    func deathFade(completion: @escaping () -> Void) {
        curtain.alpha = 0
        curtain.run(SKAction.sequence([
            SKAction.fadeAlpha(to: 1, duration: 0.55),
            SKAction.wait(forDuration: 0.35),
            SKAction.run(completion),
            SKAction.fadeAlpha(to: 0, duration: 0.5)
        ]))
    }

    /// Final: beyaza fade — spec 65.
    func fadeOutToWhite(completion: @escaping () -> Void) {
        curtain.fillColor = SKColor(white: 1, alpha: 1)
        curtain.run(SKAction.sequence([
            SKAction.fadeAlpha(to: 1, duration: 1.6),
            SKAction.run(completion)
        ]))
    }

    func setInteractive(_ on: Bool) {
        curtain.isUserInteractionEnabled = on
    }
}
