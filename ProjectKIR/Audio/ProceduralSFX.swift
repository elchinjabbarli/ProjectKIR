import AVFoundation

/// Prosedürel ses sentezi — spec 87-96.
/// Tüm SFX runtime'da AVAudioPCMBuffer olarak üretilir; asset dosyası yok.
/// 44.1 kHz mono float32.
enum ProceduralSFX {

    static let sampleRate: Double = 44100

    // MARK: - Temel yardımcılar
    private static func makeBuffer(_ duration: Double) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let frames = AVAudioFrameCount(sampleRate * duration)
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buf.frameLength = frames
        return buf
    }

    /// Basit one-pole alçak geçiren filtre.
    private static func lowPass(_ input: [Float], cutoff: Double) -> [Float] {
        let dt = 1.0 / sampleRate
        let rc = 1.0 / (2.0 * .pi * cutoff)
        let alpha = dt / (rc + dt)
        var out = [Float](repeating: 0, count: input.count)
        var y: Float = 0
        for i in 0..<input.count {
            y += alpha * (input[i] - y)
            out[i] = y
        }
        return out
    }

    /// Basit one-pole yüksek geçiren filtre.
    private static func highPass(_ input: [Float], cutoff: Double) -> [Float] {
        let dt = 1.0 / sampleRate
        let rc = 1.0 / (2.0 * .pi * cutoff)
        let alpha = rc / (rc + dt)
        var out = [Float](repeating: 0, count: input.count)
        var prevIn = input.first ?? 0
        var y: Float = 0
        for i in 0..<input.count {
            let x = input[i]
            y = alpha * (y + x - prevIn)
            prevIn = x
            out[i] = y
        }
        return out
    }

    /// ADSR benzeri zarf: attack / decay / sustain / release.
    static func envelope(n: Int, attack: Double, decay: Double, sustain: Double, release: Double) -> [Float] {
        var e = [Float](repeating: 0, count: n)
        let aEnd = Int(Double(n) * attack)
        let dEnd = Int(Double(n) * (attack + decay))
        let rStart = Int(Double(n) * (1 - release))
        for i in 0..<n {
            let t = Double(i) / Double(n)
            var v: Double = sustain
            if i < aEnd {
                v = t / max(0.0001, attack) * sustain
            } else if i < dEnd {
                let p = (t - attack) / max(0.0001, decay)
                v = sustain + (1 - sustain) * (1 - p)
            } else if i >= rStart {
                let p = (t - (1 - release)) / max(0.0001, release)
                v = sustain * (1 - p)
            }
            e[i] = Float(max(0, min(1, v)))
        }
        return e
    }

    // MARK: - Oszilatörler
    static func sine(_ freq: Double, duration: Double, gain: Float = 0.6,
                     attack: Double = 0.01, release: Double = 0.4) -> AVAudioPCMBuffer {
        let buf = makeBuffer(duration)
        let n = Int(buf.frameLength)
        let env = envelope(n: n, attack: attack, decay: 0.05, sustain: 0.7, release: release)
        let ptr = buf.floatChannelData![0]
        var phase: Double = 0
        for i in 0..<n {
            phase += 2 * .pi * freq / sampleRate
            ptr[i] = Float(sin(phase)) * env[i] * gain
        }
        return buf
    }

    static func triangle(_ freq: Double, duration: Double, gain: Float = 0.5) -> AVAudioPCMBuffer {
        let buf = makeBuffer(duration)
        let n = Int(buf.frameLength)
        let env = envelope(n: n, attack: 0.02, decay: 0.1, sustain: 0.6, release: 0.3)
        let ptr = buf.floatChannelData![0]
        let period = sampleRate / freq
        for i in 0..<n {
            let p = fmod(Double(i), period) / period
            let tri = 4 * abs(p - 0.5) - 1
            ptr[i] = Float(tri) * env[i] * gain
        }
        return buf
    }

    /// Spec 88-89: pitch sweep + exponential decay (rezonans pulsu çekirdeği).
    static func pitchSweep(start: Double, peak: Double, duration: Double, gain: Float = 0.55,
                           waveform: String = "sine") -> AVAudioPCMBuffer {
        let buf = makeBuffer(duration)
        let n = Int(buf.frameLength)
        let ptr = buf.floatChannelData![0]
        var phase: Double = 0
        for i in 0..<n {
            let t = Double(i) / Double(n)
            // Yükseliş (0–0.2) sonra sönüm.
            let f: Double
            if t < 0.18 {
                f = start + (peak - start) * (t / 0.18)
            } else {
                let d = (t - 0.18) / 0.82
                f = peak * exp(-d * 2.2)
                f = max(f, start * 0.8)
            }
            phase += 2 * .pi * f / sampleRate
            let env = Float(exp(-t * 4.2)) * gain
            var s = sin(phase)
            if waveform == "triangle" {
                let p = fmod(phase, 2 * .pi) / (2 * .pi)
                s = 4 * abs(p - 0.5) - 1
            }
            // Spec 90: hafif noise bileşeni.
            let noise = Float.random(in: -0.08...0.08) * env
            ptr[i] = s * env + noise
        }
        return buf
    }

    /// Filtrelenmiş gürültü patlaması (ayak sesi, su sıçraması).
    static func noiseBurst(duration: Double, gain: Float = 0.4, lowpass: Double = 2200,
                            attack: Double = 0.02, release: Double = 0.5, hp: Double = 0) -> AVAudioPCMBuffer {
        let n = Int(sampleRate * duration)
        var raw = [Float](repeating: 0, count: n)
        for i in 0..<n {
            raw[i] = Float.random(in: -1...1)
        }
        var filtered = lowPass(raw, cutoff: lowpass)
        if hp > 0 {
            filtered = highPass(filtered, cutoff: hp)
        }
        let env = envelope(n: n, attack: attack, decay: 0.1, sustain: 0.5, release: release)
        let buf = makeBuffer(duration)
        let ptr = buf.floatChannelData![0]
        for i in 0..<n {
            ptr[i] = filtered[i] * env[i] * gain
        }
        return buf
    }

    /// Metal darbe — spec 91: birkaç çarpık partial + gürültü.
    static func metalImpact(baseFreq: Double, duration: Double = 0.5, gain: Float = 0.5) -> AVAudioPCMBuffer {
        let buf = makeBuffer(duration)
        let n = Int(buf.frameLength)
        let ptr = buf.floatChannelData![0]
        let partials: [Double] = [1.0, 1.83, 2.76, 4.07, 5.42]
        var phases = [Double](repeating: 0, count: partials.count)
        for i in 0..<n {
            let t = Double(i) / sampleRate
            var s: Double = 0
            for (k, m) in partials.enumerated() {
                let f = baseFreq * m * (1.0 + 0.004 * sin(t * 13 + Double(k)))
                phases[k] += 2 * .pi * f / sampleRate
                let damp = exp(-t * (2.0 + Double(k) * 2.5))
                s += sin(phases[k]) * damp / Double(k + 1)
            }
            s += Double.random(in: -0.05...0.05) * exp(-t * 18)
            ptr[i] = Float(s) * gain * 0.7
        }
        return buf
    }

    /// Makine uğultusu döngüsü — spec 92: düşük testere dişi + LFO.
    static func machineHum(baseFreq: Double = 46, duration: Double = 2.4, gain: Float = 0.22) -> AVAudioPCMBuffer {
        let buf = makeBuffer(duration)
        let n = Int(buf.frameLength)
        let ptr = buf.floatChannelData![0]
        let period = sampleRate / baseFreq
        var lfoPhase: Double = 0
        for i in 0..<n {
            let t = Double(i) / sampleRate
            // Testere dişi (yumuşatılmış).
            let p = fmod(Double(i), period) / period
            var saw = 2 * p - 1
            saw = tanh(saw * 1.6) * 0.7
            // Yavaş genlik LFO'su.
            lfoPhase += 2 * .pi * 0.9 / sampleRate
            let lfo = 0.75 + 0.25 * sin(lfoPhase)
            // Uzak vuruş hissi.
            let thump = 0.35 + 0.65 * pow(max(0, sin(2 * .pi * t / 1.2)), 6)
            ptr[i] = Float(saw * lfo * thump) * gain
        }
        return buf
    }

    /// Su döngüsü — spec 93: bant geçiren gürültü + dalga modülasyonu.
    static func waterLoop(duration: Double = 4.0, gain: Float = 0.16) -> AVAudioPCMBuffer {
        let n = Int(sampleRate * duration)
        var raw = [Float](repeating: 0, count: n)
        for i in 0..<n {
            raw[i] = Float.random(in: -1...1)
        }
        var lp = lowPass(raw, cutoff: 900)
        lp = highPass(lp, cutoff: 240)
        let buf = makeBuffer(duration)
        let ptr = buf.floatChannelData![0]
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let swell = 0.5 + 0.5 * sin(2 * .pi * 0.35 * t) * sin(2 * .pi * 0.13 * t + 1)
            ptr[i] = lp[i] * Float(swell) * gain
        }
        return buf
    }

    /// Drone vınlaması — spec 397: iki çarpık osilatör + hışırtı.
    static func droneHumLoop(duration: Double = 3.0, gain: Float = 0.2) -> AVAudioPCMBuffer {
        let buf = makeBuffer(duration)
        let n = Int(buf.frameLength)
        let ptr = buf.floatChannelData![0]
        var p1: Double = 0
        var p2: Double = 0
        for i in 0..<n {
            let f1 = 112.0
            let f2 = 116.5  // hafif vuru
            p1 += 2 * .pi * f1 / sampleRate
            p2 += 2 * .pi * f2 / sampleRate
            let s = sin(p1) * 0.5 + sin(p2) * 0.5
            let flutter = 0.9 + 0.1 * sin(2 * .pi * Double(i) / sampleRate * 6)
            let noise = Float.random(in: -0.05...0.05)
            ptr[i] = Float(s * flutter) * gain + noise * 0.1
        }
        return buf
    }

    /// Ambiyans yatağı — spec 107: kahverengi gürültü + çok düşük drone.
    static func ambienceBed(duration: Double = 6.0, gain: Float = 0.10, coldness: Double = 0.3) -> AVAudioPCMBuffer {
        let n = Int(sampleRate * duration)
        var brown = [Float](repeating: 0, count: n)
        var last: Double = 0
        for i in 0..<n {
            let w = Double.random(in: -1...1)
            last = (last + 0.02 * w) / 1.02
            brown[i] = Float(last * 3.5)
        }
        let buf = makeBuffer(duration)
        let ptr = buf.floatChannelData![0]
        var p: Double = 0
        let bedFreq = 38.0 + coldness * 14
        for i in 0..<n {
            p += 2 * .pi * bedFreq / sampleRate
            let slow = 0.7 + 0.3 * sin(2 * .pi * Double(i) / sampleRate * 0.07)
            ptr[i] = brown[i] * gain * Float(slow) + Float(sin(p)) * gain * 0.35
        }
        return buf
    }

    /// Radyo parçası — spec 121/122: bozuk kayıt hissi.
    static func radioFragment(text: String, duration: Double = 2.2, gain: Float = 0.35) -> AVAudioPCMBuffer {
        let buf = makeBuffer(duration)
        let n = Int(buf.frameLength)
        let ptr = buf.floatChannelData![0]
        // Hece benzeri modülasyon.
        var carrier: Double = 0
        let seed = Double(text.hashValue.magnitude % 1000) / 1000
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let syllable = sin(2 * .pi * (4.5 + seed * 2) * t)
            let gate = pow(max(0, sin(2 * .pi * 2.2 * t)), 2)
            let f = 620 + syllable * 180
            carrier += 2 * .pi * f / sampleRate
            let s = sin(carrier) * gate
            let crackle = Double.random(in: -1...1) * (Double.random(in: 0...1) < 0.02 ? 0.8 : 0.04)
            let am = 0.6 + 0.4 * sin(2 * .pi * 0.7 * t)
            ptr[i] = Float((s * 0.6 + crackle) * am) * gain
        }
        var shaped = [Float](repeating: 0, count: n)
        let raw = Array(UnsafeBufferPointer(start: buf.floatChannelData![0], count: n))
        shaped = highPass(lowPass(raw, cutoff: 2800), cutoff: 500)
        for i in 0..<n { ptr[i] = shaped[i] }
        return buf
    }

    /// Final harmonik dizi — spec 315: üç frekans tek uyumlu tona dönüşür.
    static func finalChord(duration: Double = 8.0, gain: Float = 0.4) -> AVAudioPCMBuffer {
        let buf = makeBuffer(duration)
        let n = Int(buf.frameLength)
        let ptr = buf.floatChannelData![0]
        let freqs: [Double] = [92, 138, 184, 440, 554, 880, 1760]
        var phases = [Double](repeating: 0, count: freqs.count)
        for i in 0..<n {
            let t = Double(i) / sampleRate
            var s: Double = 0
            for (k, f) in freqs.enumerated() {
                phases[k] += 2 * .pi * f / sampleRate
                let swell = min(1, t / 2.5) * min(1, (duration - t) / 2.0)
                s += sin(phases[k]) / Double(freqs.count) * swell
            }
            ptr[i] = Float(s) * gain
        }
        return buf
    }
}
