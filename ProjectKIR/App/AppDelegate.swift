import UIKit

/// Uygulama giriş noktası — spec 526 (App Lifecycle).
/// Tüm sahne yönetimi SpriteKit'e, pencere yönetimi burada.
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var coordinator = GameCoordinator()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        AppConfiguration.configure()
        coordinator.bootstrap()
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = GameViewController(coordinator: coordinator)
        window?.makeKeyAndVisible()
        KIRLog.info("App did finish launching. device=\(AppConfiguration.deviceClass)")
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Spec 308 — arka plana geçişte save al ve audio'yu duraklat.
        coordinator.handleAppDidEnterBackground()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        coordinator.handleAppWillEnterForeground()
    }

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        // Spec 5 — yalnızca landscape.
        return .landscape
    }
}
