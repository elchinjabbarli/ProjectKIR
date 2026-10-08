import SpriteKit

/// Hareketli platform — spec 8/43: yol noktaları arasında gider.
/// Rezonansla tetiklenir (fren çözülür — spec 43) veya sürekli döner (L03 piston ritmi).
final class PlatformNode: InteractiveObject {

    struct Waypoint {
        let position: CGPoint
        let pause: TimeInterval
    }

    enum Mode: String, Codable {
        case looping      // sürekli gidip gelir (L03)
        case triggered    // rezonansla çalışır (L05)
        case floating     // su yüzeyinde yüzer (L02)
        case oneShot      // tek yolculuk
    }

    let mode: Mode
    let size: CGSize
    private var waypoints: [Waypoint] = []
    private(set) var currentWaypoint = 0
    private var pauseTimer: TimeInterval = 0
    private var moving = true
    private(set) var triggered = false
    private var sceneRef: GameScene?

    override var acceptedFrequency: ResonanceFrequency { .body }
    override var isInteractiveActive: Bool { mode == .triggered && !triggered }
    override var stateLabel: String { moving ? "HAREKET" : "BEKLER" }

    private let slab: SKShapeNode

    init(entityID: String, size: CGSize, mode: Mode, waypoints: [Waypoint]) {
        self.mode = mode
        self.size = size
        self.waypoints = waypoints
        slab = SKShapeNode(rectOf: size, cornerRadius: 4)
        slab.fillColor = KIRPalette.ash
        slab.strokeColor = KIRPalette.rust
        slab.lineWidth = 2
        super.init(entityID: entityID)
        addChild(slab)
        if let first = waypoints.first {
            position = first.position
        }
        if mode == .triggered {
            attachFrequencyMark(color: KIRPalette.bodyColor, pattern: ResonanceFrequency.body.patternLabel)
            moving = false
        }

        let body = SKPhysicsBody(rectangleOf: size)
        body.categoryBitMask = PhysicsCategory.interactive
        body.collisionBitMask = PhysicsCategory.player
        body.contactTestBitMask = PhysicsCategory.player
        body.isDynamic = false
        body.affectedByGravity = false
        body.friction = 1.0
        physicsBody = body
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) kullanılmıyor") }

    func attachScene(_ scene: GameScene) { sceneRef = scene }

    override func receiveResonance(_ pulse: ResonancePulse) {
        guard mode == .triggered, !triggered else { return }
        triggered = true
        moving = true
        sceneRef?.audio.playMachineStart()
        sceneRef?.haptics.machine()
        childNode(withName: "freqMark")?.run(SKAction.fadeOut(withDuration: 0.4))
    }

    override func receiveWrongFrequency(_ pulse: ResonancePulse) {
        ResonanceVisuals.wrongFrequencyRipple(node: self, color: KIRPalette.color(for: pulse.frequency))
        sceneRef?.audio.playWrongFrequency()
    }

    /// Su yüzeyine süzül (L02 yüzen platform).
    func floatTo(y: CGFloat) {
        run(SKAction.move(to: CGPoint(x: position.x, y: y), duration: 1.0))
        // Fizik gövdesini de taşı.
        physicsBody?.velocity = CGVector(dx: 0, dy: 0)
    }

    func update(dt: TimeInterval, player: PlayerNode?) {
        guard moving, waypoints.count > 1 else { return }

        // Oyuncu üstündeyse hafif birlikte taşınır
        // (SpriteKit: platform statik gövde + doğrudan konum → kontaktla otomatik taşınır).

        if pauseTimer > 0 {
            pauseTimer -= dt
            return
        }
        let target = waypoints[currentWaypoint].position
        let dir = CGVector(dx: target.x - position.x, dy: target.y - position.y)
        let dist = hypot(dir.dx, dir.dy)
        let speed: CGFloat = 120
        if dist < 6 {
            pauseTimer = waypoints[currentWaypoint].pause
            let nextIndex: Int
            switch mode {
            case .looping, .floating:
                nextIndex = (currentWaypoint + 1) % waypoints.count
            case .triggered, .oneShot:
                nextIndex = currentWaypoint + 1 < waypoints.count ? currentWaypoint + 1 : currentWaypoint
                if mode == .oneShot && currentWaypoint + 1 >= waypoints.count {
                    moving = false
                }
                if mode == .triggered && currentWaypoint + 1 >= waypoints.count {
                    moving = false
                }
            }
            currentWaypoint = nextIndex
            sceneRef?.audio.playPlatformSettle()
            return
        }
        let step = min(dist, speed * CGFloat(dt))
        position = CGPoint(x: position.x + dir.dx / dist * step,
                           y: position.y + dir.dy / dist * step)
    }

    func reset() {
        triggered = false
        if mode == .triggered {
            moving = false
            currentWaypoint = 0
            if let first = waypoints.first { position = first.position }
            childNode(withName: "freqMark")?.alpha = 1
        }
    }
}
