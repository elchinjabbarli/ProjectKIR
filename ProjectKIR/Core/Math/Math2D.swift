import CoreGraphics

/// 2B matematik yardımcıları.
enum Math2D {

    static func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        return max(lo, min(hi, v))
    }

    static func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        return a + (b - a) * t
    }

    /// Frame-rate bağımsız yumuşatma.
    static func damp(_ current: CGFloat, _ target: CGFloat, smoothing: CGFloat, dt: CGFloat) -> CGFloat {
        let t = 1.0 - pow(smoothing, dt)
        return current + (target - current) * t
    }

    static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        return hypot(a.x - b.x, a.y - b.y)
    }

    static func direction(from a: CGPoint, to b: CGPoint) -> CGVector {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let len = max(0.0001, hypot(dx, dy))
        return CGVector(dx: dx / len, dy: dy / len)
    }

    static func angle(of v: CGVector) -> CGFloat {
        return atan2(v.dy, v.dx)
    }

    static func point(from p: CGPoint, direction: CGVector, distance d: CGFloat) -> CGPoint {
        return CGPoint(x: p.x + direction.dx * d, y: p.y + direction.dy * d)
    }
}
