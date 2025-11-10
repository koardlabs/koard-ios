import SwiftUI
import KoardSDK

struct MainTabView: View {
    let koardMerchantService: KoardMerchantServiceable
    
    var body: some View {
        TabView {
            ContentView(viewModel: .init(koardMerchantService: koardMerchantService))
                .tabItem {
                    Image(systemName: "house")
                    Text("Home")
                }
            
            TransactionsHistoryView(koardMerchantService: koardMerchantService)
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Transactions")
                }
            
            CheckoutView()
                .tabItem {
                    Image(systemName: "creditcard")
                    Text("Checkout")
                }
        }
        .tint(.koardGreen)
    }
}

#Preview {
    MainTabView(koardMerchantService: .mockMerchantService)
}