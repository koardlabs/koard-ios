import KoardSDK
import SwiftUI

struct ContentView: View {
    @State private var viewModel: ContentViewModel

    init(viewModel: ContentViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack {
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

                Button {
                    viewModel.showLocationSelectionTapped()
                } label: {
                    Text(viewModel.selectedLocation?.name ?? "Select Location")
                        .underline()
                }
                .disabled(!viewModel.isAuthenticated)
                .padding(.top, 8)

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

                Divider()
                    .padding(.vertical, 20)

                Button {
                    viewModel.transactionFlowTapped()
                } label: {
                    HStack {
                        Text("Process Sample Transaction")
                        Image(systemName: "chevron.right")
                    }
                }
                .buttonStyle(.primary)

                Divider()
                    .padding(.vertical, 20)

                Button {
                    viewModel.transactionHistoryTapped()
                } label: {
                    Text("Transaction History")
                }
                .disabled(!viewModel.isAuthenticated)
                .buttonStyle(.primary)

                Spacer()
            }
            .onAppear {
                viewModel.onAppear()
            }
            .sheet(item: $viewModel.destination) { destination in
                switch destination {
                case let .locationSelection(locationViewModel):
                    LocationSelectionView(viewModel: locationViewModel)
                case let .transactionHistory(historyViewModel):
                    TransactionHistoryView(viewModel: historyViewModel)
                        .presentationDragIndicator(.visible)
                }
            }
            .navigationDestination(item: $viewModel.navigationDestination) { destination in
                switch destination {
                case let .sampleTransactionFlow(transactionViewModel):
                    TransactionView(viewModel: transactionViewModel)
                }
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
        .tint(.koardGreen)
    }
}

#Preview {
    ContentView(viewModel: .init(koardMerchantService: .mockMerchantService))
}
