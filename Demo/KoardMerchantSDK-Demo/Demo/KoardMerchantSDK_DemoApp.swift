import KoardSDK
import SwiftUI

@main
struct KoardMerchantSDK_DemoApp: App {
    private let koardMerchantService: KoardMerchantServiceable

    init() {
        koardMerchantService = KoardMerchantService(
            apiKey: "krd_s27IllrxIdLDaA6N7bH_oIdoGsFkSQTKj0c9yUY4h04",
            merchantCode: "6uTCmwtoDRPF",
            merchantPin: "598993",
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
