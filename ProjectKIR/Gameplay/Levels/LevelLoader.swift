import Foundation

/// Level yükleme + doğrulama — spec 158 (Level Validation Tool), 434 (Invalid Level).
final class LevelLoader {

    enum LoadError: Error {
        case notFound(String)
        case malformed(String, String)
    }

    /// Bundle'dan level JSON oku.
    static func load(levelID: String) throws -> LevelDefinition {
        guard let url = Bundle.main.url(forResource: levelID, withExtension: "json") else {
            throw LoadError.notFound(levelID)
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let def = try decoder.decode(LevelDefinition.self, from: data)
            let problems = validate(def)
            if !problems.isEmpty {
                KIRLog.warn("Level doğrulama uyarıları (\(levelID)): \(problems.joined(separator: "; "))")
            }
            return def
        } catch {
            // Spec 434: bozuk level çökertmez.
            throw LoadError.malformed(levelID, String(describing: error))
        }
    }

    /// Basit kural kontrolü — spec 158.
    static func validate(_ def: LevelDefinition) -> [String] {
        var problems: [String] = []
        if def.id != def.id.trimmingCharacters(in: .whitespaces) {
            problems.append("id boşluklu")
        }
        if def.camera.right <= def.camera.left {
            problems.append("kamera sağ<=sol")
        }
        if def.spawn.x < def.camera.left || def.spawn.x > def.camera.right {
            problems.append("spawn kamera dışında")
        }
        if def.checkpoints.isEmpty {
            problems.append("checkpoint yok")
        }
        let known = ["door", "valve", "mirror", "platform", "counterweight", "bridge",
                     "receiver", "drone", "pressurewave", "debris", "silt", "electric", "exit"]
        for e in def.entities where !known.contains(e.type) {
            problems.append("bilinmeyen entity tipi: \(e.type)")
        }
        return problems
    }
}
