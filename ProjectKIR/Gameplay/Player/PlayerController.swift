import SpriteKit

/// Oyuncu beyni — girdiyi harekete, rezonansa ve etkileşime çevirir.
/// GameScene'den her kare çağrılır (spec 7: mantık burada, sahne sadece koordine eder).
final class PlayerController {

    private unowned let scene: GameScene
    private var movement = PlayerMovement()
    private let animator = PlayerAnimator()
    private var snapshot = PlayerSnapshot()
    private var breathTimer: Double = 0
    private var wasHolding = false

    init(scene: GameScene) {
        self.scene = scene
        ResonanceSystem.shared.scene = scene
        ResonanceSystem.shared.player = scene.playerNode
    }

    func update(dt: Double, input: inout InputState, locked: Bool) {
        // scene.playerNode Optional<PlayerNode> — early return ile güvenli unwrap.
        guard let player = scene.playerNode else { return }

        if locked { input.lock() }

        // 1) Hareket — spec 11/12.
        let events = movement.step(
            player: player,
            dt: dt,
            moveX: input.moveX,
            jumpHeld: input.jumpHeld,
            jumpPressed: input.jumpPressedThisFrame,
            crouchPressed: input.crouchHeld,
            scene: scene)

        // 2) Ses, gürültü ve animasyon olayları — spec 27.
        if events.didJump {
            scene.audio.playJump()
            animator.triggerJump(node: player)
            scene.broadcastSound(SoundEvent(position: player.position,
                                            intensity: SoundEvent.noiseScore(.impact),
                                            category: .impact))
        }
        if events.didLand {
            scene.audio.playLand(strength: Float(min(1, events.landingSpeed / 900)))
            animator.triggerLand(node: player, strength: events.landingSpeed)
            scene.broadcastSound(SoundEvent(position: player.position,
                                            intensity: SoundEvent.noiseScore(.impact) * 1.2,
                                            category: .impact))
        }
        if events.footstep {
            scene.audio.playFootstep(running: true)
            scene.broadcastSound(SoundEvent(position: player.position,
                                            intensity: SoundEvent.noiseScore(.movement),
                                            category: .movement))
        }

        // Nefes — spec 96: yalnızlık hissi (seyrek).
        breathTimer += dt
        if breathTimer > 7.5 && movement.grounded {
            breathTimer = 0
            if scene.coordinator.random < 0.4 {
                scene.audio.playBreath()
            }
        }

        // 3) Rezonans — spec 17/383.
        let held = input.chargeHeld && !locked
        let justStarted = held && !wasHolding
        ResonanceSystem.shared.updateCharge(
            dt: dt,
            held: held,
            justStarted: justStarted,
            released: input.chargeReleasedThisFrame)
        wasHolding = held

        // Şarj görseli — spec 150.
        let rs = ResonanceSystem.shared
        if rs.charging {
            ResonanceVisuals.chargeRing(
                player: player,
                progress: CGFloat(rs.chargeProgress),
                color: KIRPalette.color(for: rs.currentFrequency))
        } else {
            ResonanceVisuals.chargeRing(player: player, progress: 0, color: .clear)
        }

        // 4) Etkileşim vurgusu — spec 146.
        let target = PlayerInteraction.nearestReactiveTarget(player: player, in: scene)
        PlayerInteraction.updateIcon(icon: scene.childForInteractIcon(), target: target,
                                     playerPosition: player.position)
        for obj in scene.interactiveObjects {
            obj.setHighlighted(obj === target)
        }

        // 5) Snapshot + animatör — spec 471/472.
        snapshot.grounded = movement.grounded
        snapshot.charging = rs.charging
        snapshot.chargeProgress = rs.chargeProgress
        snapshot.chargeFull = rs.isCharged
        snapshot.facingRight = player.isFacingRight
        snapshot.inWater = scene.level.waterNodes.contains { $0.contains(player.position) }
        if player.locomotion != .dead {
            let locomotion: PlayerLocomotion
            if locked {
                locomotion = .cinematicLocked
            } else if !movement.grounded {
                locomotion = .airborne
            } else if player.crouching {
                locomotion = .crouching
            } else if abs(player.physicsBody?.velocity.dx ?? 0) > 40 {
                locomotion = .running
            } else {
                locomotion = .idle
            }
            snapshot.locomotion = locomotion
            player.locomotion = locomotion
        }
        animator.update(dt: dt, node: player, snapshot: snapshot)
    }
}
