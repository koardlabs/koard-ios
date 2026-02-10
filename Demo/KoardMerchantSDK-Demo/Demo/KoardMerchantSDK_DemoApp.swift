import KoardSDK
import SwiftUI

@main
struct KoardMerchantSDK_DemoApp: App {
    private let koardMerchantService: KoardMerchantServiceable
    @Environment(\.scenePhase) private var scenePhase

    init() {
        UISegmentedControl.appearance().selectedSegmentTintColor = .koardGreen
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.koardGreen], for: .normal)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [.foregroundColor: UIColor.koardGreen]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.koardGreen]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance

        guard let config = ConfigurationManager.loadConfiguration() else {
            fatalError("Failed to load configuration. Please ensure Config.plist exists and contains valid credentials.")
        }

        koardMerchantService = KoardMerchantService(
            apiKey: config.apiKey,
            environment: config.environment,
            customURL: config.customURL,
            merchantCode: config.merchantCode,
            merchantPin: config.merchantPin
        )

        // Initialize SDK immediately so it can read persisted auth token from Keychain
        koardMerchantService.setup()
    }

    var body: some Scene {
        WindowGroup {
            RootView(koardMerchantService: koardMerchantService)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .active:
                print("App became active - checking auth and reader status")
                // When app comes to foreground, refresh reader session if authenticated
                if koardMerchantService.isAuthenticated && koardMerchantService.isReaderSetupSupported {
                    Task {
                        do {
                            try await koardMerchantService.prepareCardReader()
                            print("Card reader refreshed on app active")
                        } catch {
                            print("Failed to refresh card reader: \(error)")
                        }
                    }
                }
            case .background:
                print("App moved to background")
            case .inactive:
                print("App became inactive")
            @unknown default:
                break
            }
        }
    }
}
