import SpriteKit

/// Hareket entegrasyonu — spec 11, 12, 184-186, 185 (forgiveness), 228-229.
/// Coyote time + jump buffer + değişken zıplama yüksekliği + duck/stand.
struct PlayerMovement {

    private(set) var coyoteTimer: TimeInterval = 0
    private(set) var jumpBufferTimer: TimeInterval = 0
    private(set) var grounded = false
    private(set) var wasGrounded = false
    private(set) var justLanded = false
    private(set) var justJumped = false
    private(set) var groundY: CGFloat = 0
    var wantCrouch = false

    /// Ray ile zemin yoklaması — spec 228: sol/orta/sağ ayak probları.
    /// Hızla yükselirken (zıplama) zemin aramayı bırak; yavaş itki (su kaldırma) sırasında aramaya devam et.
    func probeGround(player: PlayerNode, in scene: SKScene) -> Bool {
        guard let body = player.physicsBody else { return false }
        if body.velocity.dy > 400 { return false }
        let halfW = Tuning.playerSize.width * 0.35
        let reach = (player.crouching ? Tuning.crouchHeight : Tuning.playerSize.height) / 2 + 6
        let center = player.position
        var found = false
        var bestY: CGFloat = -CGFloat.greatestFiniteMagnitude
        let xs: [CGFloat] = [-halfW, 0, halfW]
        for x in xs {
            let start = CGPoint(x: center.x + x, y: center.y - 4)
            let end = CGPoint(x: center.x + x, y: center.y - reach)
            scene.physicsWorld.enumerateBodies(alongRayStart: start, end: end) { probeBody, point, _, _ in
                if probeBody.categoryBitMask & (PhysicsCategory.world | PhysicsCategory.interactive) != 0 {
                    found = true
                    bestY = max(bestY, point.y)
                }
            }
        }
        if found { groundY = bestY }
        return found
    }

    /// Duvar yoklaması — spec 229 (side probe).
    func probeWall(player: PlayerNode, in scene: SKScene, toRight: Bool) -> Bool {
        let dir: CGFloat = toRight ? 1 : -1
        let start = CGPoint(x: player.position.x + dir * 4, y: player.position.y)
        let end = CGPoint(x: player.position.x + dir * (Tuning.playerSize.width / 2 + 8), y: player.position.y)
        var hit = false
        scene.physicsWorld.enumerateBodies(alongRayStart: start, end: end) { body, _, _, _ in
            if body.categoryBitMask & (PhysicsCategory.world | PhysicsCategory.interactive) != 0 {
                hit = true
            }
        }
        return hit
    }

    /// Üst boşluk — crouch'tan kalkabildi mi? (spec 229 top clearance)
    func hasHeadroom(player: PlayerNode, in scene: SKScene) -> Bool {
        let start = CGPoint(x: player.position.x, y: player.position.y + 4)
        let end = CGPoint(x: player.position.x, y: player.position.y + Tuning.playerSize.height / 2 + 2)
        var blocked = false
        scene.physicsWorld.enumerateBodies(alongRayStart: start, end: end) { body, _, _, _ in
            if body.categoryBitMask & PhysicsCategory.world != 0 { blocked = true }
        }
        return !blocked
    }

    /// Ana adım — hedef hızları fizik gövdesine uygular.
    /// Dönüş: bu karede gerçekleşen olaylar (ses/gürültü için).
    struct StepEvents {
        var didJump = false
        var didLand = false
        var landingSpeed: CGFloat = 0
        var footstep = false
    }

    mutating func step(
        player: PlayerNode,
        dt: TimeInterval,
        moveX: CGFloat,
        jumpHeld: Bool,
        jumpPressed: Bool,
        crouchPressed: Bool,
        scene: SKScene
    ) -> StepEvents {
        var events = StepEvents()
        wasGrounded = grounded
        grounded = probeGround(player: player, in: scene)
        justLanded = false

        // Zemin / hava kontrolü
        if grounded {
            coyoteTimer = Tuning.coyoteTime
        } else if coyoteTimer > 0 {
            coyoteTimer -= dt
        }
        if jumpPressed { jumpBufferTimer = Tuning.jumpBuffer }
        else if jumpBufferTimer > 0 { jumpBufferTimer -= dt }

        // Crouch — spec 229: kalkma için üst boşluk gerekir.
        if crouchPressed && grounded {
            player.setCrouch(true, scene: scene)
        } else if !crouchPressed && player.crouching {
            if hasHeadroom(player: player, in: scene) {
                player.setCrouch(false, scene: scene)
            }
        }
        let speed = player.crouching ? Tuning.crouchSpeed : Tuning.moveSpeed

        // Yatay hız — spec 185: esnek kontrol.
        let targetVX = moveX * speed
        let control: CGFloat = grounded ? 1.0 : Tuning.airControl
        if let body = player.physicsBody {
            let dv = targetVX - body.velocity.dx
            body.velocity.dx += dv * min(1, control * 12 * CGFloat(dt))
        }

        // Zıplama
        if jumpBufferTimer > 0 && coyoteTimer > 0 {
            if let body = player.physicsBody {
                body.velocity.dy = Tuning.jumpVelocity
            }
            coyoteTimer = 0
            jumpBufferTimer = 0
            justJumped = true
            events.didJump = true
        }
        // Değişken yükseklik — tuş erken bırakılırsa kes (spec 186).
        if !jumpHeld, let body = player.physicsBody, body.velocity.dy > 200 {
            body.velocity.dy *= 0.55
        }

        // Yerçekimi sınırı
        if let body = player.physicsBody, body.velocity.dy < Tuning.maxFallSpeed {
            body.velocity.dy = Tuning.maxFallSpeed
        }

        // Yön
        if moveX > 0.15 { player.face(right: true) }
        if moveX < -0.15 { player.face(right: false) }

        // İniş
        if grounded && !wasGrounded {
            justLanded = true
            events.didLand = true
            if let body = player.physicsBody {
                events.landingSpeed = -body.velocity.dy
            }
        }

        // Ayak sesi ritmi — hız bazlı
        if grounded && abs(moveX) > 0.3 {
            footstepPhase += dt * (player.crouching ? 5.0 : 8.2)
            if footstepPhase >= 1 {
                footstepPhase -= 1
                events.footstep = true
            }
        }
        return events
    }

    private var footstepPhase: Double = 0
}
