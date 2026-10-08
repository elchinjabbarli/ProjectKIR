import SpriteKit

/// Spec 68 (Renk Paleti), 199 (Object Color Coding), 200 (Resonance Object Shapes).
/// Placeholder görsel dil: az renk, yüksek kontrast, anlamlı ışık.
enum KIRPalette {

    // Dünya — kül grisi / kömür siyahı / kirli beyaz
    static let coal = SKColor(red: 0.08, green: 0.078, blue: 0.07, alpha: 1)        // kömür siyahı
    static let ash = SKColor(red: 0.29, green: 0.29, blue: 0.28, alpha: 1)          // kül grisi
    static let dirtyWhite = SKColor(red: 0.85, green: 0.835, blue: 0.78, alpha: 1)  // kirli beyaz
    static let rust = SKColor(red: 0.54, green: 0.35, blue: 0.23, alpha: 1)         // pas
    static let coldBlue = SKColor(red: 0.35, green: 0.44, blue: 0.53, alpha: 1)     // düşük doygunluklu soğuk mavi
    static let amber = SKColor(red: 0.91, green: 0.70, blue: 0.35, alpha: 1)         // sinyal ışığı

    // Frekans kodlama — spec 303: renk + biçim + ses üçlüsü.
    static let deepColor = coldBlue      // kalın tek çizgi
    static let bodyColor = amber         // çift çizgi
    static let edgeColor = dirtyWhite    // kesik ince çizgi

    static func color(for f: ResonanceFrequency) -> SKColor {
        switch f {
        case .deep: return deepColor
        case .body: return bodyColor
        case .edge: return edgeColor
        }
    }

    /// Bölüm görsel kimliği — spec 280.
    static func chapterBackground(_ chapter: Int) -> SKColor {
        switch chapter {
        case 1: return SKColor(red: 0.10, green: 0.105, blue: 0.115, alpha: 1)
        case 2: return SKColor(red: 0.09, green: 0.10, blue: 0.12, alpha: 1)
        case 3: return SKColor(red: 0.10, green: 0.095, blue: 0.09, alpha: 1)
        case 4: return SKColor(red: 0.075, green: 0.085, blue: 0.10, alpha: 1)
        case 5: return SKColor(red: 0.065, green: 0.07, blue: 0.085, alpha: 1)
        default: return SKColor(red: 0.08, green: 0.085, blue: 0.09, alpha: 1)
        }
    }
}

/// Fizik kategorileri — spec 450 (Collision Masks).
struct PhysicsCategory {
    static let none: UInt32 = 0
    static let world: UInt32 = 0b0000_0001      // zemin, duvar
    static let player: UInt32 = 0b0000_0010
    static let hazard: UInt32 = 0b0000_0100      // pressure wave gövdesi, silt
    static let drone: UInt32 = 0b0000_1000
    static let interactive: UInt32 = 0b0001_0000 // kapı, platform
    static let checkpoint: UInt32 = 0b0010_0000
    static let water: UInt32 = 0b0100_0000
    static let trigger: UInt32 = 0b1000_0000     // exit, story bölgesi
    static let debris: UInt32 = 0b1_0000_0000
}

/// Spec 375/376/377 — dünya tutarlılığı: kabul edilen fizik değerleri.
/// Varsayılanlar kodda; açılışta GameplayBalance.json üzerine yazar (spec 330/331).
struct Tuning {
    static let playerSize = CGSize(width: 34, height: 58)
    static let crouchHeight: CGFloat = 34
    static var moveSpeed: CGFloat = 260
    static var crouchSpeed: CGFloat = 120
    static var jumpVelocity: CGFloat = 760
    static var gravity: CGFloat = -2100
    static var maxFallSpeed: CGFloat = -1200
    static var coyoteTime: TimeInterval = 0.12
    static var jumpBuffer: TimeInterval = 0.14
    static var airControl: CGFloat = 0.75
    static var chargeDuration: TimeInterval = 0.65
    static var pulseRange: CGFloat = 520
    static var pulseTravelSpeed: CGFloat = 700
    static var interactRange: CGFloat = 110
    static var droneSightRange: CGFloat = 560
    static var droneSightHalfAngle: CGFloat = 0.55
    static var droneCrouchSightFactor: CGFloat = 0.6   // çömelen hedef görünür menzil çarpanı
    static var fallDeathDistanceBeyondBounds: CGFloat = 140
}

/// UI metinleri — spec 170/171 (localization tek noktadan).
enum KIRStrings {
    static let gameTitle = "PROJECT KIR"
    static let newGame = "Yeni Oyun"
    static let continueGame = "Devam Et"
    static let settings = "Ayarlar"
    static let back = "Geri"
    static let resume = "Sürdür"
    static let mainMenu = "Ana Menü"
    static let restartCheckpoint = "Baştan Başla"
    static let quitConfirm = "Ana menüye dönülüyor. Kayıt seni bekliyor olacak."
    static let masterVolume = "Ana Ses"
    static let musicVolume = "Müzik"
    static let sfxVolume = "Efektler"
    static let hapticsOn = "Titreşim"
    static let subtitlesOn = "Altyazılar"
    static let reduceMotion = "Hareketi Azalt"
    static let credits = "Jenerik"
    static let pauseTitle = "DURAKLATILDI"
    static let checkpointSaved = "Kalibrasyon noktası kaydedildi"
    static let chapterPrefix = "BÖLÜM"
    static let tapToBegin = "Başlamak için dokun"
    static let deathHint = "…"
    static let completed = "TAMAMLANDI"
    static let finalThanks = "duydun mu?"
}
