import Foundation
import CoreGraphics

/// Spec 330/331 — GameplayBalance.json yükleyicisi.
/// Tuning değerleri kodda varsayılanlarla durur; bundle'daki config bulunursa
/// açılışta bir kez üzerine yazar. Böylece denge iterasyonu derleme gerektirmez
/// ve config bozuksa oyun varsayılanlarla açılır (spec 534 fallback prensibi).
enum BalanceConfig {

    private struct Root: Codable {
        let player: Player?
        let resonance: Resonance?
        let drone: Drone?
        let world: World?
    }
    private struct Player: Codable {
        let moveSpeed: CGFloat?
        let crouchSpeed: CGFloat?
        let jumpVelocity: CGFloat?
        let gravity: CGFloat?
        let maxFallSpeed: CGFloat?
        let coyoteTime: Double?
        let jumpBuffer: Double?
        let airControl: CGFloat?
    }
    private struct Resonance: Codable {
        let chargeDuration: Double?
        let pulseRange: CGFloat?
        let pulseTravelSpeed: CGFloat?
    }
    private struct Drone: Codable {
        let sightRange: CGFloat?
        let sightHalfAngle: CGFloat?
        let crouchSightFactor: CGFloat?
    }
    private struct World: Codable {
        let interactRange: CGFloat?
        let fallDeathDistanceBeyondBounds: CGFloat?
    }

    /// Bir kez çağrılır (AppConfiguration.configure). Hata durumunda sessizce varsayılanda kalır.
    static func load() {
        guard let url = Bundle.main.url(forResource: "GameplayBalance",
                                         withExtension: "json") else {
            KIRLog.warn("GameplayBalance.json bulunamadı — varsayılan denge kullanılıyor.")
            return
        }
        do {
            let raw = try Data(contentsOf: url)
            let cfg = try JSONDecoder().decode(Root.self, from: raw)
            apply(cfg)
            KIRLog.info("GameplayBalance.json yüklendi.")
        } catch {
            KIRLog.warn("GameplayBalance.json çözümlenemedi: \(error.localizedDescription)")
        }
    }

    private static func apply(_ cfg: Root) {
        if let p = cfg.player {
            if let v = p.moveSpeed { Tuning.moveSpeed = v }
            if let v = p.crouchSpeed { Tuning.crouchSpeed = v }
            if let v = p.jumpVelocity { Tuning.jumpVelocity = v }
            if let v = p.gravity { Tuning.gravity = v }
            if let v = p.maxFallSpeed { Tuning.maxFallSpeed = v }
            if let v = p.coyoteTime { Tuning.coyoteTime = v }
            if let v = p.jumpBuffer { Tuning.jumpBuffer = v }
            if let v = p.airControl { Tuning.airControl = v }
        }
        if let r = cfg.resonance {
            if let v = r.chargeDuration { Tuning.chargeDuration = v }
            if let v = r.pulseRange { Tuning.pulseRange = v }
            if let v = r.pulseTravelSpeed { Tuning.pulseTravelSpeed = v }
        }
        if let d = cfg.drone {
            if let v = d.sightRange { Tuning.droneSightRange = v }
            if let v = d.sightHalfAngle { Tuning.droneSightHalfAngle = v }
            if let v = d.crouchSightFactor { Tuning.droneCrouchSightFactor = v }
        }
        if let w = cfg.world {
            if let v = w.interactRange { Tuning.interactRange = v }
            if let v = w.fallDeathDistanceBeyondBounds { Tuning.fallDeathDistanceBeyondBounds = v }
        }
    }
}
