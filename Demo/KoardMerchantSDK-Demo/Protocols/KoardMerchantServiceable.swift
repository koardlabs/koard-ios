import Foundation
import KoardSDK

/// A protocol that defines the public contract for interacting with the Koard SDK in your app.
///
/// This abstraction is designed to be implemented by wrapper or service types like `KoardMerchantService`,
/// allowing your app to decouple from the SDK itself. This approach improves testability, simplifies mocking,
/// and promotes clean architecture.
///
/// By relying on this protocol instead of the SDK directly, you can:
/// - Inject test doubles in SwiftUI previews or unit tests
/// - Abstract SDK functionality for custom workflows
/// - Swap out or extend functionality without rewriting core logic
///
/// This protocol is intended as a starting point. It can and should be modified, extended, or simplified
/// based on the specific needs of your application and integration with the Koard SDK.
///
/// ### Example Usage:
/// ```swift
/// final class KoardMerchantService: KoardMerchantServiceable {
///     func setup() { ... }
///     func authenticateMerchant() async throws { ... }
///     // ... other methods
/// }
/// ```
///
///  This protocol can also be used to mock SDK behavior for testing and preview purposes.
///
public protocol KoardMerchantServiceable {
    var isAuthenticated: Bool { get }
    var isReaderSetupSupported: Bool { get }
    var activeLocation: Location? { get }
    
    func setup()
    func authenticateMerchant() async throws
    func setupLocation() async throws
    func prepareCardReader() async throws
    func monitorReaderStatus()
    func fetchLocations() async throws -> [Location]
    func updateLocation(location: Location)
    
    func preauthorize(
        amount: Int,
        currency: CurrencyCode) async throws -> TransactionResponse
    
    func processSale(
        subtotal: Int,
        taxRate: Double,
        tipAmount: Int?,
        tipType: PaymentBreakdown.TipType
    ) async throws -> KoardTransaction
    
    func getTransactionHistory(
        startDate: Date,
        endDate: Date?,
        statuses: [KoardTransaction.Status],
        types: [PaymentType],
        minAmount: Int,
        maxAmount: Int,
        limit: Int?
    ) async throws -> TransactionHistoryResponse
    
    func transactionConfirmed(transactionId: String, confirm: Bool) async throws -> KoardTransaction
    func searchTransactions(searchTerm: String) async throws -> TransactionHistoryResponse
    func fetchTransactionsByStatus(status: KoardTransaction.Status) async throws -> TransactionHistoryResponse
    
    func captureTransaction(
        transactionId: String,
        subtotal: Int,
        taxRate: Double,
        tipAmount: Int?,
        tipType: PaymentBreakdown.TipType,
        finalAmount: Int?
    ) async throws -> String
    
    func preauthCaptureWorkflow(
        subtotal: Int,
        taxRate: Double,
        tipAmount: Int?,
        tipType: PaymentBreakdown.TipType
    ) async throws -> TransactionResponse
    
    func incrementalAuthWorkflow(
        initialAmount: Int,
        incrementalSubtotal: Int,
        taxRate: Double,
        tipAmount: Int,
        tipType: PaymentBreakdown.TipType,
        finalAmount: Int
    ) async throws -> TransactionResponse
    
    func sendReceipts(
        transactionId: String,
        email: String?,
        phoneNumber: String?
    ) async throws -> SendReceiptsResponse
    
    func refund(
        transactionID: String,
        amount: Int?,
        eventId: String?
    ) async throws -> TransactionResponse
    
    func logout()
}
