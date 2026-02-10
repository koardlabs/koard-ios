import SwiftUI
import KoardSDK

struct RootView: View {
    @State private var isAuthenticated: Bool

    private let koardMerchantService: KoardMerchantServiceable

    init(koardMerchantService: KoardMerchantServiceable) {
        self.koardMerchantService = koardMerchantService
        // Initialize with actual authentication status from SDK
        self._isAuthenticated = State(initialValue: koardMerchantService.isAuthenticated)
    }

    var body: some View {
        Group {
            if isAuthenticated {
                MainTabView(
                    koardMerchantService: koardMerchantService,
                    onLogout: {
                        checkAuthenticationStatus()
                    }
                )
            } else {
                LoginView(
                    viewModel: .init(
                        koardMerchantService: koardMerchantService,
                        onAuthenticationSuccess: {
                            checkAuthenticationStatus()
                        }
                    )
                )
            }
        }
        .onAppear {
            checkAuthenticationStatus()
        }
    }

    private func checkAuthenticationStatus() {
        let wasAuthenticated = isAuthenticated
        isAuthenticated = koardMerchantService.isAuthenticated

        print("""
        [RootView] Auth status check:
          - Was authenticated: \(wasAuthenticated)
          - Now authenticated: \(isAuthenticated)
          - SDK isAuthenticated: \(koardMerchantService.isAuthenticated)
        """)
    }
}

#Preview {
    RootView(koardMerchantService: .mockMerchantService)
}
