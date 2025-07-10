import KoardSDK
import SwiftUI

@main
struct KoardMerchantSDK_DemoApp: App {
    private let koardMerchantService: KoardMerchantServiceable

    init() {
        koardMerchantService = KoardMerchantService(
            apiKey: "<Your API Key>",
            merchantCode: "<Your Merchant Code>",
            merchantPin: "<Your Merchant Pin>"
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
