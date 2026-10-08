import SpriteKit

/// Checkpoint yaşam döngüsü — spec 29/137/420-423/461-463.
/// Aktivasyon → snapshot → save; ölüm → snapshot restore → respawn.
final class CheckpointManager {

    private(set) var activeCheckpointID: String?
    private var snapshot: LevelManager.Snapshot?
    private weak var scene: GameScene?

    init(scene: GameScene) {
        self.scene = scene
    }

    func beaconReached(_ beacon: CheckpointBeacon, in level: LevelManager) {
        // Spec 137: checkpoint frekansı — checkpoint sırasında dünya durumu da kaydedilir.
        activeCheckpointID = beacon.checkpointID
        snapshot = level.captureSnapshot()
        scene?.coordinator.saveSystem.recordCheckpoint(levelID: level.definition.id,
                                                       checkpointID: beacon.checkpointID)
        // Spec 422: save göstergesi (HUD'da kısa bildirim).
        scene?.hud?.showSaveIndicator()
    }

    /// Ölüm sonrası restore — spec 460/463: JSON yeniden yüklenmez.
    func restoreForRespawn(in level: LevelManager) -> CGPoint {
        if let snap = snapshot {
            level.restore(snapshot: snap)
        }
        let beacon = level.beacons.first { $0.checkpointID == activeCheckpointID }
        if let b = beacon {
            return CGPoint(x: b.position.x, y: b.position.y + 70)
        }
        return level.definition.spawn.cgPoint
    }

    /// Save'den gelirken checkpoint'e göre konum.
    func spawnPoint(fromSave checkpointID: String?, in level: LevelManager) -> CGPoint {
        activeCheckpointID = checkpointID
        if let cp = checkpointID,
           let b = level.beacons.first(where: { $0.checkpointID == cp }) {
            b.activated = true
            b.activateVisualOnly()
            return CGPoint(x: b.position.x, y: b.position.y + 70)
        }
        return level.definition.spawn.cgPoint
    }

    func registerInitialSnapshot(_ snap: LevelManager.Snapshot) {
        if snapshot == nil { snapshot = snap }
    }
}
