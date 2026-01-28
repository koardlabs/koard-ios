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

    public var activeLocation: Location? {
        .downtownCoffee
    }

    public func setup() {}
    
    public func loadActiveLocation() async -> Location? {
        .downtownCoffee
    }

    public func authenticateMerchant() async throws {}

    public func setupLocation() async throws {}

    public func updateLocation(location: Location) { }
    
    public func prepareCardReader() async throws {}

    public func preauthorize(
        amount: Int,
        breakdown: PaymentBreakdown?,
        currency: CurrencyCode
    ) async throws -> TransactionResponse {
        .mockPreauthorizedTransaction
    }

    public func fetchLocations() async throws -> [Location] {
        [.downtownCoffee, .theBookLoft, .seasideGrill]
    }

    public func monitorReaderStatus() {}

    public func processSale(
        subtotal: Int,
        taxRate: Double,
        tipAmount: Int? = 0,
        tipType: PaymentBreakdown.TipType = .fixed,
        surcharge: PaymentBreakdown.Surcharge? = nil
    ) async throws -> KoardTransaction {
        .mockApprovedTransaction
    }

    public func getTransactionHistory(
        startDate: Date?,
        endDate: Date?,
        statuses: [KoardTransaction.Status]?,
        types: [PaymentType]?,
        minAmount: Int?,
        maxAmount: Int?,
        limit: Int?
    ) async throws -> TransactionHistoryResponse {
        .init(
            transactions: [
                .mockApprovedTransaction,
                .mockDeclinedTransction,
                .mockRefundedTransction,
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
                .mockRefundedTransction,
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
                .mockApprovedTransaction,
            ],
            total: 3,
            limit: 25,
            offset: 0,
            page: 1
        )
    }

    public func transactionConfirmed(
        transactionId: String,
        confirm: Bool,
        amount: Int?,
        breakdown: PaymentBreakdown?,
        eventId: String?
    ) async throws -> KoardTransaction {
        .mockApprovedTransaction
    }

    public func fetchTransaction(transactionId: String) async throws -> KoardTransaction {
        .mockApprovedTransaction
    }

    public func captureTransaction(
        transactionId: String,
        subtotal: Int,
        taxRate: Double,
        tipAmount: Int? = 0,
        tipType: PaymentBreakdown.TipType = .fixed,
        finalAmount: Int? = nil
    ) async throws -> TransactionResponse {
        .mockCapturedTransaction
    }
    
    public func incrementalAuth(
        transactionId: String,
        amount: Int
    ) async throws -> TransactionResponse {
        .mockCapturedTransaction
    }
    
    public func reverse(
        transactionId: String,
        amount: Int?
    ) async throws -> TransactionResponse {
        .mockCapturedTransaction
    }

    public func preauthCaptureWorkflow(
        subtotal: Int,
        taxRate: Double,
        tipAmount: Int?,
        tipType: PaymentBreakdown.TipType
    ) async throws -> TransactionResponse {
        .mockCapturedTransaction
    }

    public func incrementalAuthWorkflow(
        initialAmount: Int,
        incrementalSubtotal: Int,
        taxRate: Double,
        tipAmount: Int,
        tipType: PaymentBreakdown.TipType,
        finalAmount: Int
    ) async throws -> TransactionResponse {
        .mockCapturedTransaction
    }

    public func sendReceipts(
        transactionId: String,
        email: String? = nil,
        phoneNumber: String? = nil
    ) async throws -> SendReceiptsResponse {
        .mockReceiptResponse
    }
    
    public func refund(
        transactionID: String,
        amount: Int?,
        eventId: String? = nil,
        withTap: Bool = false
    ) async throws -> TransactionResponse {
        .mockCapturedTransaction
    }
    
    public func logout() {}
}
