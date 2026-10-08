import SpriteKit
import UIKit

/// Dokunmatik kontroller — spec 77/78/142/142.
/// Sol: sanal joystick (hareket). Sağ: zıplama + rezonans şarj.
/// Frekans: sağ üstte üç küçük frekans çipi (tek dokunuş).
/// Tüm HUD güvenli alana göre hizalanır (spec 5).
final class TouchControls: SKNode {

    // Joystick
    private let stickBase: SKShapeNode
    private let stickKnob: SKShapeNode
    private var stickTouch: UITouch?
    private var stickCenter: CGPoint = .zero
    private(set) var stickVector: CGVector = CGVector(dx: 0, dy: 0)

    // Butonlar
    private let jumpButton: SKShapeNode
    private let chargeButton: SKShapeNode
    private let crouchButton: SKShapeNode          // Eğilme — spec 56 (low-ceiling + gizlenme)
    private var jumpTouch: UITouch?
    private var chargeTouch: UITouch?
    private var crouchTouch: UITouch?
    private(set) var crouchHeld = false

    // Frekans seçici — spec 16/149
    private var freqChips: [ResonanceFrequency: SKShapeNode] = [:]
    private var freqLabels: [ResonanceFrequency: SKLabelNode] = [:]
    private var selectedFrequency: ResonanceFrequency = .deep
    private var freqTouch: UITouch?

    // Süreklilik için buton durumları
    private(set) var jumpHeld = false
    private(set) var jumpPressedEdge = false
    private(set) var chargeHeld = false
    private(set) var chargeReleasedEdge = false

    // Duraklatma butonu (dokunmatik için gerekli)
    private let pauseButton: SKShapeNode
    private var pauseTouch: UITouch?

    var visible = true

    override init() {
        // Joystick
        stickBase = SKShapeNode(circleOfRadius: 64)
        stickBase.fillColor = SKColor(white: 1, alpha: 0.05)
        stickBase.strokeColor = SKColor(white: 1, alpha: 0.22)
        stickBase.lineWidth = 2
        stickKnob = SKShapeNode(circleOfRadius: 26)
        stickKnob.fillColor = SKColor(white: 1, alpha: 0.18)
        stickKnob.strokeColor = KIRPalette.dirtyWhite
        stickKnob.lineWidth = 2

        // Zıplama butonu
        jumpButton = SKShapeNode(circleOfRadius: 44)
        jumpButton.fillColor = SKColor(white: 1, alpha: 0.06)
        jumpButton.strokeColor = KIRPalette.dirtyWhite
        jumpButton.lineWidth = 2
        let jl = SKLabelNode.caption("↑", size: 26, color: KIRPalette.dirtyWhite)

        // Rezonans butonu
        chargeButton = SKShapeNode(circleOfRadius: 52)
        chargeButton.fillColor = KIRPalette.amber.withAlphaComponent(0.10)
        chargeButton.strokeColor = KIRPalette.amber
        chargeButton.lineWidth = 2
        let cl = SKLabelNode.caption("◈", size: 24, color: KIRPalette.amber)

        // Eğilme butonu — joystick'in sağ üstü (spec 56: low-ceiling geçişi + droneden saklanma).
        crouchButton = SKShapeNode(circleOfRadius: 34)
        crouchButton.fillColor = SKColor(white: 1, alpha: 0.06)
        crouchButton.strokeColor = KIRPalette.dirtyWhite.withAlphaComponent(0.7)
        crouchButton.lineWidth = 2
        let crl = SKLabelNode.caption("▼", size: 18, color: KIRPalette.dirtyWhite)

        super.init()
        addChild(stickBase)
        stickBase.addChild(stickKnob)
        addChild(jumpButton)
        jumpButton.addChild(jl)
        addChild(chargeButton)
        chargeButton.addChild(cl)
        addChild(crouchButton)
        crouchButton.addChild(crl)

        // Duraklat — sol üst, güvenli alan içinde.
        pauseButton = SKShapeNode(rectOf: CGSize(width: 44, height: 44), cornerRadius: 10)
        pauseButton.fillColor = SKColor(white: 1, alpha: 0.05)
        pauseButton.strokeColor = KIRPalette.dirtyWhite.withAlphaComponent(0.5)
        pauseButton.lineWidth = 1.5
        let pl = SKLabelNode.caption("❚❚", size: 15, color: KIRPalette.dirtyWhite)
        pauseButton.addChild(pl)
        addChild(pauseButton)

        zPosition = 950
        name = NodeNames.hud
        isUserInteractionEnabled = true

        for f in ResonanceFrequency.allCases {
            let chip = SKShapeNode(rectOf: CGSize(width: 46, height: 34), cornerRadius: 6)
            chip.fillColor = KIRPalette.color(for: f).withAlphaComponent(0.14)
            chip.strokeColor = KIRPalette.color(for: f)
            chip.lineWidth = 2
            let l = SKLabelNode.caption(f.shortLabel, size: 13, color: KIRPalette.color(for: f))
            chip.addChild(l)
            addChild(chip)
            freqChips[f] = chip
            freqLabels[f] = l
        }
        refreshFreqVisual()
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) kullanılmıyor") }

    // MARK: - Yerleşim (safe area; kamera çocuğu → merkez origin)
    func layout(for size: CGSize) {
        let safe = SceneRouter.safeInsets
        let left = -size.width / 2
        let right = size.width / 2
        let bottom = -size.height / 2
        let top = size.height / 2
        let y = bottom + size.height * 0.22
        stickCenter = CGPoint(x: left + 120 + safe.left, y: y)
        stickBase.position = stickCenter
        stickKnob.position = .zero
        jumpButton.position = CGPoint(x: right - 210 - safe.right, y: y)
        chargeButton.position = CGPoint(x: right - 96 - safe.right, y: y + 46)
        crouchButton.position = CGPoint(x: left + 236 + safe.left, y: y + 8)
        pauseButton.position = CGPoint(x: left + 46 + safe.left, y: top - 46 - safe.top)
        let chips: [ResonanceFrequency] = [.deep, .body, .edge]
        for (i, f) in chips.enumerated() {
            freqChips[f]?.position = CGPoint(x: right - 100 - safe.right - CGFloat(i) * 54,
                                             y: top - 52 - safe.top)
        }
    }

    // MARK: - Dokunma
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard visible else { return }
        for t in touches {
            let p = t.location(in: self)
            if Math2D.distance(p, pauseButton.position) < 40 {
                NotificationCenter.default.post(name: .kirTogglePause, object: nil)
                return
            }
            if freqChipHit(p) { continue }
            if containsNode(crouchButton, point: p) {
                if crouchTouch == nil {
                    crouchTouch = t
                    crouchHeld = true
                }
            } else if containsNode(jumpButton, point: p) {
                if jumpTouch == nil {
                    jumpTouch = t
                    jumpHeld = true
                    jumpPressedEdge = true
                }
            } else if containsNode(chargeButton, point: p) {
                if chargeTouch == nil {
                    chargeTouch = t
                    chargeHeld = true
                }
            } else if Math2D.distance(p, stickBase.position) < 110 && stickTouch == nil {
                stickTouch = t
                updateStick(to: p)
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            if t == stickTouch { updateStick(to: t.location(in: self)) }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouches(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouches(touches)
    }

    private func endTouches(_ touches: Set<UITouch>) {
        for t in touches {
            if t == stickTouch {
                stickTouch = nil
                stickVector = CGVector(dx: 0, dy: 0)
                stickKnob.run(SKAction.move(to: .zero, duration: 0.12))
            }
            if t == jumpTouch { jumpTouch = nil; jumpHeld = false }
            if t == crouchTouch { crouchTouch = nil; crouchHeld = false }
            if t == chargeTouch {
                chargeTouch = nil
                if chargeHeld { chargeReleasedEdge = true }
                chargeHeld = false
            }
            if t == pauseTouch { pauseTouch = nil }
        }
    }

    private func updateStick(to p: CGPoint) {
        var v = CGVector(dx: p.x - stickCenter.x, dy: p.y - stickCenter.y)
        let len = hypot(v.dx, v.dy)
        let maxLen: CGFloat = 52
        if len > maxLen {
            v.dx = v.dx / len * maxLen
            v.dy = v.dy / len * maxLen
        }
        stickKnob.position = CGPoint(x: v.dx, y: v.dy)
        let dead: CGFloat = 12
        let normLen = max(0, min(1, (len - dead) / (maxLen - dead)))
        if len < dead || abs(v.dx) < 2 {
            stickVector = CGVector(dx: 0, dy: 0)
        } else {
            let dirSign: CGFloat = v.dx > 0 ? 1 : -1
            stickVector = CGVector(dx: dirSign * normLen, dy: 0)
        }
    }

    // MARK: - Frekans erişimi (kademeli tanıtım — spec 894/M02/M03)
    private var availableFrequencies: Set<ResonanceFrequency> = Set(ResonanceFrequency.allCases)

    func setAvailableFrequencies(_ fs: [ResonanceFrequency]) {
        availableFrequencies = Set(fs)
        if !availableFrequencies.contains(selectedFrequency),
           let first = availableFrequencies.first {
            selectedFrequency = first
        }
        refreshFreqVisual()
    }

    private func freqChipHit(_ p: CGPoint) -> Bool {
        for (f, chip) in freqChips {
            guard availableFrequencies.contains(f) else { continue }
            let local = convert(p, to: chip)
            if abs(local.x) < 26 && abs(local.y) < 22 {
                selectedFrequency = f
                refreshFreqVisual()
                NotificationCenter.default.post(name: .kirFrequencyDirect, object: f.rawValue)
                return true
            }
        }
        return false
    }

    func selectFrequency(_ f: ResonanceFrequency) {
        selectedFrequency = f
        refreshFreqVisual()
    }

    private func refreshFreqVisual() {
        for (f, chip) in freqChips {
            let unlocked = availableFrequencies.contains(f)
            let sel = f == selectedFrequency
            chip.setScale(sel ? 1.15 : 0.9)
            chip.alpha = unlocked ? (sel ? 1.0 : 0.55) : 0.10
            chip.isHidden = !unlocked
        }
    }

    private func containsNode(_ node: SKNode, point p: CGPoint) -> Bool {
        // Butonlar dairesel: merkeze uzaklık yeterli.
        let r = max(node.frame.width, node.frame.height) / 2 + 14
        return Math2D.distance(p, node.position) < r
    }

    // MARK: - Kare başı sıfırlama
    func consumeEdges() -> (jump: Bool, release: Bool) {
        let j = jumpPressedEdge
        let r = chargeReleasedEdge
        jumpPressedEdge = false
        chargeReleasedEdge = false
        return (j, r)
    }

    func apply(to input: inout InputState) {
        if abs(stickVector.dx) > 0.02 { input.moveX = stickVector.dx }
        if jumpHeld { input.jumpHeld = true }
        if chargeHeld { input.chargeHeld = true }
        if crouchHeld { input.crouchHeld = true }
    }

    func setChargeVisual(progress: CGFloat, full: Bool) {
        let s = 1 + progress * 0.25 + (full ? 0.08 : 0)
        chargeButton.setScale(s)
        chargeButton.strokeColor = full ? KIRPalette.dirtyWhite : KIRPalette.amber
    }

    func flashFrequency(_ f: ResonanceFrequency) {
        selectFrequency(f)
        if let chip = freqChips[f] {
            chip.run(SKAction.sequence([
                SKAction.scale(to: 1.35, duration: 0.07),
                SKAction.scale(to: 1.15, duration: 0.12)
            ]))
        }
    }
}
