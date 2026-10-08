import AVFoundation

/// Ses bus yapısı — spec 86.
enum AudioBus: String, CaseIterable {
    case master
    case music
    case ambience
    case environment
    case player
    case resonance
    case threat
    case ui
}
