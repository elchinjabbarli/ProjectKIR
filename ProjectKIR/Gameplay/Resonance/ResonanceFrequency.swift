import SpriteKit

/// Spec 16 — üç frekans: DEEP / BODY / EDGE.
/// Her frekansın rengi, sesi ve sembol dili farklıdır (spec 303: renk+biçim+ses).
enum ResonanceFrequency: String, CaseIterable, Codable {
    case deep
    case body
    case edge

    /// Spec 88 — temel frekanslar.
    var fundamentalHz: Double {
        switch self {
        case .deep: return 92
        case .body: return 440
        case .edge: return 1760
        }
    }

    /// Spec 89 — şarj sweep aralığı.
    var sweepRange: (start: Double, peak: Double) {
        switch self {
        case .deep: return (70, 110)
        case .body: return (340, 520)
        case .edge: return (1450, 2100)
        }
    }

    /// Spec 200 — biçim dili (görsel ipucu).
    var patternLabel: String {
        switch self {
        case .deep: return "▁▁▁"   // kalın tek katman
        case .body: return "▁▁ ▁▁" // çift
        case .edge: return "▁ ▁ ▁" // kesik ince
        }
    }

    var shortLabel: String {
        switch self {
        case .deep: return "DEEP"
        case .body: return "BODY"
        case .edge: return "EDGE"
        }
    }

    var displayName: String {
        switch self {
        case .deep: return "Derin"
        case .body: return "Gövde"
        case .edge: return "Keskin"
        }
    }

    func next() -> ResonanceFrequency {
        switch self {
        case .deep: return .body
        case .body: return .edge
        case .edge: return .deep
        }
    }

    func previous() -> ResonanceFrequency {
        switch self {
        case .deep: return .edge
        case .body: return .deep
        case .edge: return .body
        }
    }
}
