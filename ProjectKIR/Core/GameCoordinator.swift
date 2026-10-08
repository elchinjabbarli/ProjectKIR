import Foundation
import SpriteKit

/// Spec 527 (Dependency Container), 528 (Singleton yok, bağımlılık enjeksiyonu).
/// Tüm servisleri elinde tutan üst koordinatör; sahneler zayıf değil güçlü referans alır
/// ama koordinatör hiçbir sahneyi tutmaz (retain cycle yok).
final class GameCoordinator {

    // MARK: - Servisler
    let saveSystem = SaveSystem()
    var settings: GameSettings
    let audio = AudioDirector()
    let haptics = HapticDirector()
    let time = TimeService()
    private var noise = Noise(seed: 7717)

    // MARK: - Durum
    private(set) var state: GameState = .idle
    private(set) var currentLevelIndex: Int = 0
    private var lastWallTime: Date = Date()

    /// Bölüm sırası — spec 629 (MVP Content Summary).
    static let levelOrder: [String] = [
        "L01_Arrival", "L02_Intake", "L03_BellowHall", "L04_OrchardEdge",
        "L05_CounterweightHouse", "L06_PressureGallery", "L07_FloodChamber",
        "L08_SiltTunnels", "L09_MirrorBasin", "L10_QuietEngine"
    ]

    var random: Double { noise.uniform() }

    init() {
        settings = GameSettings.load()
    }

    func bootstrap() {
        audio.start(settings: settings)
        haptics.start(enabled: settings.hapticsEnabled)
        KIRLog.info("Coordinator bootstrap. v\(AppConfiguration.appVersion)")
    }

    // MARK: - Akış
    func launchFromMainMenu() {
        setState(.mainMenu)
        let menu = MainMenuScene(size: SceneRouter.view?.bounds.size ?? CGSize(width: 1334, height: 750))
        menu.coordinator = self
        SceneRouter.presentImmediately(menu)
    }

    func startNewGame() {
        saveSystem.beginNewGame()
        currentLevelIndex = 0
        settings.save()
        presentLevel(index: 0, checkpointID: nil)
    }

    func continueGame() {
        let levelID = saveSystem.data.currentLevelID
        let idx = GameCoordinator.levelOrder.firstIndex(of: levelID) ?? 0
        currentLevelIndex = idx
        presentLevel(index: idx, checkpointID: saveSystem.data.currentCheckpointID)
    }

    func presentLevel(index: Int, checkpointID: String?) {
        guard index >= 0 && index < GameCoordinator.levelOrder.count else { return }
        currentLevelIndex = index
        setState(.loading)
        let levelID = GameCoordinator.levelOrder[index]
        let scene = GameScene(levelID: levelID, checkpointID: checkpointID, coordinator: self)
        let size = SceneRouter.view?.bounds.size ?? CGSize(width: 1334, height: 750)
        scene.size = size
        SceneRouter.present(scene, withFadeDuration: 0.6)
    }

    /// Spec 423 (Level Complete) — sonraki seviyeye geç.
    func levelCompleted(currentLevelID: String) {
        saveSystem.recordLevelComplete(currentLevelID)
        let next = currentLevelIndex + 1
        if next >= GameCoordinator.levelOrder.count {
            playEnding()
        } else {
            setState(.chapterTransition)
            let size = SceneRouter.view?.bounds.size ?? CGSize(width: 1334, height: 750)
            let card = ChapterCardScene(nextLevelID: GameCoordinator.levelOrder[next], coordinator: self)
            card.size = size
            SceneRouter.present(card, withFadeDuration: 0.8)
        }
    }

    func advanceFromChapterCard() {
        presentLevel(index: currentLevelIndex + 1, checkpointID: nil)
    }

    // MARK: - Final — spec 65, 595, 596
    func playEnding() {
        setState(.ending)
        let size = SceneRouter.view?.bounds.size ?? CGSize(width: 1334, height: 750)
        let end = EndingScene(size: size)
        end.coordinator = self
        SceneRouter.present(end, withFadeDuration: 1.2)
    }

    func finishCredits() {
        saveSystem.markCompletion()
        launchFromMainMenu()
    }

    func returnToMainMenu() {
        time.reset()
        launchFromMainMenu()
    }

    // MARK: - Sahne içi durum geçişleri
    func setState(_ s: GameState) {
        guard s != state else { return }
        if GameState.isValidTransition(from: state, to: s) || state == .idle {
            state = s
        } else {
            // Geçersiz sıçramaları logla ama bloke etme (spec 466 pragmatik yaklaşım).
            KIRLog.warn("Şüpheli durum geçişi: \(state) -> \(s)")
            state = s
        }
    }

    // MARK: - Kesinti — spec 308/309/310
    func handleAppDidEnterBackground() {
        if state == .playing {
            saveSystem.save()
        }
        audio.suspend()
    }

    func handleAppWillEnterForeground() {
        audio.resume()
    }

    // MARK: - Ayar değişimi
    func applySettings(_ s: GameSettings) {
        settings = s
        settings.save()
        audio.applyVolumes(settings: s)
        haptics.setEnabled(s.hapticsEnabled)
        // Spec 30 — ayar değişimi de save tetikler.
        saveSystem.save()
    }
}
