import SpriteKit

/// Ana tehdit: Devriye Dronu — spec 25/26/399/400.
/// FSM: PATROL → SUSPICION → ALERT → SEARCH → RETURN.
/// Öldürmez: alarm verir → basınç sistemi zorlaşır (spec 25: alarm felsefesi).
final class PatrolDrone: SKNode {

    enum State: String {
        case patrol
        case suspicion
        case alert
        case search
        case returnHome
    }

    private(set) var state: State = .patrol
    let path: [CGPoint]
    private var pathIndex = 0
    private var facing: CGFloat = 1
    private var suspicionTimer: TimeInterval = 0
    private var alertTimer: TimeInterval = 0
    private var searchTimer: TimeInterval = 0
    private var lastKnownPlayerPos: CGPoint = .zero
    private var sceneRef: GameScene?

    // Görsel
    private let hull: SKShapeNode
    private let lens: SKShapeNode
    private let leg1: SKShapeNode
    private let leg2: SKShapeNode
    private let leg3: SKShapeNode
    private var bobPhase: Double = 0

    // Spec 398: alarm UI — genişleyen vinyet.
    private(set) var alertLevel: Float = 0

    init(path: [CGPoint]) {
        self.path = path
        hull = SKShapeNode(rectOf: CGSize(width: 46, height: 30), cornerRadius: 10)
        hull.fillColor = KIRPalette.rust
        hull.strokeColor = KIRPalette.ash
        hull.lineWidth = 2

        lens = SKShapeNode(circleOfRadius: 7)
        lens.fillColor = KIRPalette.amber
        lens.strokeColor = KIRPalette.coal
        lens.position = CGPoint(x: 18, y: 0)

        leg1 = SKShapeNode(rectOf: CGSize(width: 3, height: 22), cornerRadius: 1.5)
        leg1.fillColor = KIRPalette.ash
        leg1.strokeColor = KIRPalette.ash
        leg1.position = CGPoint(x: -12, y: -20)
        leg1.zRotation = 0.4

        leg2 = SKShapeNode(rectOf: CGSize(width: 3, height: 26), cornerRadius: 1.5)
        leg2.fillColor = KIRPalette.ash
        leg2.strokeColor = KIRPalette.ash
        leg2.position = CGPoint(x: 2, y: -22)

        leg3 = SKShapeNode(rectOf: CGSize(width: 3, height: 22), cornerRadius: 1.5)
        leg3.fillColor = KIRPalette.ash
        leg3.strokeColor = KIRPalette.ash
        leg3.position = CGPoint(x: 15, y: -20)
        leg3.zRotation = -0.4

        super.init()
        name = NodeNames.drone
        if let p = path.first { position = p }
        addChild(leg1)
        addChild(leg2)
        addChild(leg3)
        addChild(hull)
        addChild(lens)
        zPosition = 25

        let body = SKPhysicsBody(rectangleOf: CGSize(width: 50, height: 40))
        body.categoryBitMask = PhysicsCategory.drone
        body.collisionBitMask = PhysicsCategory.none
        body.contactTestBitMask = PhysicsCategory.player
        body.isDynamic = false
        body.affectedByGravity = false
        physicsBody = body
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) kullanılmıyor") }

    func attachScene(_ scene: GameScene) { sceneRef = scene }

    // MARK: - Algılama — spec 26: LOS + mesafe + ses
    private func canSee(player: PlayerNode) -> Bool {
        guard let sc = sceneRef else { return false }
        // Çömelen oyuncu daha küçük bir hedef — açık alanda görüş menzili azalır (spec 56/401).
        let sightRange = player.crouching
            ? Tuning.droneSightRange * Tuning.droneCrouchSightFactor
            : Tuning.droneSightRange
        let d = Math2D.distance(position, player.position)
        guard d < sightRange else { return false }
        let dir = Math2D.direction(from: position, to: player.position)
        let facing = CGVector(dx: facing, dy: 0)
        let dot = dir.dx * facing.dx + dir.dy * facing.dy
        let angle = acos(max(-1, min(1, dot)))
        guard angle < Tuning.droneSightHalfAngle else { return false }
        // Görüş hattı: duvar engeli var mı?
        let start = position
        let end = player.position
        var blocked = false
        sc.physicsWorld.enumerateBodies(alongRayStart: start, end: end) { body, _, _, _ in
            if body.categoryBitMask & PhysicsCategory.world != 0 { blocked = true }
        }
        return !blocked
    }

    private func hear(sound: SoundEvent) -> Bool {
        let d = Math2D.distance(position, sound.position)
        let radius: CGFloat = 380 + CGFloat(sound.intensity) * 900
        return d < radius && sound.category != .environment
    }

    func onSoundEvent(_ sound: SoundEvent) {
        guard state == .patrol || state == .suspicion else { return }
        if hear(sound: sound) {
            enterSuspicion(at: sound.position)
        }
    }

    // MARK: - Durum geçişleri
    private func enterSuspicion(at source: CGPoint) {
        guard state != .alert else { return }
        state = .suspicion
        suspicionTimer = 1.4
        lastKnownPlayerPos = source
        sceneRef?.audio.playDroneSuspicion()
        lens.fillColor = KIRPalette.dirtyWhite
    }

    private func enterAlert() {
        state = .alert
        alertTimer = 3.2
        sceneRef?.audio.playDroneAlert()
        sceneRef?.haptics.danger()
        sceneRef?.droneAlertBegan()
        lens.fillColor = SKColor(red: 0.9, green: 0.3, blue: 0.25, alpha: 1)
        hull.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.moveBy(x: 2, y: 0, duration: 0.06),
            SKAction.moveBy(x: -2, y: 0, duration: 0.06)
        ])))
    }

    private func enterSearch() {
        state = .search
        searchTimer = 4.0
        lens.fillColor = KIRPalette.amber
    }

    private func enterReturn() {
        state = .returnHome
        hull.removeAllActions()
        alertLevel = 0
        sceneRef?.droneAlertEnded()
        sceneRef?.audio.playDroneCalm()
        lens.fillColor = KIRPalette.amber
    }

    // MARK: - Güncelleme
    func update(dt: TimeInterval, player: PlayerNode, playerHidden: Bool) {
        bobPhase += dt
        position.y += sin(bobPhase * 2.2) * 0.35

        switch state {
        case .patrol:
            alertLevel = Float(Math2D.lerp(CGFloat(alertLevel), 0, CGFloat(dt) * 2))
            moveAlongPath(speed: 85)
            if canSee(player: player) && !playerHidden {
                enterSuspicion(at: player.position)
            }

        case .suspicion:
            suspicionTimer -= dt
            lookAt(lastKnownPlayerPos)
            moveToward(lastKnownPlayerPos, speed: 40, dt: dt)
            if canSee(player: player) && !playerHidden {
                lastKnownPlayerPos = player.position
                if suspicionTimer < 0.9 { enterAlert() }
            }
            if suspicionTimer <= 0 { enterReturn() }

        case .alert:
            alertLevel = Float(Math2D.lerp(CGFloat(alertLevel), 1, CGFloat(dt) * 3))
            alertTimer -= dt
            if canSee(player: player) && !playerHidden {
                lastKnownPlayerPos = player.position
                alertTimer = 3.2
            }
            lookAt(lastKnownPlayerPos)
            moveToward(lastKnownPlayerPos, speed: 110, dt: dt)
            if alertTimer <= 0 {
                enterSearch()
            } else if alertTimer < 1.0 && !playerHidden {
                // Uzun süre açık hedefte → çevre tehlikeli hale gelir (spec 25).
                sceneRef?.environmentEscalated(by: self)
            }

        case .search:
            searchTimer -= dt
            lookAt(lastKnownPlayerPos)
            // Son bilinen konumda daire çizer.
            let a = CGFloat(searchTimer * 1.5)
            position.x = lastKnownPlayerPos.x + cos(a) * 90
            position.y = lastKnownPlayerPos.y + sin(a) * 40
            if canSee(player: player) && !playerHidden {
                enterAlert()
            }
            if searchTimer <= 0 { enterReturn() }

        case .returnHome:
            moveAlongPath(speed: 95)
            if let target = nearestPathPoint() {
                if Math2D.distance(position, target) < 30 { state = .patrol }
            }
            if canSee(player: player) && !playerHidden {
                enterSuspicion(at: player.position)
            }
        }
    }

    private func nearestPathPoint() -> CGPoint? {
        return path.indices.contains(pathIndex) ? path[pathIndex] : path.first
    }

    private func moveAlongPath(speed: CGFloat) {
        guard path.count > 1 else { return }
        let target = path[pathIndex]
        let d = Math2D.distance(position, target)
        if d < 14 {
            pathIndex = (pathIndex + 1) % path.count
            return
        }
        let dir = Math2D.direction(from: position, to: target)
        position = position + CGPoint(x: dir.dx, y: dir.dy) * speed * (1.0 / 60.0)
        facing = dir.dx >= 0 ? 1 : -1
        lens.position = CGPoint(x: 18 * facing, y: 0)
        hull.xScale = facing
        leg1.xScale = facing
        leg2.xScale = facing
        leg3.xScale = facing
    }

    private func moveToward(_ target: CGPoint, speed: CGFloat, dt: TimeInterval) {
        let dir = Math2D.direction(from: position, to: target)
        position = position + CGPoint(x: dir.dx, y: dir.dy) * speed * CGFloat(dt)
        facing = dir.dx >= 0 ? 1 : -1
        lens.position = CGPoint(x: 18 * facing, y: 0)
        hull.xScale = facing
    }

    private func lookAt(_ target: CGPoint) {
        facing = target.x >= position.x ? 1 : -1
        lens.position = CGPoint(x: 18 * facing, y: 0)
        hull.xScale = facing
    }

    func reset() {
        state = .patrol
        alertLevel = 0
        hull.removeAllActions()
        lens.fillColor = KIRPalette.amber
        pathIndex = 0
        if let p = path.first { position = p }
    }
}
