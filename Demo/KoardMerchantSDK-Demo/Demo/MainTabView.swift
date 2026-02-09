import SwiftUI
import KoardSDK

struct MainTabView: View {
    let koardMerchantService: KoardMerchantServiceable
    let onLogout: () -> Void

    @State private var selectedTab: Int = 1

    var body: some View {
        TabView(selection: $selectedTab) {
            TransactionHistoryView(
                viewModel: .init(koardMerchantService: koardMerchantService)
            )
            .tabItem {
                Image(systemName: "list.bullet")
                Text("History")
            }
            .tag(0)

            NavigationStack {
                TransactionView(
                    viewModel: .init(koardMerchantService: koardMerchantService)
                )
            }
            .tabItem {
                Image(systemName: "creditcard")
                Text("Transaction")
            }
            .tag(1)

            SettingsView(
                viewModel: .init(
                    koardMerchantService: koardMerchantService,
                    onLogout: onLogout
                )
            )
            .tabItem {
                Image(systemName: "gearshape")
                Text("Settings")
            }
            .tag(2)
        }
        .tint(.koardGreen)
    }
}

#Preview {
    MainTabView(
        koardMerchantService: .mockMerchantService,
        onLogout: {}
    )
}