import SpriteKit

/// Etkileşim tespiti ve "interact" ikonu — spec 145/146/147.
final class PlayerInteraction {

    /// Menzil içindeki en yakın rezonansa duyarlı nesne.
    static func nearestReactiveTarget(player: PlayerNode, in scene: GameScene) -> InteractiveObject? {
        var best: InteractiveObject?
        var bestDist = Tuning.interactRange
        for obj in scene.interactiveObjects where obj.isInteractiveActive {
            let d = Math2D.distance(player.position, obj.position)
            if d < bestDist {
                bestDist = d
                best = obj
            }
        }
        return best
    }

    /// Interact ikonu (küçük el işareti yerine: frekans halkası).
    static func buildIcon() -> SKNode {
        let ring = SKShapeNode(circleOfRadius: 16)
        ring.fillColor = .clear
        ring.strokeColor = KIRPalette.dirtyWhite
        ring.lineWidth = 2
        let dot = SKShapeNode(circleOfRadius: 4)
        dot.fillColor = KIRPalette.amber
        dot.strokeColor = KIRPalette.amber
        let holder = SKNode()
        holder.addChild(ring)
        holder.addChild(dot)
        holder.zPosition = 90
        holder.name = NodeNames.interactIcon
        holder.alpha = 0
        return holder
    }

    static func updateIcon(icon: SKNode?, target: InteractiveObject?, playerPosition: CGPoint) {
        guard let icon = icon else { return }
        if let t = target {
            icon.position = CGPoint(x: t.position.x, y: t.position.y + 70)
            icon.run(SKAction.fadeAlpha(to: 0.9, duration: 0.15))
        } else {
            icon.run(SKAction.fadeAlpha(to: 0, duration: 0.2))
        }
    }
}

/// Sahne düğümü isim sabitleri — spec 329 (Magic String yasak).
enum NodeNames {
    static let player = "player"
    static let interactIcon = "interactIcon"
    static let world = "world"
    static let hud = "hud"
    static let overlay = "overlay"
    static let checkpoint = "checkpoint"
    static let exit = "levelExit"
    static let drone = "drone"
    static let pressureWave = "pressureWave"
    static let water = "water"
    static let debris = "debris"
    static let debugLayer = "debugLayer"
}
