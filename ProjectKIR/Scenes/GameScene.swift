import SpriteKit
import UIKit

/// Oyun sahnesi — spec 7: yalnızca lifecycle + sistem kurulumu + update koordinasyonu.
/// Oyuncu mantığı PlayerController'da, ses AudioDirector'da, save SaveSystem'de,
/// level çözümlemesi LevelManager'dadır.
final class GameScene: SKScene, SKPhysicsContactDelegate {

    // MARK: - Bağımlılıklar
    let coordinator: GameCoordinator
    let levelID: String
    var audio: AudioDirector { coordinator.audio }
    var haptics: HapticDirector { coordinator.haptics }

    // MARK: - Sistemler
    let worldNode = SKNode()
    private(set) var level: LevelManager!
    private(set) var cameraController: CameraController!
    private(set) var parallax: ParallaxController!
    private(set) var checkpointManager: CheckpointManager!
    private(set) var transition: TransitionManager!
    private(set) var storyBeats: StoryBeatSystem!
    private(set) var hud: HUDController!
    private(set) var touchControls: TouchControls!
    private(set) var keyboard: KeyboardInput!
    private(set) var debugOverlay: DebugOverlay!

    // MARK: - Aktörler
    private(set) var playerNode: PlayerNode!
    private var playerController: PlayerController!
    private var interactIcon: SKNode!

    // MARK: - Girdi
    private var input = InputState()

    // MARK: - Durum
    private var deathCooldown: Double = 0
    private var respawnPending = false
    private var completed = false
    private(set) var covers: [CGRect] = []
    private var sessionStart = Date()
    private var droneAnyAlert = false
    private var escalations = 0
    private var motifTimer: Double = 0    // jeneratif motif aralığı — spec 416/503

    var interactiveObjects: [InteractiveObject] { level.interactiveObjects }

    // MARK: - Kurulum
    init(levelID: String, checkpointID: String?, coordinator: GameCoordinator) {
        self.levelID = levelID
        self.coordinator = coordinator
        super.init(size: CGSize(width: 1334, height: 750))
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) kullanılmıyor") }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        coordinator.setState(.loading)
        physicsWorld.gravity = CGVector(dx: 0, dy: Tuning.gravity)
        physicsWorld.contactDelegate = self

        // Spec 434: level yüklenemezse ana menüye güvenli dönüş.
        let def: LevelDefinition
        do {
            def = try LevelLoader.load(levelID: levelID)
        } catch {
            KIRLog.error("Level yüklenemedi: \(levelID) — menüye dönülüyor.")
            coordinator.returnToMainMenu()
            return
        }

        backgroundColor = KIRPalette.chapterBackground(def.chapter)
        worldNode.name = NodeNames.world
        addChild(worldNode)

        // Sistemler.
        level = LevelManager(definition: def)
        level.build(in: self)
        cameraController = CameraController(scene: self)
        cameraController.setBounds(def.camera.rect)
        parallax = ParallaxController()
        parallax.build(in: self, camera: cameraController.camera,
                       palette: KIRPalette.chapterBackground(def.chapter))
        checkpointManager = CheckpointManager(scene: self)
        transition = TransitionManager(scene: self, camera: cameraController.camera)
        storyBeats = StoryBeatSystem(beats: def.storyBeats, scene: self)

        // Oyuncu — save'deki checkpoint yalnız bu bölüme aitse kullanılır.
        let savedCP = (coordinator.saveSystem.data.currentLevelID == levelID)
            ? coordinator.saveSystem.data.currentCheckpointID : nil
        let spawnPoint = checkpointManager.spawnPoint(fromSave: savedCP, in: level)
        playerNode = PlayerNode(placeholderLabel: true)
        playerNode.name = NodeNames.player
        playerNode.position = spawnPoint
        playerNode.zPosition = 40
        worldNode.addChild(playerNode)
        playerController = PlayerController(scene: self)

        // HUD + kontroller — kamera çocukları: ekran uzayında kalır (spec 151).
        hud = HUDController()
        hud.layout(for: size)
        cameraController.camera.addChild(hud)

        // Kademeli frekans tanıtımı — spec 894, M02/M03 kabulü.
        ResonanceSystem.shared.setAvailableFrequencies(def.allowedFrequencies)
        hud.setAvailableFrequencies(def.allowedFrequencies)
        touchControls = TouchControls()
        touchControls.layout(for: size)
        touchControls.setAvailableFrequencies(def.allowedFrequencies)
        cameraController.camera.addChild(touchControls)
        hud.updateFrequency(ResonanceSystem.shared.currentFrequency)

        keyboard = KeyboardInput()

        interactIcon = PlayerInteraction.buildIcon()
        worldNode.addChild(interactIcon)

        debugOverlay = DebugOverlay()
        debugOverlay.layout(for: size)
        cameraController.camera.addChild(debugOverlay)

        // Ses — spec 408/415: bölgeye göre müzik.
        audio.startAmbience(kind: def.ambient?.palette ?? "default")
        audio.setMusicState(def.ambient?.musicState ?? "calm")

        // Register'lar.
        checkpointManager.registerInitialSnapshot(level.captureSnapshot())
        if !coordinator.saveSystem.data.activatedCheckpoints.isEmpty {
            storyBeats.markFired(firedFromSave())
        }

        // Bildirimler.
        NotificationCenter.default.addObserver(self, selector: #selector(togglePause),
                                               name: .kirTogglePause, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(frequencyStepped(_:)),
                                               name: .kirFrequencyStep, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(frequencyDirect(_:)),
                                               name: .kirFrequencyDirect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(controllerDisconnected),
                                               name: .kirControllerDisconnected, object: nil)

        transition.fadeInFromBlack(duration: 0.9)
        coordinator.setState(.playing)
        sessionStart = Date()
        KIRLog.info("Level başladı: \(levelID) spawn=\(Int(spawnPoint.x)),\(Int(spawnPoint.y))")
    }

    private func firedFromSave() -> [String] {
        // Aynı bölümde tetiklenmiş beat'ler tekrar oynamaz (spec 453 kalıcılık).
        return coordinator.saveSystem.data.firedStoryBeats
    }

    // MARK: - Ana döngü — spec 225
    override func update(_ currentTime: TimeInterval) {
        guard playerNode != nil, level != nil else { return }
        coordinator.time.tick(wallTime: currentTime)

        let dt = coordinator.time.deltaTime
        guard dt > 0 else { return }

        let isPaused = coordinator.state == .paused
        if !isPaused {
            stepGame(dt: dt)
        }
        debugOverlay.update(dt: dt, scene: self)
    }

    private func stepGame(dt: Double) {
        // 1) Girdi — spec 225 sırası.
        input.beginFrame()
        if coordinator.state == .playing {
            touchControls.apply(to: &input)
            keyboard.poll(into: &input)
            let edges = touchControls.consumeEdges()
            if edges.jump { input.jumpPressedThisFrame = true }
            if edges.release { input.chargeReleasedThisFrame = true }
            touchControls.setChargeVisual(progress: CGFloat(ResonanceSystem.shared.chargeProgress),
                                          full: ResonanceSystem.shared.isCharged)
        }

        // 2) Ölüm/respawn zamanlayıcısı.
        if respawnPending {
            deathCooldown -= dt
            if deathCooldown <= 0 {
                respawnPending = false
                performRespawn()
            }
        }

        // 3) Oyuncu kontrolü.
        if coordinator.state == .playing || coordinator.state == .dead {
            playerController.update(dt: dt, input: &input, locked: storyBeats.isCinematicLock)
        }

        // 4) Gameplay sistemleri.
        if coordinator.state == .playing {
            ResonanceSystem.shared.update(dt: dt)
            for obj in level.interactiveObjects {
                (obj as? DoorNode)?.update(dt: dt)
                (obj as? ResonanceBridgeNode)?.update(dt: dt)
            }
            for platform in level.platforms {
                platform.update(dt: dt, player: playerNode)
            }
            for wave in level.waves {
                wave.update(dt: dt, player: playerNode)
            }
            for debris in level.debrisSpawners {
                debris.update(dt: dt)
            }
            for silt in level.siltZones {
                silt.update(dt: dt, player: playerNode)
            }
            for leak in level.leaks {
                leak.update(dt: dt, player: playerNode)
            }
            for water in level.waterNodes {
                water.applyBuoyancy(to: playerNode)
            }
            updateDrones(dt: dt)
            storyBeats.update(dt: dt, playerPosition: playerNode.position)

            // Ölümcül düşme — spec 187.
            let bottom = level.definition.camera.bottom - Tuning.fallDeathDistanceBeyondBounds
            if playerNode.position.y < bottom && coordinator.state == .playing {
                killPlayer(reason: "fall")
            }
        }

        // 5) Kamera.
        cameraController.update(dt: dt, playerPosition: playerNode.position, viewSize: size)
        parallax.update()

        // 6) HUD.
        hud.update(dt: dt)
        hud.updateFrequency(ResonanceSystem.shared.currentFrequency)
        let maxAlert = level.drones.map { $0.alertLevel }.max() ?? 0
        hud.setAlertLevel(maxAlert)

        // 7) Jeneratif müzik motifi — seyrek, rastgele (spec 416/503).
        motifTimer += dt
        if motifTimer > 24 {
            motifTimer = 0
            if coordinator.random < 0.7 { audio.tickMotif() }
        }
    }

    private func updateDrones(dt: Double) {
        // Oyuncu gizli mi? — çömelme + siper (spec 56/401: alçak alan ve siper saklar).
        let inCover = covers.contains { $0.contains(playerNode.position) }
        let playerHidden = playerNode.crouching && inCover
        var anyAlert = false
        for drone in level.drones {
            drone.update(dt: dt, player: playerNode, playerHidden: playerHidden)
            if drone.alertLevel > 0.3 { anyAlert = true }
        }
        if anyAlert != droneAnyAlert {
            droneAnyAlert = anyAlert
            audio.setDroneLoop(active: anyAlert)
        }
    }

    // MARK: - Fizik teması — spec 144.
    func didBegin(_ contact: SKPhysicsContact) {
        let a = contact.bodyA
        let b = contact.bodyB
        let masks = a.categoryBitMask | b.categoryBitMask

        if masks & PhysicsCategory.checkpoint != 0 {
            let beaconBody = (a.categoryBitMask == PhysicsCategory.checkpoint) ? a : b
            if let beacon = beaconBody.node as? CheckpointBeacon {
                if !beacon.activated { beacon.activate() }
            }
        }
        if masks & PhysicsCategory.trigger != 0 {
            if coordinator.state == .playing { levelCompleted() }
        }
        if masks & PhysicsCategory.hazard != 0 && coordinator.state == .playing {
            killPlayer(reason: "hazard")
        }
        // Hızlı düşen enkaz — ölümcül temas (spec 25 gerilim).
        if masks & PhysicsCategory.debris != 0 && coordinator.state == .playing {
            let debrisBody = (a.categoryBitMask == PhysicsCategory.debris) ? a : b
            if (debrisBody.node?.physicsBody?.velocity.dy ?? 0) < -320 {
                killPlayer(reason: "debris")
            }
        }
    }

    // MARK: - Olaylar
    func checkPointReached(_ beacon: CheckpointBeacon) {
        checkpointManager.beaconReached(beacon, in: level)
        storyBeats.handleEvent(type: "checkpoint", id: beacon.checkpointID)
        coordinator.saveSystem.recordFiredBeats(storyBeats.firedIDs)
    }

    func levelCompleted() {
        guard !completed else { return }
        completed = true
        coordinator.setState(.levelComplete)
        audio.stopAmbience()
        audio.setMusicState("silence")
        coordinator.saveSystem.recordSessionTime(Date().timeIntervalSince(sessionStart))
        coordinator.saveSystem.recordFiredBeats(storyBeats.firedIDs)
        transition.fadeOutToBlack(duration: 1.0) { [weak self] in
            self?.coordinator.levelCompleted(currentLevelID: self?.levelID ?? "")
        }
    }

    func killPlayer(reason: String) {
        guard coordinator.state == .playing || coordinator.state == .dead else { return }
        guard coordinator.state != .dead else { return }
        coordinator.setState(.dead)
        coordinator.time.timeScale = 0.35
        audio.duckMusic(0.8, for: 3.0)
        haptics.death()
        playerNode.dieVisual()
        respawnPending = true
        deathCooldown = 1.1
        transition.deathFade { [weak self] in
            // Restore transition callback içinde değil; respawn performRespawn'da.
        }
        KIRLog.info("Ölüm: \(reason)")
    }

    private func performRespawn() {
        // Spec 669: hızlı dönüş — 1-2 sn.
        let spawn = checkpointManager.restoreForRespawn(in: level)
        playerNode.respawnVisual()
        playerNode.position = spawn
        playerNode.physicsBody?.velocity = CGVector(dx: 0, dy: 0)
        coordinator.time.timeScale = 1.0
        ResonanceSystem.shared.reset()
        coordinator.setState(.playing)
        audio.playCheckpoint()
    }

    // MARK: - Zincir
    func triggerChain(from source: InteractiveObject, frequency: ResonanceFrequency) {
        level.triggerChain(from: source, frequency: frequency, in: self)
        storyBeats.handleEvent(type: "receiver", id: source.entityID)
    }

    func setWaterLevel(waterID: String, level: ValveNode.WaterLevel) {
        self.level.setWaterLevel(waterID: waterID, level: level)
    }

    func broadcastSound(_ event: SoundEvent) {
        for drone in level.drones {
            drone.onSoundEvent(event)
        }
    }

    func registerCover(rect: CGRect) {
        covers.append(rect)
    }

    func spawnPulseVisual(_ pulse: ResonancePulse) {
        ResonanceVisuals.pulseRing(pulse: pulse, parent: worldNode)
        ResonanceVisuals.chargeRing(player: playerNode, progress: 0, color: .clear)
    }

    /// Interact ikonu (worldNode içinde).
    func childForInteractIcon() -> SKNode? {
        return worldNode.childNode(withName: "//\(NodeNames.interactIcon)")
    }

    // MARK: - Cinematic lock — spec 261
    func cinematicLockBegan() {
        input.lock()
        touchControls.isHidden = true
    }

    func cinematicLockEnded() {
        input.unlock()
        touchControls.isHidden = false
    }

    // MARK: - Drone alarm tepsisi
    func droneAlertBegan() {
        hud.setAlertLevel(0.6)
    }

    func droneAlertEnded() {
        hud.setAlertLevel(0)
    }

    /// Drone uzun süre oyuncuyu gördü — çevre tehlikeli (spec 25).
    func environmentEscalated(by drone: PatrolDrone) {
        escalations += 1
        if escalations >= 3 {
            killPlayer(reason: "drone")
        }
    }

    // MARK: - Bildirim seçicileri
    @objc private func togglePause() {
        guard coordinator.state == .playing || coordinator.state == .paused else { return }
        if coordinator.state == .playing {
            pauseGame()
        } else {
            resumeGame()
        }
    }

    private func pauseGame() {
        coordinator.setState(.paused)
        physicsWorld.speed = 0
        audio.pause()
        // Spec 308: arka plana geçişte save.
        coordinator.saveSystem.save()
        let pause = PauseOverlay(size: size, coordinator: coordinator)
        pause.onResume = { [weak self] in self?.resumeGame() }
        pause.onMainMenu = { [weak self] in
            self?.audio.resume()
            self?.coordinator.returnToMainMenu()
        }
        pause.onRestartCheckpoint = { [weak self] in
            self?.resumeGame()
            self?.killPlayer(reason: "manual")
        }
        cameraController.camera.addChild(pause)
        lastPauseOverlay = pause
    }

    private var lastPauseOverlay: PauseOverlay?

    private func resumeGame() {
        lastPauseOverlay?.removeFromParent()
        lastPauseOverlay = nil
        physicsWorld.speed = 1
        audio.resume()
        coordinator.setState(.playing)
    }

    @objc private func frequencyStepped(_ note: Notification) {
        guard let step = note.object as? Int else { return }
        ResonanceSystem.shared.stepFrequency(step)
        hud.updateFrequency(ResonanceSystem.shared.currentFrequency)
        touchControls.flashFrequency(ResonanceSystem.shared.currentFrequency)
    }

    @objc private func frequencyDirect(_ note: Notification) {
        guard let raw = note.object as? String,
              let f = ResonanceFrequency(rawValue: raw) else { return }
        ResonanceSystem.shared.setFrequency(f)
        hud.updateFrequency(f)
        touchControls.flashFrequency(f)
    }

    @objc private func controllerDisconnected() {
        if coordinator.state == .playing { pauseGame() }
    }

    // MARK: - Donanım klavyesi (simülatör / iPad) — UIResponder presses API.
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            if let key = press.key, !key.charactersIgnoringModifiers.isEmpty {
                keyboard.keyDown(String(key.charactersIgnoringModifiers.prefix(1)))
            }
        }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            if let key = press.key, !key.charactersIgnoringModifiers.isEmpty {
                keyboard.keyUp(String(key.charactersIgnoringModifiers.prefix(1)))
            }
        }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        touchControls.layout(for: size)
        hud.layout(for: size)
        debugOverlay.layout(for: size)
    }

    // MARK: - Temizlik — spec 357/358
    override func willMove(from view: SKView) {
        NotificationCenter.default.removeObserver(self)
        ResonanceSystem.shared.reset()
    }
}
