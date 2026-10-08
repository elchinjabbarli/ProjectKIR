import SpriteKit

/// Ana mekanik sistemi — spec 15–23, 382–390.
/// Şarj → Puls → yayılma → tepki zinciri.
final class ResonanceSystem {

    static let shared = ResonanceSystem()

    // MARK: - Durum
    private(set) var charging = false
    private(set) var chargeProgress: Double = 0
    private(set) var currentFrequency: ResonanceFrequency = .deep
    private(set) var lastSelectedFrequency: ResonanceFrequency = .deep
    private(set) var pulses: [ResonancePulse] = []

    weak var scene: GameScene?
    weak var player: PlayerNode?

    var isCharged: Bool { chargeProgress >= 1 }

    private init() {}

    func reset() {
        charging = false
        chargeProgress = 0
        pulses.removeAll()
    }

    // MARK: - Frekans erişimi — kademeli tanıtım (spec 894, M02/M03 kabulü)
    private(set) var availableFrequencies: Set<ResonanceFrequency> = Set(ResonanceFrequency.allCases)

    func setAvailableFrequencies(_ fs: [ResonanceFrequency]) {
        availableFrequencies = Set(fs)
        if availableFrequencies.isEmpty { availableFrequencies = [.deep] }
        if !availableFrequencies.contains(currentFrequency) {
            currentFrequency = availableFrequencies.sorted { $0.fundamentalHz < $1.fundamentalHz }.first!
        }
    }

    // MARK: - Frekans
    func stepFrequency(_ delta: Int) {
        var f = currentFrequency
        if delta > 0 {
            for _ in 0..<ResonanceFrequency.allCases.count {
                f = f.next()
                if availableFrequencies.contains(f) { break }
            }
        } else if delta < 0 {
            for _ in 0..<ResonanceFrequency.allCases.count {
                f = f.previous()
                if availableFrequencies.contains(f) { break }
            }
        }
        setFrequency(f)
    }

    func setFrequency(_ f: ResonanceFrequency) {
        guard f != currentFrequency else { return }
        guard availableFrequencies.contains(f) else {
            // Kilitli frekans — hafif ret sesi (spec 385).
            scene?.audio.playWrongFrequency()
            return
        }
        currentFrequency = f
        lastSelectedFrequency = f
        scene?.audio.playFrequencySwitch(f)
        scene?.haptics.light()
    }

    // MARK: - Şarj — spec 17/383/479
    func updateCharge(dt: TimeInterval, held: Bool, justStarted: Bool, released: Bool) {
        if justStarted || (held && !charging) {
            charging = true
            if chargeProgress <= 0 {
                scene?.audio.playChargeStart(currentFrequency)
            }
        }
        if charging && held {
            chargeProgress += dt / Tuning.chargeDuration
            chargeProgress = min(1, chargeProgress)
            if chargeProgress >= 1 && !wasFull {
                // Full charge anı — haptic + tık sesi (spec 17).
                scene?.haptics.chargeFull()
                scene?.audio.playChargeFull(currentFrequency)
            }
        }
        if released || (!held && charging) {
            // Spec 478 — bırakma her zaman puls üretir; şarj yetersizse zayıf puls.
            releasePulse()
        }
        wasFull = chargeProgress >= 1
    }

    private var wasFull = false

    private func releasePulse() {
        defer {
            charging = false
            chargeProgress = 0
            wasFull = false
        }
        guard let p = player else { return }
        var pulse = ResonancePulse(
            origin: p.position,
            direction: CGVector(dx: p.isFacingRight ? 1 : -1, dy: 0),
            frequency: currentFrequency,
            strength: max(0.35, CGFloat(chargeProgress)),
            maxRange: Tuning.pulseRange * (0.55 + 0.45 * max(0.35, CGFloat(chargeProgress)))
        )
        pulses.append(pulse)

        // Ses + görsel + haptic + gürültü — spec 705: üçlü birlikte.
        scene?.audio.playPulse(pulse)
        scene?.spawnPulseVisual(pulse)
        scene?.haptics.pulse(power: Float(pulse.strength))
        scene?.broadcastSound(SoundEvent(
            position: p.position,
            intensity: SoundEvent.noiseScore(.resonance) * Float(pulse.strength) * 2.4,
            category: .resonance))
    }

    // MARK: - Yayılma — her karede pulsları ilerlet, nesneleri tetikle.
    func update(dt: TimeInterval) {
        guard let sc = scene else { return }
        let pulseCount = pulses.count
        for i in stride(from: pulseCount - 1, through: 0, by: -1) {
            pulses[i].advance(dt: dt)
            let pulse = pulses[i]
            for obj in sc.interactiveObjects {
                guard obj.isInteractiveActive else { continue }
                guard !obj.hasConsumedPulse(identity: pulseIdentity(pulse)) else { continue }
                let d = Math2D.distance(pulse.origin, obj.position)
                let reactionRange = CGFloat(obj.resonanceSensitivity) * pulse.maxRange
                guard d <= reactionRange + pulse.radius else { continue }
                // Nesne dalga cephesine yakınsa tetikle.
                if obj.acceptedFrequency == pulse.frequency {
                    obj.markPulseConsumed(identity: pulseIdentity(pulse))
                    deflectIfMirror(obj, pulse: pulse, scene: sc)
                    obj.receiveResonance(pulse)
                } else if obj.resonatesWithAnyFrequency {
                    obj.markPulseConsumed(identity: pulseIdentity(pulse))
                    deflectIfMirror(obj, pulse: pulse, scene: sc)
                    obj.receiveWrongFrequency(pulse)
                }
            }
            if !pulses[i].alive { pulses.remove(at: i) }
        }
    }

    /// Spec 21/254: ayna, gelen pulsu mevcut yönelimine göre 90° yönlendirir.
    /// Yönlendirme mevcut açıya göre yapılır; ardından ayna sonraki vuruş için döner.
    private func deflectIfMirror(_ obj: InteractiveObject, pulse: ResonancePulse, scene sc: GameScene) {
        guard let mirror = obj as? MirrorNode else { return }
        guard pulse.bounces < 2 else { return }   // zincir sınırı (spec 388)
        let dir = mirror.deflect(direction: pulse.direction)
        let deflected = ResonancePulse(
            origin: mirror.position,
            direction: dir,
            frequency: pulse.frequency,
            strength: pulse.strength * 0.95,
            maxRange: pulse.maxRange * 0.85,
            bounces: pulse.bounces + 1)
        pulses.append(deflected)
        sc.spawnPulseVisual(deflected)
        ResonanceVisuals.chainBeam(from: mirror.position,
                                   to: mirror.position + CGPoint(x: dir.dx, dy: dir.dy) * 220,
                                   color: KIRPalette.color(for: pulse.frequency),
                                   parent: sc.worldNode)
    }

    /// Puls kimliği — tekrar tetiklenmeyi önlemek için (spec 388: sonsuz döngü riski).
    private func pulseIdentity(_ p: ResonancePulse) -> UInt64 {
        // Aynı origin+frekans+açı → pratik kimlik; nesne başına tek tetik yeter.
        let x = UInt64(abs(Int(p.origin.x * 10)))
        let y = UInt64(abs(Int(p.origin.y * 10)))
        let f = UInt64(p.frequency.hashValue.magnitude)
        return x &* 1000003 &+ y &* 101 &+ f
    }
}
