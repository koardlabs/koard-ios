import SwiftUI

struct CheckoutView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "creditcard.circle")
                    .font(.system(size: 72))
                    .foregroundColor(.koardGreen)
                
                Text("Checkout")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Checkout functionality coming soon!")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Checkout")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    CheckoutView()
}