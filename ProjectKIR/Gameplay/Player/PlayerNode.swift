import SpriteKit

/// Nera — saha kalibrasyon teknisyeni.
/// Görsel: placeholder silüet (spec 233). Fizik: dinamik gövde + doğrudan hız kontrolü (spec 227).
final class PlayerNode: SKNode {

    // Görsel parçalar
    private let torso: SKShapeNode
    private let head: SKShapeNode
    let device: SKShapeNode          // el rezonans cihazı (amber)
    private let deviceCore: SKShapeNode
    private(set) var shadow: SKShapeNode?

    // Durum
    private(set) var facingRight = true
    private(set) var crouching = false
    var locomotion: PlayerLocomotion = .idle

    var isFacingRight: Bool { facingRight }

    init(placeholderLabel: Bool = false) {
        torso = SKShapeNode(rectOf: CGSize(width: Tuning.playerSize.width * 0.62,
                                           height: Tuning.playerSize.height * 0.66),
                            cornerRadius: 8)
        torso.fillColor = KIRPalette.dirtyWhite
        torso.strokeColor = KIRPalette.dirtyWhite

        head = SKShapeNode(circleOfRadius: Tuning.playerSize.width * 0.30)
        head.fillColor = KIRPalette.dirtyWhite
        head.strokeColor = KIRPalette.dirtyWhite
        head.position = CGPoint(x: 0, y: Tuning.playerSize.height * 0.34)

        device = SKShapeNode(rectOf: CGSize(width: 12, height: 18), cornerRadius: 3)
        device.fillColor = KIRPalette.amber
        device.strokeColor = KIRPalette.amber
        device.position = CGPoint(x: 16, y: -2)

        deviceCore = SKShapeNode(circleOfRadius: 4)
        deviceCore.fillColor = KIRPalette.coal
        deviceCore.strokeColor = KIRPalette.coal

        super.init()
        addChild(torso)
        addChild(head)
        addChild(device)
        device.addChild(deviceCore)
        if placeholderLabel {
            let l = SKLabelNode.caption("NERA", size: 11, color: KIRPalette.coal)
            l.position = CGPoint(x: 0, y: 2)
            torso.addChild(l)
        }
        configurePhysics(standing: !crouching)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) kullanılmıyor") }

    // MARK: - Fizik
    func configurePhysics(standing: Bool) {
        let h = standing ? Tuning.playerSize.height : Tuning.crouchHeight
        let body = SKPhysicsBody(rectangleOf: CGSize(width: Tuning.playerSize.width * 0.7, height: h - 4))
        body.categoryBitMask = PhysicsCategory.player
        body.collisionBitMask = PhysicsCategory.world | PhysicsCategory.interactive | PhysicsCategory.debris
        body.contactTestBitMask = PhysicsCategory.hazard | PhysicsCategory.water
                              | PhysicsCategory.checkpoint | PhysicsCategory.trigger | PhysicsCategory.drone
        body.affectedByGravity = true
        body.allowsRotation = false
        body.friction = 0
        body.restitution = 0
        body.linearDamping = 0
        body.angularDamping = 0
        body.mass = 1
        physicsBody = body
    }

    func setCrouch(_ crouch: Bool, scene: SKScene?) {
        guard crouch != crouching else { return }
        crouching = crouch
        // Alçalma anında hemen, kalkma anında üst boşluk kontrolü yapılır (movement katmanı).
        configurePhysics(standing: !crouch)
        let scaleY: CGFloat = crouch ? 0.62 : 1.0
        run(SKAction.scaleY(to: scaleY, duration: 0.12))
    }

    func face(right: Bool) {
        guard right != facingRight else { return }
        facingRight = right
        // Spec 474 — dönüş anlık ama görsel yumuşatılır.
        xScale = xScale // dokunma
        run(SKAction.sequence([
            SKAction.scaleX(to: right ? 1 : -1, duration: 0.08)
        ]))
    }

    /// Spec 475 — şarj sırasında cihaz ileri kalkar.
    func aimDevice(forward: Bool) {
        let x: CGFloat = (facingRight ? 1 : -1) * (forward ? 22 : 16)
        device.position = CGPoint(x: x, y: forward ? 6 : -2)
    }

    func deviceGlow(_ intensity: CGFloat, color: SKColor) {
        device.fillColor = color
        deviceCore.fillColor = intensity > 0.6 ? color : KIRPalette.coal
        let s = 1 + intensity * 0.9
        device.setScale(s * (facingRight ? 1 : 1))
    }

    func dieVisual() {
        locomotion = .dead
        run(SKAction.group([
            SKAction.fadeAlpha(to: 0.15, duration: 0.35),
            SKAction.scale(to: 0.7, duration: 0.35)
        ]))
    }

    func respawnVisual() {
        removeAllActions()
        alpha = 1
        xScale = facingRight ? 1 : -1
        yScale = 1
        locomotion = .idle
    }
}
