import KoardSDK
import SwiftUI

struct ContentView: View {
    @State private var viewModel: ContentViewModel

    init(viewModel: ContentViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(spacing: 12) {
            AsyncButton {
                await viewModel.authenticateMerchantButtonTapped()
            } label: {
                Text(viewModel.isAuthenticated ? "Logout" : "Authenticate Merchant")
            }
            .disabled(viewModel.isAuthenticating)
            .buttonStyle(.primary)
            .overlay {
                if viewModel.isAuthenticating {
                    ProgressView()
                        .tint(.white)
                }
            }
            .padding(.top, 100)

            Text(viewModel.authenticationError)
                .font(.caption)
                .foregroundColor(.red)
                .opacity(viewModel.authenticationError.isEmpty ? 0 : 1)

            AsyncButton {
                await viewModel.setupReader()
            } label: {
                Text("Setup Card Reader")
            }
            .disabled(!viewModel.isReaderSetupSupported || viewModel.isPreparingReader)
            .buttonStyle(.primary)
            .overlay {
                if viewModel.isPreparingReader {
                    ProgressView()
                        .tint(.white)
                }
            }

            Group {
                if viewModel.isReaderReady {
                    Text("Card reader prepared and ready")
                        .foregroundColor(.koardGreen)
                } else {
                    Text("Card Reader Not Ready")
                        .foregroundColor(.red)
                        .opacity(!viewModel.isReaderSetupSupported ? 0.5 : 1)
                }
            }
            .font(.subheadline)
            .fontWeight(.medium)

            AsyncButton {
                await viewModel.processSale()
            } label: {
                VStack {
                    Text("Process Sample Transaction")
                    Text("$10.00 Sale - $1.00 Tip")
                        .font(.caption)
                }
            }
            .disabled(!viewModel.isReaderReady || viewModel.isProcessingSale)
            .buttonStyle(.primary)
            .overlay {
                if viewModel.isProcessingSale {
                    ProgressView()
                        .tint(.white)
                }
            }

            Divider()
                .padding(.vertical, 20)

            AsyncButton {
                await viewModel.getTransactions()
            } label: {
                Text("Get Transaction History")
            }
            .disabled(!viewModel.isAuthenticated)
            .buttonStyle(.primary)
            .overlay {
                if viewModel.isFetchingTransactions {
                    ProgressView()
                        .tint(.white)
                }
            }

            Spacer()
        }
        .onAppear {
            viewModel.onAppear()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KoardBackgroundView())
        .overlay(alignment: .top) {
            Image("koardLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 200, height: 20)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.7))
                        .background(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                )
                .padding(.top, 10)
        }
    }
}

#Preview {
    ContentView(viewModel: .init(koardMerchantService: .mockMerchantService))
}
