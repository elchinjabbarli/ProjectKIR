import SpriteKit

/// Kamera kontrolü — spec 13/73/76/373: sınırlı takip + yumuşatma + shake + look-ahead.
final class CameraController {

    let camera = SKCameraNode()
    private var bounds: CGRect = .infinite
    private var shakeTime: TimeInterval = 0
    private var shakeMagnitude: CGFloat = 0
    private var shakeOffset = CGPoint.zero
    private var lookAhead: CGFloat = 0
    private weak var scene: GameScene?

    /// Odak noktası (cinematic sırasında oyuncu değil beat hedefi).
    var focusOverride: CGPoint?
    var allowLookAhead = true

    init(scene: GameScene) {
        self.scene = scene
        scene.camera = camera
        scene.addChild(camera)
    }

    func setBounds(_ rect: CGRect) {
        bounds = rect
    }

    // MARK: - Shake — spec 82
    func shake(duration: TimeInterval, magnitude: CGFloat) {
        guard let sc = scene, !sc.coordinator.settings.reduceMotion else { return }
        shakeTime = max(shakeTime, duration)
        shakeMagnitude = max(shakeMagnitude, magnitude)
    }

    /// Tek kısa itme (checkpoint).
    func punch(amount: CGFloat) {
        shake(duration: 0.12, magnitude: amount)
    }

    // MARK: - Güncelleme
    func update(dt: TimeInterval, playerPosition: CGPoint, viewSize: CGSize) {
        let target = focusOverride ?? playerPosition

        // Spec 373: hafif ileri bakış.
        if allowLookAhead, let p = scene?.playerNode {
            let dirSign: CGFloat = p.isFacingRight ? 1 : -1
            let spd = abs(p.physicsBody?.velocity.dx ?? 0)
            let t = min(1, spd / Tuning.moveSpeed)
            lookAhead = Math2D.damp(lookAhead, dirSign * 90 * t, smoothing: 0.0005, dt: CGFloat(dt))
        } else {
            lookAhead = 0
        }

        let desired = CGPoint(x: target.x + lookAhead, y: target.y + 40)

        // Yumuşatma
        let pos = camera.position
        let nx = Math2D.damp(pos.x, desired.x, smoothing: 0.0001, dt: CGFloat(dt))
        let ny = Math2D.damp(pos.y, desired.y, smoothing: 0.0002, dt: CGFloat(dt))
        camera.position = CGPoint(x: nx, y: ny)

        // Bounds — spec 230: kamera asla ortamın dışına çıkmaz.
        let hw = viewSize.width / 2
        let hh = viewSize.height / 2
        if bounds != .infinite {
            let minX = bounds.minX + hw
            let maxX = bounds.maxX - hw
            let minY = bounds.minY + hh
            let maxY = bounds.maxY - hh
            if minX < maxX { camera.position.x = Math2D.clamp(camera.position.x, minX, maxX) }
            if minY < maxY { camera.position.y = Math2D.clamp(camera.position.y, minY, maxY) }
        }

        // Shake
        if shakeTime > 0 {
            shakeTime -= dt
            let decay = max(0, CGFloat(shakeTime)) * 2
            shakeOffset = CGPoint(x: CGFloat.random(in: -1...1) * shakeMagnitude * min(1, decay),
                                  y: CGFloat.random(in: -1...1) * shakeMagnitude * min(1, decay))
            camera.position.x += shakeOffset.x
            camera.position.y += shakeOffset.y
        }
    }
}

/// Parallax — spec 14/231: üç uzak katman, sadece görünürken güncellenir.
final class ParallaxController {

    private var layers: [(node: SKNode, factor: CGFloat)] = []
    private weak var camera: SKCameraNode?

    func build(in scene: GameScene, camera: SKCameraNode, palette: SKColor) {
        self.camera = camera
        let viewSize = scene.size
        for (i, factor) in [0.25, 0.45, 0.7].enumerated() {
            let layer = SKNode()
            layer.zPosition = -50 + CGFloat(i) * 10
            // Uzak silüetler: rastgele dikey çubuklar (tesis hissi — spec 130 ölçek).
            var seed = Noise(seed: UInt64(1000 + i * 137))
            let w = viewSize.width * 2.2
            for x in stride(from: -w, to: w, by: 90) {
                let h = 140 + CGFloat(seed.uniform(0, 420))
                let bar = SKShapeNode(rectOf: CGSize(width: 26 + CGFloat(seed.uniform(0, 40)), height: h))
                bar.fillColor = palette.withAlphaComponent(0.10 + 0.05 * CGFloat(i))
                bar.strokeColor = SKColor.clear
                bar.position = CGPoint(x: x + CGFloat(seed.uniform(0, 40)), y: -100 + h / 2)
                bar.isAntialiased = false
                layer.addChild(bar)
            }
            scene.addChild(layer)
            layers.append((layer, factor))
        }
    }

    func update() {
        guard let cam = camera else { return }
        for (layer, f) in layers {
            layer.position = CGPoint(x: cam.position.x * (1 - f), y: cam.position.y * (1 - f) * 0.4)
        }
    }
}
