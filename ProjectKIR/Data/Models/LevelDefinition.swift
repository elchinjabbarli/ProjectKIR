import Foundation

/// Level JSON veri modelleri — spec 31 (Level Format), 452-457.
/// Statik tanım (immutable); runtime durumu ayrı tutulur (spec 457).

// MARK: - Kök
struct LevelDefinition: Codable {
    let id: String
    let name: String
    let chapter: Int
    /// Bu bölümde açık olan frekanslar — kademeli tanıtım (spec 894, M02/M03).
    /// Yoksa üçü de açıktır.
    let frequencies: [String]?
    let spawn: LevelPoint
    let camera: LevelCameraBounds
    let ambient: LevelAmbient?
    let solids: [LevelSolid]
    let entities: [LevelEntity]
    let water: [LevelWater]
    let checkpoints: [LevelCheckpoint]
    let storyBeats: [LevelStoryBeat]?
    let intro: String?

    /// Kod tarafına hazır çözülmüş frekans listesi.
    var allowedFrequencies: [ResonanceFrequency] {
        guard let raw = frequencies, !raw.isEmpty else { return ResonanceFrequency.allCases }
        let fs = raw.compactMap { ResonanceFrequency(rawValue: $0) }
        return fs.isEmpty ? ResonanceFrequency.allCases : fs
    }
}

struct LevelPoint: Codable {
    let x: Double
    let y: Double
    var cgPoint: CGPoint { CGPoint(x: x, y: y) }
}

struct LevelCameraBounds: Codable {
    let left: Double
    let right: Double
    let top: Double
    let bottom: Double
    var rect: CGRect {
        return CGRect(x: left, y: bottom,
                      width: right - left,
                      height: top - bottom)
    }
}

struct LevelAmbient: Codable {
    let palette: String?      // bölüm renk adı
    let musicState: String?   // calm / tense / sparse / silence
    let droneDensity: Double?
}

struct LevelSolid: Codable {
    let id: String
    let type: String           // ground / wall / ceiling / lowceiling / cover / platform
    let x: Double
    let y: Double
    let w: Double
    let h: Double
}

struct LevelCheckpoint: Codable {
    let id: String
    let x: Double
    let y: Double
    var point: CGPoint { CGPoint(x: x, y: y) }
}

// MARK: - Su
struct LevelWater: Codable {
    let id: String
    let x: Double
    let baseY: Double
    let width: Double
    let start: String
    let low: Double
    let mid: Double
    let high: Double

    var startLevel: ValveNode.WaterLevel { ValveNode.WaterLevel(rawValue: start) ?? .low }
}

// MARK: - Entity
/// JSON tarafında özellikler DÜZ (flat) yazılır: {"type":"door","frequency":"deep"}.
/// Decoder, rezerve alanlar dışındaki tüm anahtarları `properties` sözlüğüne toplar.
struct LevelEntity: Codable {
    let id: String
    let type: String
    let x: Double
    let y: Double
    let rotation: Double?
    let properties: [String: LevelPropertyValue]

    private struct AnyKey: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init(stringValue s: String) { stringValue = s }
        init?(intValue: Int) { return nil }
        init(_ s: String) { stringValue = s }
    }

    private static let reserved = ["id", "type", "x", "y", "rotation"]

    init(id: String, type: String, x: Double, y: Double,
         rotation: Double? = nil, properties: [String: LevelPropertyValue] = [:]) {
        self.id = id
        self.type = type
        self.x = x
        self.y = y
        self.rotation = rotation
        self.properties = properties
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        guard let id = try? c.decode(String.self, forKey: AnyKey("id")),
              let type = try? c.decode(String.self, forKey: AnyKey("type")),
              let x = try? c.decode(Double.self, forKey: AnyKey("x")),
              let y = try? c.decode(Double.self, forKey: AnyKey("y")) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath,
                                     debugDescription: "Entity id/type/x/y zorunludur"))
        }
        self.id = id
        self.type = type
        self.x = x
        self.y = y
        self.rotation = try? c.decodeIfPresent(Double.self, forKey: AnyKey("rotation"))

        var props: [String: LevelPropertyValue] = [:]
        for key in c.allKeys where !LevelEntity.reserved.contains(key.stringValue) {
            if let v = try? c.decode(LevelPropertyValue.self, forKey: key) {
                props[key.stringValue] = v
            }
        }
        self.properties = props
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: AnyKey.self)
        try c.encode(id, forKey: AnyKey("id"))
        try c.encode(type, forKey: AnyKey("type"))
        try c.encode(x, forKey: AnyKey("x"))
        try c.encode(y, forKey: AnyKey("y"))
        try c.encodeIfPresent(rotation, forKey: AnyKey("rotation"))
        for (k, v) in properties {
            try c.encode(v, forKey: AnyKey(k))
        }
    }

    func string(_ key: String, _ def: String? = nil) -> String? {
        if let v = properties[key], case .string(let s) = v { return s }
        return def
    }
    func double(_ key: String, _ def: Double) -> Double {
        if let v = properties[key], case .number(let n) = v { return n }
        return def
    }
    func numberArray(_ key: String) -> [Double] {
        if let v = properties[key], case .numberArray(let a) = v { return a }
        return []
    }
    func stringArray(_ key: String) -> [String] {
        if let v = properties[key], case .stringArray(let a) = v { return a }
        return []
    }
    func bool(_ key: String, _ def: Bool) -> Bool {
        if let v = properties[key] {
            switch v {
            case .bool(let b): return b
            case .number(let n): return n != 0
            default: break
            }
        }
        return def
    }
}

enum LevelPropertyValue: Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case stringArray([String])
    case numberArray([Double])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { self = .string(s); return }
        if let b = try? c.decode(Bool.self) { self = .bool(b); return }
        if let n = try? c.decode(Double.self) { self = .number(n); return }
        if let a = try? c.decode([String].self) { self = .stringArray(a); return }
        if let a = try? c.decode([Double].self) { self = .numberArray(a); return }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "Desteklenmeyen property tipi")
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .number(let n): try c.encode(n)
        case .bool(let b): try c.encode(b)
        case .stringArray(let a): try c.encode(a)
        case .numberArray(let a): try c.encode(a)
        }
    }
}

// MARK: - Story beat — spec 453
struct LevelStoryBeat: Codable {
    let id: String
    let triggerType: String       // enter / checkpoint / receiver / distance / radio
    let triggerID: String?
    let x: Double?
    let y: Double?
    let cameraMode: String?       // focus / wide / hold
    let audioCue: String?
    let caption: String?          // opsiyonel — altyazı
    let duration: Double
    let playerLocked: Bool
    let once: Bool?
}

/// Bölüm geçiş kartı verisi — spec 136.
struct ChapterInfo {
    let levelID: String
    var number: Int { Int(levelID.prefix(2)) ?? 0 }
    var title: String {
        switch levelID {
        case let s where s.hasPrefix("L01"): return "Varış"
        case let s where s.hasPrefix("L02"): return "Alım Odası"
        case let s where s.hasPrefix("L03"): return "Körük Salonu"
        case let s where s.hasPrefix("L04"): return "Bahçe Kenarı"
        case let s where s.hasPrefix("L05"): return "Karşı Ağırlık Evi"
        case let s where s.hasPrefix("L06"): return "Basınç Galerisi"
        case let s where s.hasPrefix("L07"): return "Sel Odası"
        case let s where s.hasPrefix("L08"): return "Balçık Tünelleri"
        case let s where s.hasPrefix("L09"): return "Ayna Havzası"
        case let s where s.hasPrefix("L10"): return "Sessiz Motor"
        default: return ""
        }
    }
}
