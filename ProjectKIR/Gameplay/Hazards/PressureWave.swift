import SpriteKit

/// Basınç dalgası — spec 49/396: uyarı fazı + dalga geçişi + cover sistemi.
/// Savaş değil, zamanlama tehlikesi (spec 24).
final class PressureWaveZone: SKNode {

    private let interval: TimeInterval
    private let warningDuration: TimeInterval
    private var timer: TimeInterval
    private(set) var phase: Phase = .idle
    private var elapsed: TimeInterval = 0

    enum Phase: String {
        case idle       // bekleme
        case warning     // düşük uğultu + titreşim (spec 49)
        case wave        // dalga geçiyor
    }

    private let zoneRect: CGRect
    private let waveVisual: SKShapeNode
    private var sceneRef: GameScene?
    private var coveredPositions: [CGRect] = []

    init(rect: CGRect, interval: TimeInterval = 5.0, warningDuration: TimeInterval = 1.2) {
        self.zoneRect = rect
        self.interval = interval
        self.warningDuration = warningDuration
        self.timer = interval * 0.6
        waveVisual = SKShapeNode(rectOf: rect.size, cornerRadius: 6)
        waveVisual.fillColor = SKColor(white: 1, alpha: 0.0)
        waveVisual.strokeColor = KIRPalette.coldBlue.withAlphaComponent(0.10)
        waveVisual.lineWidth = 2
        waveVisual.zPosition = 5
        super.init()
        name = NodeNames.pressureWave
        position = CGPoint(x: rect.midX, y: rect.midY)
        waveVisual.isHidden = true
        addChild(waveVisual)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) kullanılmıyor") }

    func attachScene(_ scene: GameScene) { sceneRef = scene }

    /// Cover bölgeleri kaydı (alçak duvarlar) — spec 49.
    func registerCover(_ rect: CGRect) {
        coveredPositions.append(rect)
    }

    private func isPlayerCovered(player: PlayerNode) -> Bool {
        for c in coveredPositions {
            if c.contains(player.position) { return true }
        }
        return false
    }

    func update(dt: TimeInterval, player: PlayerNode) {
        timer -= dt
        switch phase {
        case .idle:
            if timer <= 0 {
                phase = .warning
                elapsed = warningDuration
                sceneRef?.audio.playPressureWarning()
                waveVisual.isHidden = false
                waveVisual.fillColor = KIRPalette.coldBlue.withAlphaComponent(0.06)
            }
        case .warning:
            elapsed -= dt
            // Toz titremesi — görsel uyarı (spec 49).
            waveVisual.alpha = 0.5 + CGFloat(sin(elapsed * 30)) * 0.3
            if elapsed <= 0 {
                phase = .wave
                elapsed = 0.9
                sceneRef?.audio.playPressureWave()
                sceneRef?.haptics.doorRumble()
                waveVisual.fillColor = KIRPalette.dirtyWhite.withAlphaComponent(0.22)
                waveVisual.run(SKAction.sequence([
                    SKAction.scaleY(to: 1.25, duration: 0.12),
                    SKAction.scaleY(to: 1.0, duration: 0.3)
                ]))
            }
        case .wave:
            elapsed -= dt
            let playerInZone = zoneRect.contains(player.position)
            if playerInZone && !isPlayerCovered(player: player) {
                // Dalga oyuncuyu savurur; açık alındaysa ölümcül (spec 49).
                if let b = player.physicsBody {
                    b.velocity.dx += 620 * dt
                }
                if elapsed < 0.45 {
                    sceneRef?.killPlayer(reason: "pressure")
                }
            }
            if elapsed <= 0 {
                phase = .idle
                timer = interval
                waveVisual.isHidden = true
                waveVisual.alpha = 1
            }
        }
    }

    var zone: CGRect { return zoneRect }
}
