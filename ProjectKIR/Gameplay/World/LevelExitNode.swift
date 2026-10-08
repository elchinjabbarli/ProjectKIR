import SpriteKit

/// Bölüm çıkışı — spec 135: seviye sonu, sessiz kapı gibi.
/// Temas + tüm zorunlu koşullar tamam → bölüm biter.
final class LevelExitNode: SKNode {

    private(set) var consumed = false
    private var sceneRef: GameScene?

    init(position pos: CGPoint, size: CGSize = CGSize(width: 70, height: 150)) {
        super.init()
        position = pos
        name = NodeNames.exit
        let door = SKShapeNode(rectOf: size, cornerRadius: 6)
        door.fillColor = SKColor(white: 1, alpha: 0.03)
        door.strokeColor = KIRPalette.dirtyWhite.withAlphaComponent(0.35)
        door.lineWidth = 2
        door.zPosition = 12
        addChild(door)
        let arrow = SKLabelNode.caption("›", size: 40, color: KIRPalette.dirtyWhite.withAlphaComponent(0.5))
        addChild(arrow)

        let body = SKPhysicsBody(rectangleOf: size)
        body.categoryBitMask = PhysicsCategory.trigger
        body.collisionBitMask = PhysicsCategory.none
        body.contactTestBitMask = PhysicsCategory.player
        body.isDynamic = false
        body.affectedByGravity = false
        physicsBody = body
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) kullanılmıyor") }

    func attachScene(_ scene: GameScene) { sceneRef = scene }

    func playerEntered() {
        guard !consumed else { return }
        consumed = true
        sceneRef?.levelCompleted()
    }
}
