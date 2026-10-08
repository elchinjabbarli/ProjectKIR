import SpriteKit

/// Hikâye vuruşları — spec 259/260/261, 121/122 (radyo parçaları).
/// Tetikleyiciler: checkpoint, receiver, mesafe, radio.
/// Sinematik kilit + kamera odak + ses işareti + (ops.) altyazı.
final class StoryBeatSystem {

    private var beats: [LevelStoryBeat] = []
    private var fired: Set<String> = []
    private weak var scene: GameScene?
    private var activeLockTimer: Double = 0
    private(set) var isCinematicLock = false

    init(beats: [LevelStoryBeat]?, scene: GameScene) {
        self.beats = beats ?? []
        self.scene = scene
    }

    /// Save'den gelen: daha önce tetiklenenler.
    func markFired(_ ids: [String]) {
        fired.formUnion(ids)
    }

    func update(dt: TimeInterval, playerPosition: CGPoint) {
        guard let sc = scene else { return }

        if isCinematicLock {
            activeLockTimer -= dt
            if activeLockTimer <= 0 {
                isCinematicLock = false
                sc.cameraController.focusOverride = nil
                sc.cinematicLockEnded()
            }
        }

        for beat in beats where !fired.contains(beat.id) {
            let shouldFire: Bool
            switch beat.triggerType {
            case "distance":
                let bx = beat.x ?? 0
                let by = beat.y ?? 0
                shouldFire = Math2D.distance(playerPosition, CGPoint(x: bx, y: by)) < 140
            case "enter":
                // Eşik geçişi: verilen x'e sağdan ulaşınca tetiklenir.
                shouldFire = playerPosition.x > (beat.x ?? -999999)
            default:
                shouldFire = false
            }
            if shouldFire {
                fire(beat)
            }
        }
    }

    /// Olay bazlı tetikler (checkpoint/receiver/radio) — GameScene çağırır.
    func handleEvent(type: String, id: String) {
        for beat in beats where beat.triggerType == type && beat.triggerID == id && !fired.contains(beat.id) {
            fire(beat)
        }
    }

    private func fire(_ beat: LevelStoryBeat) {
        guard let sc = scene else { return }
        let once = beat.once ?? true
        if once { fired.insert(beat.id) }

        // Ses işareti.
        if let cue = beat.audioCue {
            switch cue {
            case "radio":
                sc.coordinator.audio.playRadioFragment(beat.id)
                if sc.coordinator.settings.subtitlesEnabled, let cap = beat.caption {
                    sc.hud?.showSubtitle(cap, duration: max(3, beat.duration))
                }
            case "tone":
                sc.coordinator.audio.playReceiverTrigger(.deep)
            case "silence":
                sc.coordinator.audio.setMusicState("silence")
            default:
                break
            }
        }

        // Kamera.
        if beat.cameraMode == "focus", beat.x != nil, beat.y != nil {
            sc.cameraController.focusOverride = CGPoint(x: beat.x!, y: beat.y!)
        } else if beat.cameraMode == "wide" {
            sc.cameraController.shake(duration: 0.3, magnitude: 3)
        }

        // Oyuncu kilidi — spec 261.
        if beat.playerLocked && beat.duration > 0.3 {
            isCinematicLock = true
            activeLockTimer = beat.duration
            sc.cinematicLockBegan()
        }
    }

    var firedIDs: [String] { return Array(fired) }
}
