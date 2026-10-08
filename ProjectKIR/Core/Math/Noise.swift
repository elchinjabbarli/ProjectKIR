import Foundation

/// Hafif değer gürültüsü — prosedürel ambiyans ve partikül varyasyonu için.
/// Spec 177 (Ambient Randomizer) ve 502 (Sound Randomization) temel taşı.
struct Noise {

    private var seed: UInt64
    private static let mask: UInt64 = 0x7FFFFFFF

    init(seed: UInt64 = 0x9E3779B97F4A7C15) {
        self.seed = seed == 0 ? 1 : seed
    }

    private mutating func next() -> Double {
        // xorshift64*
        seed ^= seed >> 12
        seed ^= seed << 25
        seed ^= seed >> 27
        return Double((seed &* 2685821657736338717) >> 11) / Double(1 << 53)
    }

    /// [0,1) uniform rastgele.
    mutating func uniform() -> Double { return next() }

    mutating func uniform(_ lo: Double, _ hi: Double) -> Double {
        return lo + (hi - lo) * next()
    }

    /// [-1,1) arası.
    mutating func bipolar() -> Double { return next() * 2 - 1 }

    /// Basit değer gürültüsü (1B).
    static func value1D(x: Double, seed: Double) -> Double {
        let ix = floor(x)
        let fx = x - ix
        let smooth = fx * fx * (3 - 2 * fx)
        let h0 = hash(ix, seed)
        let h1 = hash(ix + 1, seed)
        return h0 + (h1 - h0) * smooth
    }

    private static func hash(_ i: Double, _ seed: Double) -> Double {
        var x = sin(i * 127.1 + seed * 311.7) * 43758.5453
        x = x - floor(x)
        return x
    }
}
