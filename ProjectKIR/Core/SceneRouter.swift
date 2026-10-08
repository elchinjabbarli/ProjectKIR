import SpriteKit
import UIKit

/// Sahne geçişleri — spec 465/467.
/// Tüm sahne sunumları buradan yapılır; sahneler kendileri geçiş yapmaz.
enum SceneRouter {

    private(set) static weak var view: SKView?
    private(set) static var coordinator: GameCoordinator?
    private static var presenting = false

    static func attach(view: SKView, coordinator: GameCoordinator) {
        self.view = view
        self.coordinator = coordinator
    }

    /// Fade ile sahne değiştir. Spec 670/671 — yumuşak geçişler.
    static func present(_ scene: SKScene, withFadeDuration duration: TimeInterval = 0.45) {
        guard let v = view, !presenting else { return }
        presenting = true
        scene.scaleMode = .resizeFill
        let reveal = SKTransition.crossFade(withDuration: duration)
        v.presentScene(scene, transition: reveal)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.05) {
            presenting = false
        }
    }

    /// Anında sunum (ilk açılış).
    static func presentImmediately(_ scene: SKScene) {
        guard let v = view else { return }
        scene.scaleMode = .resizeFill
        v.presentScene(scene)
    }

    static var safeInsets: UIEdgeInsets {
        return view?.safeAreaInsets ?? UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
    }
}
