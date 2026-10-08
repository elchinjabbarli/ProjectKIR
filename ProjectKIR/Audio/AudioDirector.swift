import AVFoundation
import Foundation

/// Ses yönetmeni — spec 86/97/103-107/313-315.
/// AVAudioEngine + bus mimarisi + tamamen prosedürel içerik.
/// Sesler oyun mantığına göre dinamik karıştırılır (ducking — spec 314).
final class AudioDirector {

    private let engine = AVAudioEngine()
    private var mixers: [AudioBus: AVAudioMixerNode] = [:]
    private let reverb = AVAudioUnitReverb()

    // One-shot oynatıcı havuzları (bus başına 3 — polifoni).
    private var playerPools: [AudioBus: [AVAudioPlayerNode]] = [:]
    private var poolIndex: [AudioBus: Int] = [:]
    private var loopPlayer = AVAudioPlayerNode()
    private var loopPlayer2 = AVAudioPlayerNode()
    private var loopPlayer3 = AVAudioPlayerNode()
    private var musicPlayer = AVAudioPlayerNode()

    // Hazır tamponlar — init'te üretilir.
    private var buffers: [String: AVAudioPCMBuffer] = [:]
    private var musicState: String = "calm"
    private var started = false

    // Ses seviyeleri — ducking için referans.
    private var currentSettings = GameSettings()

    // MARK: - Başlatma
    func start(settings: GameSettings) {
        currentSettings = settings
        guard !started else { return }
        started = true

        for bus in AudioBus.allCases {
            let m = AVAudioMixerNode()
            engine.attach(m)
            mixers[bus] = m
        }
        engine.attach(loopPlayer)
        engine.attach(loopPlayer2)
        engine.attach(loopPlayer3)
        engine.attach(musicPlayer)

        reverb.wetDryMix = 28
        engine.attach(reverb)

        // Bus ağacı: her bus → master → output; atmosfer bus'ları → reverb → master. Spec 86.
        guard let master = mixers[.master] else { return }
        for bus in AudioBus.allCases where bus != .master {
            if let m = mixers[bus] {
                engine.connect(m, to: master, format: nil)
            }
        }
        engine.connect(reverb, to: master, format: nil)
        for bus in [AudioBus.ambience, .environment, .resonance] {
            if let m = mixers[bus] {
                engine.connect(m, to: reverb, format: nil)
            }
        }
        engine.connect(master, to: engine.mainMixerNode, format: nil)

        // Her bus için 3'lü one-shot havuzu.
        for bus in AudioBus.allCases {
            var pool: [AVAudioPlayerNode] = []
            for _ in 0..<3 {
                let p = AVAudioPlayerNode()
                engine.attach(p)
                if let m = mixers[bus] {
                    engine.connect(p, to: m, format: nil)
                }
                pool.append(p)
            }
            playerPools[bus] = pool
            poolIndex[bus] = 0
        }
        engine.connect(loopPlayer, to: mixers[.environment] ?? engine.mainMixerNode, format: nil)
        engine.connect(loopPlayer2, to: mixers[.ambience] ?? engine.mainMixerNode, format: nil)
        engine.connect(loopPlayer3, to: mixers[.threat] ?? engine.mainMixerNode, format: nil)
        engine.connect(musicPlayer, to: mixers[.music] ?? engine.mainMixerNode, format: nil)

        generateAllBuffers()
        applyVolumes(settings: settings)
        startEngine()

        // Kesinti bildirimleri — spec 310.
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification, object: nil)
    }

    private func startEngine() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            // Havuzdaki tüm oynatıcıları çalıştır.
            for pool in playerPools.values {
                for p in pool { p.play() }
            }
        } catch {
            // Spec 534: fallback — sessiz mod, oyun çökmez.
            KIRLog.warn("Audio engine başlatılamadı: \(error.localizedDescription)")
        }
    }

    // MARK: - Kesinti
    @objc private func handleInterruption(_ note: Notification) {
        guard let info = note.userInfo,
              let typeRaw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeRaw) else { return }
        if type == .began { pause() } else { resume() }
    }

    func suspend() { pause() }

    func pause() {
        loopPlayer.pause()
        loopPlayer2.pause()
        loopPlayer3.pause()
        musicPlayer.pause()
        engine.pause()
    }

    func resume() {
        guard started else { return }
        if !engine.isRunning {
            startEngine()
        }
        if ambienceBuffer != nil && !loopPlayer2.isPlaying { loopPlayer2.play() }
        if !loopPlayer.isPlaying { loopPlayer.play() }
        if droneLoopBuffer != nil && !loopPlayer3.isPlaying { loopPlayer3.play() }
        if musicWanted && !musicPlayer.isPlaying { musicPlayer.play() }
    }

    // MARK: - Seviyeler
    func applyVolumes(settings: GameSettings) {
        currentSettings = settings
        setBus(.music, volume: settings.musicVolume * settings.masterVolume)
        setBus(.ambience, volume: 0.7 * settings.sfxVolume * settings.masterVolume)
        setBus(.environment, volume: 0.8 * settings.sfxVolume * settings.masterVolume)
        setBus(.player, volume: settings.sfxVolume * settings.masterVolume)
        setBus(.resonance, volume: settings.sfxVolume * settings.masterVolume)
        setBus(.threat, volume: settings.sfxVolume * settings.masterVolume)
        setBus(.ui, volume: settings.sfxVolume * settings.masterVolume)
    }

    private func setBus(_ bus: AudioBus, volume: Float) {
        mixers[bus]?.outputVolume = volume
    }

    /// Spec 314: dinamik ducking — tehdit sesi gelince müzik çekilir.
    func duckMusic(_ amount: Float, for seconds: Double) {
        guard let m = mixers[.music] else { return }
        let target = currentSettings.musicVolume * currentSettings.masterVolume * (1 - amount)
        m.setOutputVolume(target, rampTime: 0.3)
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            guard let self = self, let mm = self.mixers[.music] else { return }
            let v = self.currentSettings.musicVolume * self.currentSettings.masterVolume
            mm.setOutputVolume(v, rampTime: 0.8)
        }
    }

    // MARK: - Tampon üretimi (spec 87: build-time yerine init'te bir kez)
    private func generateAllBuffers() {
        func put(_ key: String, _ buf: AVAudioPCMBuffer) { buffers[key] = buf }

        // Oyuncu — spec 94/95/96.
        put("footstep", ProceduralSFX.noiseBurst(duration: 0.09, gain: 0.22, lowpass: 1400, hp: 90))
        put("footstep2", ProceduralSFX.noiseBurst(duration: 0.11, gain: 0.19, lowpass: 1000, hp: 70))
        put("jump", ProceduralSFX.noiseBurst(duration: 0.22, gain: 0.16, lowpass: 900, attack: 0.25, release: 0.6))
        put("land", ProceduralSFX.metalImpact(baseFreq: 64, duration: 0.22, gain: 0.3))
        put("breath", ProceduralSFX.noiseBurst(duration: 0.8, gain: 0.05, lowpass: 600, attack: 0.45, release: 0.5))

        // Rezonans — spec 88-90: frekans başına sweep.
        put("res_deep", ProceduralSFX.pitchSweep(start: 70, peak: 110, duration: 1.4, gain: 0.5))
        put("res_body", ProceduralSFX.pitchSweep(start: 340, peak: 520, duration: 1.1, gain: 0.42, waveform: "triangle"))
        put("res_edge", ProceduralSFX.pitchSweep(start: 1450, peak: 2100, duration: 0.9, gain: 0.3))
        put("wrong", ProceduralSFX.metalImpact(baseFreq: 82, duration: 0.25, gain: 0.3))
        put("freqswitch", ProceduralSFX.sine(660, duration: 0.07, gain: 0.2, release: 0.6))
        put("chargestart_deep", ProceduralSFX.sine(46, duration: 0.7, gain: 0.10, attack: 0.6, release: 0.35))
        put("chargestart_body", ProceduralSFX.sine(220, duration: 0.7, gain: 0.08, attack: 0.6, release: 0.35))
        put("chargestart_edge", ProceduralSFX.sine(880, duration: 0.7, gain: 0.06, attack: 0.6, release: 0.35))
        put("chargefull", ProceduralSFX.sine(1320, duration: 0.1, gain: 0.16, release: 0.5))

        // Dünya — spec 91-93.
        put("dooropen", ProceduralSFX.metalImpact(baseFreq: 48, duration: 1.3, gain: 0.45))
        put("doorclose", ProceduralSFX.metalImpact(baseFreq: 56, duration: 0.4, gain: 0.4))
        put("valve", ProceduralSFX.metalImpact(baseFreq: 150, duration: 0.8, gain: 0.4))
        put("mirror", ProceduralSFX.metalImpact(baseFreq: 320, duration: 0.35, gain: 0.3))
        put("machine", ProceduralSFX.machineHum(baseFreq: 42, duration: 2.2, gain: 0.4))
        put("settle", ProceduralSFX.metalImpact(baseFreq: 90, duration: 0.3, gain: 0.28))
        put("waterchange", ProceduralSFX.waterLoop(duration: 1.8, gain: 0.3))
        put("bridge_on", ProceduralSFX.pitchSweep(start: 900, peak: 1900, duration: 0.6, gain: 0.25))
        put("bridge_off", ProceduralSFX.pitchSweep(start: 1900, peak: 700, duration: 0.5, gain: 0.18))
        put("receiver", ProceduralSFX.sine(528, duration: 0.4, gain: 0.3, release: 0.7))
        put("seqtick", ProceduralSFX.sine(520, duration: 0.09, gain: 0.22, release: 0.5))

        // Checkpoint — spec 420: iki notalı, düşük, kısa.
        put("checkpoint", ProceduralSFX.sine(196, duration: 0.9, gain: 0.30, attack: 0.02, release: 0.6))
        put("checkpoint2", ProceduralSFX.sine(294, duration: 1.1, gain: 0.26, attack: 0.02, release: 0.7))

        // Tehdit — spec 396/397.
        put("pwarn", ProceduralSFX.machineHum(baseFreq: 30, duration: 1.4, gain: 0.5))
        put("pwave", ProceduralSFX.pitchSweep(start: 28, peak: 55, duration: 1.6, gain: 0.65))
        put("dronesus", ProceduralSFX.sine(880, duration: 0.25, gain: 0.2, release: 0.5))
        put("dronealert", ProceduralSFX.noiseBurst(duration: 0.6, gain: 0.4, lowpass: 3400, attack: 0.05))
        put("dronecalm", ProceduralSFX.sine(440, duration: 0.5, gain: 0.12, release: 0.7))
        put("debris", ProceduralSFX.metalImpact(baseFreq: 210, duration: 0.4, gain: 0.3))
        put("silt", ProceduralSFX.noiseBurst(duration: 1.6, gain: 0.3, lowpass: 500, attack: 0.15, release: 0.5))
        put("electric", ProceduralSFX.noiseBurst(duration: 0.5, gain: 0.28, lowpass: 6000, hp: 1800, attack: 0.02, release: 0.7))

        // UI.
        put("uiclick", ProceduralSFX.sine(990, duration: 0.05, gain: 0.14, release: 0.4))
        put("uiback", ProceduralSFX.sine(520, duration: 0.07, gain: 0.14, release: 0.4))

        // Müzik pedleri — spec 98-100.
        put("pad_low", ProceduralSFX.triangle(92, duration: 8.0, gain: 0.16))
        put("pad_fifth", ProceduralSFX.triangle(138, duration: 8.0, gain: 0.13))
        put("pad_minor", ProceduralSFX.triangle(110, duration: 8.0, gain: 0.10))
        put("pad_high", ProceduralSFX.sine(440, duration: 9.0, gain: 0.05, attack: 0.3, release: 0.5))
        put("finalchord", ProceduralSFX.finalChord(duration: 9.0, gain: 0.5))
        put("radioblip", ProceduralSFX.radioFragment(text: "fragment", duration: 1.8, gain: 0.32))

        // Döngüler.
        ambienceBuffer = ProceduralSFX.ambienceBed(duration: 6.0, gain: 0.16)
        machineLoopBuffer = ProceduralSFX.machineHum(baseFreq: 40, duration: 4.0, gain: 0.14)
        waterLoopBuffer = ProceduralSFX.waterLoop(duration: 4.5, gain: 0.14)
        droneLoopBuffer = ProceduralSFX.droneHumLoop(duration: 3.0, gain: 0.15)
    }

    private var ambienceBuffer: AVAudioPCMBuffer?
    private var machineLoopBuffer: AVAudioPCMBuffer?
    private var waterLoopBuffer: AVAudioPCMBuffer?
    private var droneLoopBuffer: AVAudioPCMBuffer?
    private var musicWanted = false

    // MARK: - Oynatma
    private func play(_ key: String, on bus: AudioBus, rate: Float = 1.0, volume: Float = 1.0) {
        guard started, let buf = buffers[key], let pool = playerPools[bus] else { return }
        // Havuzda sıradaki oynatıcıyı kullan — üst üste binen sesler kesilmez.
        let idx = (poolIndex[bus] ?? 0) % pool.count
        poolIndex[bus] = idx + 1
        let p = pool[idx]
        p.volume = volume
        p.rate = rate
        p.scheduleBuffer(buf, at: nil, options: .interrupts)
        if !p.isPlaying { p.play() }
    }

    // Oyuncu
    func playFootstep(running: Bool) {
        play(running && Int.random(in: 0...1) == 0 ? "footstep2" : "footstep",
             on: .player, rate: Float.random(in: 0.92...1.1), volume: 0.8)
    }
    func playJump() { play("jump", on: .player) }
    func playLand(strength: Float) {
        play("land", on: .player, rate: 1.0, volume: min(1, strength))
    }
    func playBreath() { play("breath", on: .player, volume: 0.7) }

    // Rezonans
    func playPulse(_ pulse: ResonancePulse) {
        let key = "res_\(pulse.frequency.rawValue)"
        play(key, on: .resonance, rate: 1.0, volume: Float(0.5 + pulse.strength * 0.5))
    }
    func playChargeStart(_ f: ResonanceFrequency) {
        play("chargestart_\(f.rawValue)", on: .resonance, volume: 0.7)
    }
    func playChargeFull(_ f: ResonanceFrequency) {
        play("chargefull", on: .resonance)
    }
    func playWrongFrequency() { play("wrong", on: .resonance, volume: 0.7) }
    func playFrequencySwitch(_ f: ResonanceFrequency) {
        play("freqswitch", on: .ui, rate: Float(f.fundamentalHz / 440.0))
    }

    // Dünya
    func playDoorOpen(_ f: ResonanceFrequency) { duckMusic(0.2, for: 1.5); play("dooropen", on: .environment) }
    func playDoorClose() { play("doorclose", on: .environment) }
    func playValve() { play("valve", on: .environment) }
    func playMirrorRotate() { play("mirror", on: .environment, rate: Float.random(in: 0.95...1.1)) }
    func playMachineStart() { play("machine", on: .environment) }
    func playPlatformSettle() { play("settle", on: .environment, volume: 0.7) }
    func playWaterChange() { play("waterchange", on: .environment) }
    func playBridgeMaterialize() { play("bridge_on", on: .resonance) }
    func playBridgeFade() { play("bridge_off", on: .resonance, volume: 0.6) }
    func playReceiverTrigger(_ f: ResonanceFrequency) {
        play("receiver", on: .environment, rate: Float(f.fundamentalHz / 440.0))
    }
    func playSequenceTick(_ f: ResonanceFrequency, index: Int) {
        play("seqtick", on: .environment, rate: 1.0 + Float(index) * 0.18)
    }

    // Checkpoint
    func playCheckpoint() {
        play("checkpoint", on: .ui)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { [weak self] in
            self?.play("checkpoint2", on: .ui)
        }
    }

    // Tehdit
    func playPressureWarning() { play("pwarn", on: .threat) }
    func playPressureWave() { duckMusic(0.6, for: 2.2); play("pwave", on: .threat) }
    func playDroneSuspicion() { play("dronesus", on: .threat, volume: 0.7) }
    func playDroneAlert() { duckMusic(0.75, for: 3.5); play("dronealert", on: .threat) }
    func playDroneCalm() { play("dronecalm", on: .threat, volume: 0.5) }
    func playDebrisFall() { play("debris", on: .environment, rate: Float.random(in: 0.8...1.2), volume: 0.6) }
    func playSiltBurst() { play("silt", on: .environment, volume: 0.7) }
    func playElectricLeak() { play("electric", on: .threat, volume: 0.7) }

    // UI
    func playUIClick() { play("uiclick", on: .ui) }
    func playUIBack() { play("uiback", on: .ui) }
    func playRadioFragment(_ seed: String) {
        duckMusic(0.35, for: 2.5)
        play("radioblip", on: .environment, rate: Float.random(in: 0.9...1.05))
    }

    // MARK: - Döngüler
    func startAmbience(kind: String) {
        guard started else { return }
        switch kind {
        case "silt":
            startLoop(loopPlayer2, buffer: ambienceBuffer)
            startLoop(loopPlayer, buffer: waterLoopBuffer)
        case "flood":
            startLoop(loopPlayer2, buffer: ambienceBuffer)
            startLoop(loopPlayer, buffer: waterLoopBuffer)
        case "gallery":
            startLoop(loopPlayer2, buffer: ambienceBuffer)
            startLoop(loopPlayer, buffer: machineLoopBuffer)
        case "engine":
            startLoop(loopPlayer2, buffer: ambienceBuffer)
            startLoop(loopPlayer, buffer: machineLoopBuffer)
        default:
            startLoop(loopPlayer2, buffer: ambienceBuffer)
        }
    }

    private func startLoop(_ p: AVAudioPlayerNode, buffer: AVAudioPCMBuffer?) {
        guard let buf = buffer else { return }
        p.stop()
        p.scheduleBuffer(buf, at: nil, options: .loops)
        if !p.isPlaying { p.play() }
    }

    func stopAmbience() {
        loopPlayer.stop()
    }

    func setDroneLoop(active: Bool) {
        guard started else { return }
        if active {
            startLoop(loopPlayer3, buffer: droneLoopBuffer)
        } else {
            loopPlayer3.stop()
        }
    }

    // MARK: - Müzik — spec 98/99/339/416: seyrek, jeneratif motif.
    func setMusicState(_ state: String) {
        musicState = state
        switch state {
        case "silence":
            stopMusicLoop()
        default:
            musicWanted = true
            playMusicLoop()
        }
    }

    private func playMusicLoop() {
        guard started, musicWanted else { return }
        startLoop(musicPlayer, buffer: buffers[musicPadKey()])
    }

    private func stopMusicLoop() {
        musicWanted = false
        musicPlayer.stop()
    }

    private func musicPadKey() -> String {
        switch musicState {
        case "tense": return "pad_minor"
        case "sparse": return "pad_high"
        case "final": return "finalchord"
        default: return "pad_low"
        }
    }

    /// Uzun soluk motif değişimi — müzik nefes alır.
    func tickMotif() {
        guard musicWanted else { return }
        let key = ["pad_low", "pad_fifth", "pad_high", "pad_fifth"][Int.random(in: 0...3)]
        play(key, on: .music, volume: 0.7)
    }

    /// Final sekansı — spec 315/602.
    func playEndingAudio() {
        stopMusicLoop()
        play("finalchord", on: .music, volume: 1.0)
    }

    func playChapterTransition() {
        play("checkpoint", on: .ui)
    }
}
