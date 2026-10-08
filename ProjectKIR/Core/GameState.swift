import Foundation

/// Spec 465 — üst seviye oyun durum makinesi.
/// Tüm sahneler bu duraklıklara göre davranır.
enum GameState: String, Equatable {
    case idle
    case mainMenu
    case loading
    case playing
    case paused
    case dead
    case cinematic
    case chapterTransition
    case levelComplete
    case ending
    case credits

    /// Spec 466 — geçiş geçerli mi?
    static func isValidTransition(from: GameState, to: GameState) -> Bool {
        switch (from, to) {
        case (_, .mainMenu): return true
        case (.mainMenu, .loading), (.loading, .playing): return true
        case (.playing, .paused), (.paused, .playing): return true
        case (.playing, .dead), (.dead, .playing), (.dead, .loading): return true
        case (.playing, .cinematic), (.cinematic, .playing): return true
        case (.playing, .chapterTransition), (.chapterTransition, .loading): return true
        case (.playing, .levelComplete), (.levelComplete, .loading): return true
        case (.levelComplete, .chapterTransition), (.levelComplete, .ending): return true
        case (.playing, .ending), (.ending, .credits): return true
        case (.cinematic, .ending): return true
        default: return false
        }
    }
}
