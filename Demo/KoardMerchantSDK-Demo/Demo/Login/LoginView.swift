import SwiftUI
import KoardSDK

struct LoginView: View {
    @State private var viewModel: LoginViewModel

    init(viewModel: LoginViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Koard Logo/Branding
            VStack(spacing: 12) {
                Image(systemName: "creditcard.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundStyle(.koardGreen)

                Text("Koard Merchant Demo")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
            }

            Spacer()

            // Credential Input Fields
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Merchant Code")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextField("Enter merchant code", text: $viewModel.merchantCode)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Merchant PIN")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    SecureField("Enter PIN", text: $viewModel.merchantPin)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
            }
            .padding(.horizontal, 20)

            // Login Button
            AsyncButton {
                await viewModel.authenticate()
            } label: {
                HStack(spacing: 12) {
                    if viewModel.isAuthenticating {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Login")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .buttonStyle(.borderedProminent)
            .tint(.koardGreen)
            .disabled(viewModel.isAuthenticating || !viewModel.canLogin)
            .padding(.horizontal, 20)

            // Error Message
            if !viewModel.authenticationError.isEmpty {
                Text(viewModel.authenticationError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
                .frame(height: 40)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            KoardBackgroundView()
                .ignoresSafeArea()
        }
    }
}

#Preview {
    LoginView(
        viewModel: .init(
            koardMerchantService: .mockMerchantService,
            onAuthenticationSuccess: {}
        )
    )
}
