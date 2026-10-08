import SpriteKit

/// Kalibrasyon Feneri (checkpoint) — spec 29/420/421.
/// Yaklaşınca aktifleşir: amber ışık + düşük hum + minik kamera itmesi + save.
final class CheckpointBeacon: SKNode {

    let checkpointID: String
    let levelID: String
    /// internal(set) — LevelManager restore ve CheckpointManager spawnPoint içinden set edilebilmeli.
    internal(set) var activated = false

    private let post: SKShapeNode
    private let lamp: SKShapeNode
    private var sceneRef: GameScene?

    init(levelID: String, checkpointID: String, position pos: CGPoint) {
        self.levelID = levelID
        self.checkpointID = checkpointID
        post = SKShapeNode(rectOf: CGSize(width: 14, height: 64), cornerRadius: 3)
        post.fillColor = KIRPalette.ash
        post.strokeColor = KIRPalette.rust
        post.lineWidth = 2
        lamp = SKShapeNode(circleOfRadius: 10)
        lamp.fillColor = KIRPalette.ash
        lamp.strokeColor = KIRPalette.ash
        lamp.position = CGPoint(x: 0, y: 38)
        super.init()
        position = pos
        name = NodeNames.checkpoint
        addChild(post)
        addChild(lamp)
        zPosition = 15

        let body = SKPhysicsBody(rectangleOf: CGSize(width: 40, height: 80))
        body.categoryBitMask = PhysicsCategory.checkpoint
        body.collisionBitMask = PhysicsCategory.none
        body.contactTestBitMask = PhysicsCategory.player
        body.isDynamic = false
        body.affectedByGravity = false
        physicsBody = body
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) kullanılmıyor") }

    func attachScene(_ scene: GameScene) { sceneRef = scene }

    /// Oyuncu temas etti.
    func activate() {
        guard !activated else { return }
        activated = true
        activateVisualOnly()
        sceneRef?.audio.playCheckpoint()
        sceneRef?.haptics.checkpoint()
        sceneRef?.cameraController.punch(amount: 4)
        sceneRef?.checkPointReached(self)
    }

    /// Yalnızca görsel durum (restore yolu) — ses/yan etki yok.
    func activateVisualOnly() {
        lamp.fillColor = KIRPalette.amber
        lamp.strokeColor = KIRPalette.amber
        lamp.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.55, duration: 0.7),
            SKAction.fadeAlpha(to: 1, duration: 0.7)
        ])))
        let halo = SKShapeNode(circleOfRadius: 26)
        halo.strokeColor = KIRPalette.amber.withAlphaComponent(0.5)
        halo.fillColor = SKColor.clear
        halo.lineWidth = 2
        addChild(halo)
        halo.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.group([SKAction.scale(to: 1.5, duration: 1.2), SKAction.fadeAlpha(to: 0, duration: 1.2)]),
            SKAction.scale(to: 1.0, duration: 0.01)
        ])))
    }

    func deactivateVisual() {
        activated = false
        lamp.removeAllActions()
        lamp.fillColor = KIRPalette.ash
        lamp.strokeColor = KIRPalette.ash
    }
}
