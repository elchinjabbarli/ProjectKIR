import SpriteKit

/// Basit çevresel tehlikeler — spec 8 dosya yapısındaki üç küçük tehlike.
/// 1. FallingDebris (L06 galerisi): tavandan periyodik düşen parça.
/// 2. SiltBurst (L08 tünelleri): çamur patlaması — yavaşlatır.
/// 3. ElectricLeak (L04–L05): kısa süreli elektrik kaçağı — zamanlama.
final class EnvironmentalHazards {

    // MARK: - FallingDebris
    final class FallingDebris: SKNode {
        private let fallZone: CGRect
        private var timer: TimeInterval
        private let interval: TimeInterval
        private var sceneRef: GameScene?
        private var rng = Noise(seed: 551)

        init(zone: CGRect, interval: TimeInterval = 3.0, startDelay: TimeInterval = 1.0) {
            fallZone = zone
            self.interval = interval
            timer = startDelay
            super.init()
            name = NodeNames.debris
            position = .zero
        }

        required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) kullanılmıyor") }

        func attachScene(_ s: GameScene) { sceneRef = s }

        func update(dt: TimeInterval) {
            timer -= dt
            guard timer <= 0 else { return }
            timer = interval * (0.7 + rng.uniform() * 0.6)
            spawnChunk()
        }

        private func spawnChunk() {
            let size = CGSize(width: 18 + CGFloat(rng.uniform(0, 14)),
                              height: 14 + CGFloat(rng.uniform(0, 10)))
            let chunk = SKShapeNode(rectOf: size, cornerRadius: 2)
            chunk.fillColor = KIRPalette.ash
            chunk.strokeColor = KIRPalette.rust
            let x = fallZone.minX + CGFloat(rng.uniform(0, Double(fallZone.width)))
            chunk.position = CGPoint(x: x, y: fallZone.maxY)
            chunk.zPosition = 22
            chunk.name = NodeNames.debris
            sceneRef?.worldNode?.addChild(chunk)

            let body = SKPhysicsBody(rectangleOf: size)
            body.categoryBitMask = PhysicsCategory.debris
            body.collisionBitMask = PhysicsCategory.world | PhysicsCategory.player
            body.contactTestBitMask = PhysicsCategory.player
            body.affectedByGravity = true
            chunk.physicsBody = body

            chunk.run(SKAction.sequence([
                SKAction.wait(forDuration: 4.0),
                SKAction.fadeOut(withDuration: 0.6),
                SKAction.removeFromParent()
            ]))
            sceneRef?.audio.playDebrisFall()
        }
    }

    // MARK: - SiltBurst
    final class SiltBurst: SKNode {
        private var timer: TimeInterval = 0
        private let interval: TimeInterval
        private let region: CGRect
        private var sceneRef: GameScene?
        private var active = false
        private let cloud: SKShapeNode

        init(region: CGRect, interval: TimeInterval = 6.0) {
            self.region = region
            self.interval = interval
            cloud = SKShapeNode(rectOf: region.size, cornerRadius: 12)
            cloud.fillColor = SKColor(red: 0.35, green: 0.30, blue: 0.24, alpha: 0)
            cloud.strokeColor = SKColor(red: 0.4, green: 0.35, blue: 0.28, alpha: 0.3)
            cloud.zPosition = 30
            super.init()
            position = CGPoint(x: region.midX, y: region.midY)
            addChild(cloud)
        }

        required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) kullanılmıyor") }

        func attachScene(_ s: GameScene) { sceneRef = s }

        func update(dt: TimeInterval, player: PlayerNode) {
            timer -= dt
            if timer <= 0 && !active {
                active = true
                timer = 2.2
                cloud.run(SKAction.fadeAlpha(to: 0.75, duration: 0.3))
                sceneRef?.audio.playSiltBurst()
            } else if active {
                if timer <= 0 {
                    active = false
                    timer = interval
                    cloud.run(SKAction.fadeAlpha(to: 0, duration: 0.8))
                } else if region.contains(player.position) {
                    // Silt içinde hareket yavaşlar (spec 55 bölgesel his).
                    if let b = player.physicsBody {
                        b.velocity.dx *= 0.965
                    }
                }
            }
        }
    }

    // MARK: - ElectricLeak
    final class ElectricLeak: SKNode {
        private var timer: TimeInterval = 0
        private let activeDuration: TimeInterval
        private let interval: TimeInterval
        private var active = false
        private var sceneRef: GameScene?
        private let arc: SKShapeNode
        private let zoneSize: CGSize

        init(position pos: CGPoint, size: CGSize, interval: TimeInterval = 4.0, activeDuration: TimeInterval = 0.8) {
            self.zoneSize = size
            self.interval = interval
            self.activeDuration = activeDuration
            arc = SKShapeNode(rectOf: size, cornerRadius: 4)
            arc.fillColor = SKColor(red: 0.85, green: 0.8, blue: 0.5, alpha: 0.0)
            arc.strokeColor = KIRPalette.amber
            arc.lineWidth = 2
            arc.zPosition = 28
            super.init()
            position = pos
            addChild(arc)
            // Gövde yalnızca AKTİF fazda var — pasif sızıntı görünmez ölüm alanı olmaz.
        }

        required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) kullanılmıyor") }

        func attachScene(_ s: GameScene) { sceneRef = s }

        private func makeBody() -> SKPhysicsBody {
            let body = SKPhysicsBody(rectangleOf: zoneSize)
            body.categoryBitMask = PhysicsCategory.hazard
            body.collisionBitMask = PhysicsCategory.none
            body.contactTestBitMask = PhysicsCategory.player
            body.isDynamic = false
            body.affectedByGravity = false
            return body
        }

        func update(dt: TimeInterval, player: PlayerNode) {
            timer -= dt
            if !active && timer <= 0 {
                active = true
                timer = activeDuration
                physicsBody = makeBody()
                arc.run(SKAction.fadeAlpha(to: 0.65, duration: 0.08))
                sceneRef?.audio.playElectricLeak()
            } else if active && timer <= 0 {
                active = false
                timer = interval
                physicsBody = nil
                arc.run(SKAction.fadeAlpha(to: 0, duration: 0.3))
            }
            if active {
                // Aktifken titreşir.
                arc.alpha = CGFloat.random(in: 0.35...0.75)
                if Math2D.distance(position, player.position) < max(zoneSize.width, zoneSize.height) / 2 + 26 {
                    sceneRef?.killPlayer(reason: "electric")
                }
            }
        }
    }
}
