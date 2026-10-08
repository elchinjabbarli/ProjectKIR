import CoreGraphics

/// Animasyon easing fonksiyonları — spec 8 / dosya yapısı.
enum Easing {

    static func linear(_ t: CGFloat) -> CGFloat { return t }

    static func easeInQuad(_ t: CGFloat) -> CGFloat { return t * t }

    static func easeOutQuad(_ t: CGFloat) -> CGFloat { return 1 - (1 - t) * (1 - t) }

    static func easeInOutQuad(_ t: CGFloat) -> CGFloat {
        return t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }

    static func easeOutCubic(_ t: CGFloat) -> CGFloat {
        return 1 - pow(1 - t, 3)
    }

    static func easeInOutCubic(_ t: CGFloat) -> CGFloat {
        return t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
    }

    /// Yaylı mekanik his (kapı, platform için).
    static func easeOutBack(_ t: CGFloat) -> CGFloat {
        let c1: CGFloat = 1.70158
        let c3: CGFloat = c1 + 1
        let x = t - 1
        return 1 + c3 * x * x * x + c1 * x * x
    }

    /// Decay — rezonans sönümü için.
    static func expDecay(_ t: CGFloat, tau: CGFloat) -> CGFloat {
        return exp(-t / max(0.0001, tau))
    }
}
