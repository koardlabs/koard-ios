import KoardSDK
import SwiftUI

@main
struct KoardMerchantSDK_DemoApp: App {
    private let koardMerchantService: KoardMerchantServiceable

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
            merchantCode: config.merchantCode,
            merchantPin: config.merchantPin
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: .init(koardMerchantService: koardMerchantService))
                .onAppear {
                    koardMerchantService.setup()
                }
        }
    }
}
