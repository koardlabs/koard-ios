import Foundation
import KoardSDK

//  Created for SwiftUI Previews and testing.
//
//  This mock implementation of `KoardMerchantServicable` allows you to preview
//  UI components that rely on SDK interactions without making real network calls
//  or requiring merchant credentials.
//
//  Use this mock service to:
//
//  - Render SwiftUI views with sample transaction or login state
//  - Simulate SDK success and failure flows
//  - Keep previews fast, stable, and decoupled from backend dependencies
//
//  Example usage:
//
//      #Preview {
//          TransactionView(merchantService: .mockMerchantService)
//      }
//
extension KoardMerchantServiceable where Self == MockKoardMerchantService {
    public static var mockMerchantService: MockKoardMerchantService {
        MockKoardMerchantService.environment
    }
}

public final class MockKoardMerchantService: KoardMerchantServiceable {
    static let environment = MockKoardMerchantService()

    public var isAuthenticated: Bool {
        true // Simulate always authenticated for previews
    }

    public var isReaderSetupSupported: Bool {
        true // Simulate reader support available for previews
    }

    public func setup() {}

    public func authenticateMerchant() async throws {}

    public func setupLocation() async throws {}

    public func prepareCardReader() async throws {}

    public func monitorReaderStatus() {}

    public func processSale(
        subtotal: Int,
        taxRate: Double,
        tipAmount: Int? = 0,
        tipType: PaymentBreakdown.TipType = .fixed
    ) async throws -> KoardTransaction {
        .mockApprovedTransaction
    }

    public func getTransactionHistory(
        startDate: Date,
        endDate: Date? = Date(),
        statuses: [KoardTransaction.Status],
        types: [PaymentType],
        minAmount: Int,
        maxAmount: Int,
        limit: Int? = 50
    ) async throws -> TransactionHistoryResponse {
        .init(
            transactions: [
                .mockApprovedTransaction,
                .mockDeclinedTransction,
                .mockRefundedTransction
            ],
            total: 3,
            limit: 25,
            offset: 0,
            page: 1
        )
    }

    public func searchTransactions(searchTerm: String) async throws -> TransactionHistoryResponse {
        .init(
            transactions: [
                .mockApprovedTransaction,
                .mockDeclinedTransction,
                .mockRefundedTransction
            ],
            total: 3,
            limit: 25,
            offset: 0,
            page: 1
        )
    }

    public func fetchTransactionsByStatus(status: KoardTransaction.Status) async throws -> TransactionHistoryResponse {
        .init(
            transactions: [
                .mockApprovedTransaction
            ],
            total: 3,
            limit: 25,
            offset: 0,
            page: 1
        )
    }

    public func transactionConfirmed(transactionId: String, confirm: Bool) async throws -> KoardTransaction {
        .mockApprovedTransaction
    }

    public func logout() {}
}
