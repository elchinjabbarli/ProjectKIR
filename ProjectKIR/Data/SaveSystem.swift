import Foundation

/// Spec 30 (Save Sistemi), 336/337 (Save Bug Testleri), 458-462.
/// Tek slot, Codable JSON, atomik yazım, bozulma fallback'i.
final class SaveSystem {

    /// Spec 30 — önerilen model.
    struct GameSaveData: Codable {
        var version: Int = 1
        var currentLevelID: String = "L01_Arrival"
        var currentCheckpointID: String?
        var completedLevels: [String] = []
        var activatedCheckpoints: [String] = []
        var firedStoryBeats: [String] = []     // spec 453: oynanmış anlar tekrar oynamaz
        var finishedIntro = false
        var completionCount = 0
        var playTimeSeconds: Double = 0
        var lastSavedAt: Date = Date()
    }

    private(set) var data: GameSaveData
    private let fileURL: URL
    private let backupURL: URL
    private let queue = DispatchQueue(label: "kir.save", qos: .utility)

    var hasProgress: Bool {
        return data.finishedIntro || !data.completedLevels.isEmpty || data.currentCheckpointID != nil
    }

    init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = dir.appendingPathComponent("kir_save.json")
        backupURL = dir.appendingPathComponent("kir_save_backup.json")
        data = SaveSystem.load(from: fileURL) ?? SaveSystem.load(from: backupURL) ?? GameSaveData()
    }

    /// Spec 30 — bozuk save çökertmez, default state döner.
    private static func load(from url: URL) -> GameSaveData? {
        guard let raw = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let d = try? decoder.decode(GameSaveData.self, from: raw) else {
            KIRLog.warn("Save dosyası bozuk: \(url.lastPathComponent)")
            return nil
        }
        return d
    }

    /// Atomik yazım + yedek. Spec 30/363.
    func save() {
        data.lastSavedAt = Date()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        guard let raw = try? encoder.encode(data) else { return }
        // Eski sağlam dosyayı yedekle.
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: backupURL)
            try? FileManager.default.copyItem(at: fileURL, to: backupURL)
        }
        try? raw.write(to: fileURL, options: [.atomic])
        KIRLog.info("Save yazıldı: level=\(data.currentLevelID) cp=\(data.currentCheckpointID ?? "-")")
        DispatchQueue.main.async { NotificationCenter.default.post(name: .kirSaveDidWrite, object: nil) }
    }

    func recordCheckpoint(levelID: String, checkpointID: String) {
        data.currentLevelID = levelID
        data.currentCheckpointID = checkpointID
        if !data.activatedCheckpoints.contains(checkpointID) {
            data.activatedCheckpoints.append(checkpointID)
        }
        save()
    }

    func recordLevelComplete(_ levelID: String) {
        if !data.completedLevels.contains(levelID) {
            data.completedLevels.append(levelID)
        }
        data.currentCheckpointID = nil
        data.currentLevelID = levelID
        save()
    }

    func recordSessionTime(_ seconds: Double) {
        data.playTimeSeconds += seconds
    }

    /// Bölüm içinde tetiklenmiş hikâye anları — Continue'da tekrar oynamaz.
    func recordFiredBeats(_ ids: [String]) {
        let known = Set(data.firedStoryBeats)
        let added = ids.filter { !known.contains($0) }
        guard !added.isEmpty else { return }
        data.firedStoryBeats.append(contentsOf: added)
        save()
    }

    func beginNewGame() {
        data = GameSaveData()
        save()
    }

    func markIntroFinished() {
        data.finishedIntro = true
        save()
    }

    func markCompletion() {
        data.completionCount += 1
        save()
    }
}

extension Notification.Name {
    static let kirSaveDidWrite = Notification.Name("kir.save.didWrite")
}
