import SpriteKit

/// Paylaşılan kısa CG/SK extension'ları.
extension CGPoint {
    static func + (a: CGPoint, b: CGPoint) -> CGPoint {
        return CGPoint(x: a.x + b.x, y: a.y + b.y)
    }
    static func - (a: CGPoint, b: CGPoint) -> CGPoint {
        return CGPoint(x: a.x - b.x, y: a.y - b.y)
    }
    static func * (a: CGPoint, s: CGFloat) -> CGPoint {
        return CGPoint(x: a.x * s, y: a.y * s)
    }
}

extension SKShapeNode {
    /// Doku yok — spec 233 placeholder stratejisi.
    static func box(size: CGSize, fill: SKColor, stroke: SKColor? = nil, lineWidth: CGFloat = 2) -> SKShapeNode {
        let node = SKShapeNode(rectOf: size, cornerRadius: 3)
        node.fillColor = fill
        node.strokeColor = stroke ?? fill
        node.lineWidth = lineWidth
        node.isAntialiased = false
        return node
    }
}

extension SKLabelNode {
    static func caption(_ text: String, size: CGFloat = 14, color: SKColor) -> SKLabelNode {
        let l = SKLabelNode(text: text)
        l.fontName = "AvenirNext-Medium"
        l.fontSize = size
        l.fontColor = color
        l.verticalAlignmentMode = .center
        l.horizontalAlignmentMode = .center
        return l
    }
}
