import SpriteKit

/// Level inşası ve runtime durumu — spec 8/246 (Entity Factory), 247 (World Node), 459-462.
/// GameScene'e tüm düğümleri kurar; checkpoint snapshot'ları bu sınıftan gelir.
final class LevelManager {

    let definition: LevelDefinition
    private(set) var interactiveObjects: [InteractiveObject] = []
    private(set) var beacons: [CheckpointBeacon] = []
    private(set) var drones: [PatrolDrone] = []
    private(set) var waves: [PressureWaveZone] = []
    private(set) var debrisSpawners: [EnvironmentalHazards.FallingDebris] = []
    private(set) var siltZones: [EnvironmentalHazards.SiltBurst] = []
    private(set) var leaks: [EnvironmentalHazards.ElectricLeak] = []
    private(set) var waterNodes: [WaterNode] = []
    private(set) var exits: [LevelExitNode] = []
    private(set) var platforms: [PlatformNode] = []

    /// Runtime state — spec 459.
    struct LevelRuntimeState {
        var completedInteractions: Set<String> = []
        var activatedCheckpoints: Set<String> = []
        var waterStates: [String: String] = [:]
    }
    private(set) var runtime = LevelRuntimeState()

    init(definition: LevelDefinition) {
        self.definition = definition
    }

    // MARK: - Dünya inşası
    func build(in scene: GameScene) {
        buildGeometry(in: scene)
        buildEntities(in: scene)
        buildWater(in: scene)
        buildCheckpoints(in: scene)
        // Yüzen platformları su yüzeyine bağla (spec 37).
        for plat in platforms where plat.mode == .floating {
            let nearest = waterNodes.min {
                Math2D.distance($0.position, plat.position) < Math2D.distance($1.position, plat.position)
            }
            nearest?.attachFloatPlatform(plat)
        }
        // Zincir bağlantılarını çöz (spec 20).
        resolveLinks(in: scene)
    }

    /// Zemin geometrisi — placeholder kutular (spec 233).
    private func buildGeometry(in scene: GameScene) {
        for solid in definition.solids {
            let size = CGSize(width: solid.w, height: solid.h)
            let node = SKShapeNode(rectOf: size, cornerRadius: 2)
            switch solid.type {
            case "cover":
                node.fillColor = KIRPalette.ash
                node.strokeColor = KIRPalette.dirtyWhite
                scene.registerCover(rect: CGRect(x: solid.x - solid.w / 2 - 8,
                                                  y: solid.y - solid.h / 2 - 20,
                                                  width: solid.w + 16,
                                                  height: solid.h + 40))
            case "lowceiling", "ceiling":
                node.fillColor = SKColor(white: 0.05, alpha: 1)
                node.strokeColor = KIRPalette.ash
            case "platform":
                node.fillColor = KIRPalette.ash
                node.strokeColor = KIRPalette.rust
            default:
                node.fillColor = KIRPalette.ash
                node.strokeColor = KIRPalette.ash
            }
            node.isAntialiased = false
            node.position = CGPoint(x: solid.x, y: solid.y)
            node.zPosition = 10
            scene.worldNode.addChild(node)

            if solid.type != "decor" {
                let body = SKPhysicsBody(rectangleOf: size)
                body.categoryBitMask = PhysicsCategory.world
                body.collisionBitMask = PhysicsCategory.player | PhysicsCategory.debris
                body.isDynamic = false
                body.affectedByGravity = false
                body.friction = 0.9
                node.physicsBody = body
            }
        }
    }

    // MARK: - Entity factory — spec 246
    private func buildEntities(in scene: GameScene) {
        for e in definition.entities {
            let node = makeEntity(e, scene: scene)
            if let obj = node as? InteractiveObject {
                interactiveObjects.append(obj)
            }
        }
    }

    private func makeEntity(_ e: LevelEntity, scene: GameScene) -> SKNode {
        switch e.type {
        case "door":
            var config = DoorNode.Config()
            config.frequency = ResonanceFrequency(rawValue: e.string("frequency") ?? "deep") ?? .deep
            let seq = e.stringArray("sequence").compactMap { ResonanceFrequency(rawValue: $0) }
            config.sequence = seq
            config.autoClose = e.bool("autoClose", false)
            config.width = CGFloat(e.double("width", 60))
            config.height = CGFloat(e.double("height", 170))
            config.openDuration = e.double("openDuration", 1.3)
            let door = DoorNode(entityID: e.id, config: config)
            door.position = e.positionPoint
            door.attachScene(scene)
            door.zPosition = 18
            scene.worldNode.addChild(door)
            return door

        case "valve":
            let waterID = e.string("waterID", "w1") ?? "w1"
            let levelRaw = e.string("level", "mid") ?? "mid"
            let level = ValveNode.WaterLevel(rawValue: levelRaw) ?? .mid
            let freq = ResonanceFrequency(rawValue: e.string("frequency", "deep") ?? "deep") ?? .deep
            let valve = ValveNode(entityID: e.id, waterID: waterID, level: level, frequency: freq)
            valve.position = e.positionPoint
            valve.attachScene(scene)
            scene.worldNode.addChild(valve)
            return valve

        case "mirror":
            let o = MirrorNode.Orientation(rawValue: e.string("orientation", "up") ?? "up") ?? .up
            let mirror = MirrorNode(entityID: e.id, orientation: o)
            mirror.position = e.positionPoint
            mirror.attachScene(scene)
            scene.worldNode.addChild(mirror)
            return mirror

        case "platform":
            var waypoints: [PlatformNode.Waypoint] = []
            let xs = e.numberArray("pathX")
            let ys = e.numberArray("pathY")
            let pauses = e.numberArray("pauses")
            let base = e.positionPoint
            waypoints.append(PlatformNode.Waypoint(position: base, pause: pauses.first ?? 0.6))
            for i in 0..<max(xs.count, ys.count) {
                let wx = i < xs.count ? base.x + CGFloat(xs[i]) : base.x
                let wy = i < ys.count ? base.y + CGFloat(ys[i]) : base.y
                waypoints.append(PlatformNode.Waypoint(position: CGPoint(x: wx, y: wy),
                                                       pause: i < pauses.count ? pauses[i] : 0.6))
            }
            let mode = PlatformNode.Mode(rawValue: e.string("mode", "looping") ?? "looping") ?? .looping
            let size = CGSize(width: e.double("w", 140), height: e.double("h", 22))
            let plat = PlatformNode(entityID: e.id, size: size, mode: mode, waypoints: waypoints)
            plat.position = base
            plat.attachScene(scene)
            scene.worldNode.addChild(plat)
            platforms.append(plat)
            return plat

        case "counterweight":
            let travel = CGVector(dx: CGFloat(e.double("travelX", 0)), dy: CGFloat(e.double("travelY", -160)))
            let cw = CounterweightNode(entityID: e.id,
                                       linkedID: e.string("linkedID", "") ?? "",
                                       travel: travel,
                                       size: CGSize(width: e.double("w", 54), height: e.double("h", 54)))
            cw.position = e.positionPoint
            cw.attachScene(scene)
            cw.zPosition = 18
            scene.worldNode.addChild(cw)
            return cw

        case "bridge":
            let bridge = ResonanceBridgeNode(entityID: e.id,
                                             length: CGFloat(e.double("length", 240)),
                                             angle: CGFloat(e.double("angle", 0)),
                                             duration: e.double("duration", 4.5))
            bridge.position = e.positionPoint
            bridge.attachScene(scene)
            scene.worldNode.addChild(bridge)
            return bridge

        case "receiver":
            let freq = ResonanceFrequency(rawValue: e.string("frequency", "deep") ?? "deep") ?? .deep
            let recv = ReceiverNode(entityID: e.id, frequency: freq, linkedIDs: e.stringArray("linked"))
            recv.position = e.positionPoint
            recv.attachScene(scene)
            scene.worldNode.addChild(recv)
            return recv

        case "drone":
            var path: [CGPoint] = []
            let xs = e.numberArray("pathX")
            let ys = e.numberArray("pathY")
            let base = e.positionPoint
            path.append(base)
            for i in 0..<max(xs.count, ys.count) {
                let px = i < xs.count ? base.x + CGFloat(xs[i]) : base.x
                let py = i < ys.count ? base.y + CGFloat(ys[i]) : base.y
                path.append(CGPoint(x: px, y: py))
            }
            let drone = PatrolDrone(path: path)
            drone.attachScene(scene)
            scene.worldNode.addChild(drone)
            drones.append(drone)
            return drone

        case "pressurewave":
            let x = e.positionPoint.x, y = e.positionPoint.y
            let w = e.double("w", 600), h = e.double("h", 400)
            let wave = PressureWaveZone(rect: CGRect(x: x - w / 2, y: y - h / 2, width: w, height: h),
                                        interval: e.double("interval", 5.0),
                                        warningDuration: e.double("warning", 1.2))
            wave.attachScene(scene)
            scene.worldNode.addChild(wave)
            // Bölgedeki sığınakları dalga sistemine bağla (spec 49).
            for c in scene.covers where c.intersects(wave.zone) {
                wave.registerCover(c)
            }
            waves.append(wave)
            return wave

        case "debris":
            let x = e.positionPoint.x, y = e.positionPoint.y
            let w = e.double("w", 400), h = e.double("h", 200)
            let d = EnvironmentalHazards.FallingDebris(zone: CGRect(x: x - w / 2, y: y - h / 2, width: w, height: h),
                                                       interval: e.double("interval", 3.0))
            d.attachScene(scene)
            scene.worldNode.addChild(d)
            debrisSpawners.append(d)
            return d

        case "silt":
            let x = e.positionPoint.x, y = e.positionPoint.y
            let w = e.double("w", 300), h = e.double("h", 120)
            let s = EnvironmentalHazards.SiltBurst(region: CGRect(x: x - w / 2, y: y - h / 2, width: w, height: h),
                                                   interval: e.double("interval", 6.0))
            s.attachScene(scene)
            scene.worldNode.addChild(s)
            siltZones.append(s)
            return s

        case "electric":
            let leak = EnvironmentalHazards.ElectricLeak(
                position: e.positionPoint,
                size: CGSize(width: e.double("w", 80), height: e.double("h", 60)),
                interval: e.double("interval", 4.0))
            leak.attachScene(scene)
            scene.worldNode.addChild(leak)
            leaks.append(leak)
            return leak

        case "exit":
            let exit = LevelExitNode(position: e.positionPoint,
                                     size: CGSize(width: e.double("w", 70), height: e.double("h", 150)))
            exit.attachScene(scene)
            scene.worldNode.addChild(exit)
            exits.append(exit)
            return exit

        default:
            // Spec 435: bilinmeyen tip — görünmez işaret düğümü, çökertmez.
            KIRLog.warn("Bilinmeyen entity: \(e.type)/\(e.id)")
            let unknown = SKNode()
            unknown.position = e.positionPoint
            scene.worldNode.addChild(unknown)
            return unknown
        }
    }

    // MARK: - Su
    private func buildWater(in scene: GameScene) {
        for w in definition.water {
            let levels: [ValveNode.WaterLevel: CGFloat] = [
                .low: CGFloat(w.low), .mid: CGFloat(w.mid), .high: CGFloat(w.high)
            ]
            let water = WaterNode(entityID: w.id, x: CGFloat(w.x), baseY: CGFloat(w.baseY),
                                  width: CGFloat(w.width), levels: levels, start: w.startLevel)
            water.attachScene(scene)
            scene.worldNode.addChild(water)
            waterNodes.append(water)
            runtime.waterStates[w.id] = w.startLevel.rawValue
        }
    }

    // MARK: - Checkpoint
    private func buildCheckpoints(in scene: GameScene) {
        for c in definition.checkpoints {
            let beacon = CheckpointBeacon(levelID: definition.id, checkpointID: c.id, position: c.point)
            beacon.attachScene(scene)
            scene.worldNode.addChild(beacon)
            beacons.append(beacon)
        }
    }

    // MARK: - Zincir çözümü — spec 20/258
    private func resolveLinks(in scene: GameScene) {
        for e in definition.entities {
            let linked = e.stringArray("linked")
            guard !linked.isEmpty else { continue }
            if let obj = interactiveObjects.first(where: { $0.entityID == e.id }) {
                obj.linkedIDs = linked
            }
        }
    }

    /// Zincir tetikleme — event system (spec 258).
    func triggerChain(from source: InteractiveObject, frequency: ResonanceFrequency, in scene: GameScene) {
        for linkID in source.linkedIDs {
            guard let target = interactiveObjects.first(where: { $0.entityID == linkID }) else { continue }
            ResonanceVisuals.chainBeam(from: source.position, to: target.position,
                                       color: KIRPalette.color(for: frequency), parent: scene.worldNode)
            let pulse = ResonancePulse(origin: target.position,
                                        direction: CGVector(dx: 0, dy: 1),
                                        frequency: frequency,
                                        strength: 1,
                                        maxRange: 60)
            target.receiveResonance(pulse)
            scene.broadcastSound(SoundEvent(position: target.position,
                                            intensity: SoundEvent.noiseScore(.mechanical),
                                            category: .mechanical))
            runtime.completedInteractions.insert("\(source.entityID)->\(linkID)")
        }
    }

    // MARK: - Su seviyesi
    func setWaterLevel(waterID: String, level: ValveNode.WaterLevel) {
        if let w = waterNodes.first(where: { $0.entityID == waterID }) {
            w.setLevel(level)
            runtime.waterStates[waterID] = level.rawValue
        }
    }

    // MARK: - Checkpoint snapshot — spec 461/462
    struct Snapshot {
        let runtime: LevelRuntimeState
        let waterCurrents: [String: ValveNode.WaterLevel]
        let droneStates: [PatrolDrone.State]
        let doorOpenStates: [String: Bool]
        let beaconActives: [String]
    }

    func captureSnapshot() -> Snapshot {
        let water = waterNodes.map { ($0.entityID, $0.currentLevel) }
        let doors = interactiveObjects.compactMap { obj -> (String, Bool)? in
            guard let d = obj as? DoorNode else { return nil }
            return (d.entityID, d.isOpen)
        }
        return Snapshot(runtime: runtime,
                        waterCurrents: Dictionary(water, uniquingKeysWith: { a, _ in a }),
                        droneStates: drones.map { $0.state },
                        doorOpenStates: Dictionary(doors, uniquingKeysWith: { a, _ in a }),
                        beaconActives: beacons.filter { $0.activated }.map { $0.checkpointID })
    }

    func restore(snapshot: Snapshot) {
        runtime = snapshot.runtime
        for (id, lvl) in snapshot.waterCurrents {
            if let w = waterNodes.first(where: { $0.entityID == id }) {
                w.reset(to: lvl)
            }
        }
        for d in drones { d.reset() }
        for obj in interactiveObjects {
            (obj as? DoorNode)?.reset()
            (obj as? PlatformNode)?.reset()
            (obj as? CounterweightNode)?.reset()
            (obj as? ReceiverNode)?.reset()
            (obj as? ValveNode)?.reset()
            (obj as? MirrorNode)?.reset()
            (obj as? ResonanceBridgeNode)?.reset()
            obj.resetPulseMemory()
        }
        for b in beacons where snapshot.beaconActives.contains(b.checkpointID) {
            b.activated = true
            b.activateVisualOnly()
        }
        for (id, open) in snapshot.doorOpenStates where open {
            if let d = interactiveObjects.first(where: { $0.entityID == id }) as? DoorNode {
                d.reopenSilently()
            }
        }
    }
}

extension LevelEntity {
    var positionPoint: CGPoint { CGPoint(x: x, y: y) }
}
