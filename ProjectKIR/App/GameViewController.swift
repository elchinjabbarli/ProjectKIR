import SpriteKit
import UIKit

/// SKView'i barındıran tek viewController.
/// Spec 523/524 — UI teknolojisi: SpriteKit + UIKit, storyboard yok.
final class GameViewController: UIViewController {

    private let coordinator: GameCoordinator
    private var skView: SKView { view as! SKView }

    init(coordinator: GameCoordinator) {
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) kullanılmıyor") }

    override func loadView() {
        let v = SKView(frame: UIScreen.main.bounds)
        v.ignoresSiblingOrder = true
        v.preferredFramesPerSecond = 60
        v.showsFPS = AppConfiguration.isDebugBuild
        v.showsNodeCount = AppConfiguration.isDebugBuild
        view = v
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        SceneRouter.attach(view: skView, coordinator: coordinator)
        coordinator.launchFromMainMenu()
    }

    override var prefersHomeIndicatorAutoHidden: Bool { false }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }

    override var prefersStatusBarHidden: Bool { true }

    // Spec 308 — kesinti anında oyunu duraklat.
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if !isBeingDismissed { coordinator.handleAppDidEnterBackground() }
    }
}
