import Foundation
import KoardSDK

@MainActor
@Observable
public final class TransactionHistoryViewModel: Identifiable {
    public private(set) var isFetchingTransactions: Bool = false
    public private(set) var transactions: [KoardTransaction] = []
    public var destination: Destination?

    @ObservationIgnored public let id: UUID = UUID()
    @ObservationIgnored private let koardMerchantService: KoardMerchantServiceable

    public enum Destination: Identifiable, Hashable {
        public var id: Self { self }
        case transactionDetails(TransactionDetailsViewModel)
    }

    init(
        koardMerchantService: KoardMerchantServiceable
    ) {
        self.koardMerchantService = koardMerchantService
    }

    public func getTransactions() async {
        isFetchingTransactions = true

        defer {
            isFetchingTransactions = false
        }

        do {
            let transactionResponse = try await koardMerchantService.getTransactionHistory(
                startDate: Date().addingTimeInterval(-86400 * 180), // Last 180 days
                endDate: Date(), // Up to now
                statuses: nil,
                types: nil,
                minAmount: nil,
                maxAmount: nil,
                limit: 50
            )

            transactions = transactionResponse.transactions
            print(transactions.count)
        } catch {
            // Handle any errors that occur during reader setup
            print(error)
        }
    }

    public func transactionSelected(transaction: KoardTransaction) {
        let viewModel = TransactionDetailsViewModel(
            koardMerchantService: koardMerchantService,
            transaction: transaction,
            delegate: .init(
                onTransactionUpdate: { [weak self] in
                    Task {
                        await self?.getTransactions()
                    }
                }
            )
        )

        destination = .transactionDetails(viewModel)
    }
}

extension TransactionHistoryViewModel: Hashable {
    public nonisolated static func == (lhs: TransactionHistoryViewModel, rhs: TransactionHistoryViewModel) -> Bool {
        lhs.id == rhs.id
    }

    public nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
