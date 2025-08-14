import KoardSDK
import SwiftUI

struct TransactionHistoryView: View {
    @State private var viewModel: TransactionHistoryViewModel

    init(viewModel: TransactionHistoryViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack {
            VStack {
                if viewModel.isFetchingTransactions {
                    ProgressView("Loading transactions...")
                        .padding()
                } else if viewModel.transactions.isEmpty {
                    Text("No transactions found")
                        .foregroundStyle(.koardGreen)
                        .foregroundColor(.secondary)
                        .padding(.top, 44)
                } else {
                    List {
                        ForEach(viewModel.transactions, id: \.transactionId) { transaction in
                            Button {
                                viewModel.transactionSelected(transaction: transaction)
                            } label: {
                                TransactionCardView(
                                    viewModel: viewModel,
                                    transaction: transaction
                                )
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }

                Spacer()
            }
            .task {
                await viewModel.getTransactions()
            }
            .sheet(item: $viewModel.destination) { destination in
                switch destination {
                case let .transactionDetails(detailsViewModel):
                    TransactionDetailsView(viewModel: detailsViewModel)
                        .presentationDragIndicator(.visible)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Transaction History")
            .tint(.koardGreen)
            .background(KoardBackgroundView())
        }
    }
}

struct TransactionCardView: View {
    @State private var viewModel: TransactionHistoryViewModel
    private var transaction: KoardTransaction
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    public init(
        viewModel: TransactionHistoryViewModel,
        transaction: KoardTransaction
    ) {
        self.viewModel = viewModel
        self.transaction = transaction
    }
        
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(transaction.card)
                    .foregroundStyle(.black)
                Spacer()
                Text(transaction.status.displayName)
                    .foregroundColor(transaction.status.statusColor)
            }
            .font(.system(size: 14, weight: .semibold))
            
            HStack {
                Text(dateFormatter.string(from: transaction.createdAtDate))
                    .foregroundStyle(.black)
                Spacer()
                HStack(spacing: 4) {
                    if let type = transaction.transactionType, !type.isEmpty {
                        Text(type.capitalized)
                            .foregroundStyle(.black)
                            .lineLimit(1)
                            .font(.system(size: 13))
                    }
                    
                    Text(MoneyUtils.centsToStringWithCurrency(transaction.totalAmount))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.koardGreen)
                }
            }
        }
    }
}

#Preview {
    TransactionHistoryView(viewModel: .init(koardMerchantService: .mockMerchantService))
}
