import Foundation

/// Spec 372 (Default Settings), 340-344 (erişilebilirlik).
/// UserDefaults ile saklanan oyuncu tercihleri.
struct GameSettings {

    var masterVolume: Float = 0.9
    var musicVolume: Float = 0.7
    var sfxVolume: Float = 0.9
    var hapticsEnabled = true
    var subtitlesEnabled = true
    var reduceMotion = false
    var highContrast = false

    private static let key = "KIR.settings.v1"

    static func load() -> GameSettings {
        let d = UserDefaults.standard
        var s = GameSettings()
        s.masterVolume = d.object(forKey: key + ".master") as? Float ?? s.masterVolume
        s.musicVolume = d.object(forKey: key + ".music") as? Float ?? s.musicVolume
        s.sfxVolume = d.object(forKey: key + ".sfx") as? Float ?? s.sfxVolume
        s.hapticsEnabled = d.object(forKey: key + ".haptics") as? Bool ?? s.hapticsEnabled
        s.subtitlesEnabled = d.object(forKey: key + ".subs") as? Bool ?? s.subtitlesEnabled
        s.reduceMotion = d.object(forKey: key + ".motion") as? Bool ?? s.reduceMotion
        s.highContrast = d.object(forKey: key + ".contrast") as? Bool ?? s.highContrast
        return s
    }

    func save() {
        let d = UserDefaults.standard
        d.set(masterVolume, forKey: key + ".master")
        d.set(musicVolume, forKey: key + ".music")
        d.set(sfxVolume, forKey: key + ".sfx")
        d.set(hapticsEnabled, forKey: key + ".haptics")
        d.set(subtitlesEnabled, forKey: key + ".subs")
        d.set(reduceMotion, forKey: key + ".motion")
        d.set(highContrast, forKey: key + ".contrast")
    }
}
