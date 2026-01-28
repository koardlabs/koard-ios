import Foundation
import KoardSDK

@MainActor
@Observable
class TransactionsHistoryViewModel {
    private let koardMerchantService: KoardMerchantServiceable
    
    var transactions: [KoardTransaction] = []
    var isLoading: Bool = false
    var errorMessage: String = ""
    
    init(koardMerchantService: KoardMerchantServiceable) {
        self.koardMerchantService = koardMerchantService
    }
    
    func loadTransactions() async {
        isLoading = true
        errorMessage = ""
        
        defer {
            isLoading = false
        }
        
        do {
            let response = try await koardMerchantService.getTransactionHistory(
                startDate: Date().addingTimeInterval(-86400 * 30), // Last 30 days
                endDate: Date(),
                statuses: [.captured, .declined, .authorized, .pending, .reversed, .refunded, .error, .surchargePending],
                types: [.sale, .refund, .auth, .reverse],
                minAmount: 1,
                maxAmount: 1000000,
                limit: 100
            )
            
            transactions = response.transactions.sorted { $0.createdAtDate > $1.createdAtDate }
        } catch {
            errorMessage = "Failed to load transactions: \(error.localizedDescription)"
            print("Transaction history error: \(error)")
        }
    }

    func maximumActionAmount(for transaction: KoardTransaction) -> Int? {
        guard let authorizedAmount = authorizedAmount(for: transaction), authorizedAmount > 1 else {
            return nil
        }
        return max(authorizedAmount - 1, 0)
    }

    func authorizedAmount(for transaction: KoardTransaction) -> Int? {
        if let amount = transaction.gatewayTransactionResponse?.authorizedAmount, amount > 0 {
            return amount
        }

        if transaction.totalAmount > 0 {
            return transaction.totalAmount
        }

        return nil
    }

    func performReverse(for transaction: KoardTransaction, amount: Int) async -> Result<TransactionResponse, Error> {
        do {
            let response = try await koardMerchantService.reverse(transactionId: transaction.transactionId, amount: amount)
            await loadTransactions()
            return .success(response)
        } catch {
            return .failure(error)
        }
    }

    func performIncrementalAuth(for transaction: KoardTransaction, amount: Int) async -> Result<TransactionResponse, Error> {
        do {
            let response = try await koardMerchantService.incrementalAuth(transactionId: transaction.transactionId, amount: amount)
            await loadTransactions()
            return .success(response)
        } catch {
            return .failure(error)
        }
    }
}
