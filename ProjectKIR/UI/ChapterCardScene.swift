import SpriteKit

/// Bölüm geçiş kartı — spec 136: numara + isim, sade, 2.5 sn.
final class ChapterCardScene: SKScene {

    var coordinator: GameCoordinator!
    private let nextLevelID: String
    private var elapsed: TimeInterval = 0
    private let info: ChapterInfo

    init(nextLevelID: String, coordinator: GameCoordinator) {
        self.nextLevelID = nextLevelID
        self.info = ChapterInfo(levelID: nextLevelID)
        super.init(size: CGSize(width: 1334, height: 750))
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) kullanılmıyor") }

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(white: 0.02, alpha: 1)
        coordinator.audio.playChapterTransition()

        let cx = size.width / 2
        let cy = size.height / 2

        let chapterLabel = SKLabelNode.caption("\(KIRStrings.chapterPrefix) \(info.number)",
                                              size: 22, color: KIRPalette.ash)
        chapterLabel.position = CGPoint(x: cx, y: cy + 60)
        addChild(chapterLabel)

        let nameLabel = SKLabelNode(info.title)
        nameLabel.fontName = "AvenirNext-Medium"
        nameLabel.fontSize = 42
        nameLabel.fontColor = KIRPalette.dirtyWhite
        nameLabel.position = CGPoint(x: cx, y: cy)
        addChild(nameLabel)

        let line = SKShapeNode(rectOf: CGSize(width: 220, height: 2))
        line.fillColor = KIRPalette.amber
        line.strokeColor = KIRPalette.amber
        line.position = CGPoint(x: cx, y: cy - 64)
        addChild(line)

        chapterLabel.run(SKAction.sequence([
            SKAction.fadeIn(withDuration: 0.8),
            SKAction.wait(forDuration: 1.8)
        ]))
    }

    override func update(_ currentTime: TimeInterval) {
        elapsed += 1.0 / 60.0
        if elapsed > 2.8 {
            coordinator.advanceFromChapterCard()
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Dokunuş kartı atlar (spec 212 — cutscene skip).
        coordinator.advanceFromChapterCard()
    }
}
