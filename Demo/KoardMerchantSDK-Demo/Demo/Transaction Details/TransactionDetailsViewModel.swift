import Foundation
import KoardSDK

@MainActor
@Observable
public final class TransactionDetailsViewModel: Identifiable {
    public enum ReceiptContent {
        case selection
        case email
        case phoneNumber
        case sending
        case sentSuccessfully
        case sentError
    }

    public enum OperationKind: Hashable {
        case refund(useTap: Bool)
        case reverse
        case capture

        var title: String {
            switch self {
            case .refund(let useTap):
                return useTap ? "Tap Refund" : "Refund"
            case .reverse:
                return "Reverse"
            case .capture:
                return "Capture"
            }
        }

        var progressMessage: String {
            switch self {
            case .refund(let useTap):
                return useTap ? "Processing tap refund…" : "Processing refund…"
            case .reverse:
                return "Reversing transaction…"
            case .capture:
                return "Capturing transaction…"
            }
        }
    }

    public struct OperationPresentation: Identifiable {
        public enum Phase {
            case processing
            case success(TransactionResponse)
            case failure(String)
        }

        public let id: UUID
        public let kind: OperationKind
        public let amount: Int
        public let currency: CurrencyCode
        public var phase: Phase

        init(
            id: UUID = UUID(),
            kind: OperationKind,
            amount: Int,
            currency: CurrencyCode,
            phase: Phase
        ) {
            self.id = id
            self.kind = kind
            self.amount = amount
            self.currency = currency
            self.phase = phase
        }
    }

    public private(set) var transaction: KoardTransaction
    public var receiptContent: ReceiptContent = .selection
    public var isLoading: Bool = false
    public private(set) var responseMessage: String = ""
    public var operationPresentation: OperationPresentation?

    @ObservationIgnored public let id: UUID = UUID()
    @ObservationIgnored public var delegate: Delegate
    @ObservationIgnored private let koardMerchantService: KoardMerchantServiceable

    public struct Delegate {
        public var onTransactionUpdate: () -> Void

        public init(
            onTransactionUpdate: @escaping () -> Void
        ) {
            self.onTransactionUpdate = onTransactionUpdate
        }
    }

    init(
        koardMerchantService: KoardMerchantServiceable,
        transaction: KoardTransaction,
        delegate: Delegate
    ) {
        self.koardMerchantService = koardMerchantService
        self.transaction = transaction
        self.delegate = delegate
    }

    public func sendReceipt(email: String? = nil, phoneNumber: String? = nil) {
        isLoading = true
        receiptContent = .sending

        Task {
            do {
                let _ = try await koardMerchantService.sendReceipts(
                    transactionId: transaction.transactionId,
                    email: email,
                    phoneNumber: phoneNumber
                )

                await MainActor.run {
                    isLoading = false
                    responseMessage = "Sent"
                    receiptContent = .sentSuccessfully

                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.receiptContent = .selection
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false

                    if let sdkError = error as? KoardMerchantSDKError {
                        switch sdkError {
                        case let .server(message):
                            responseMessage = message ?? "Receipt sending failed"
                        case .unauthorized:
                            responseMessage = "Not authorized to send receipts"
                        case let .invalidParameters(message):
                            responseMessage = "Invalid parameters: \(message)"
                        case .blockedAccount:
                            responseMessage = "Merchant account is blocked"
                        default:
                            responseMessage = sdkError.errorDescription
                        }
                    } else {
                        responseMessage = error.localizedDescription
                    }

                    receiptContent = .sentError

                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.receiptContent = .selection
                    }
                }
                print("Failed to send receipt: \(error)")
            }
        }
    }

    public func performOperation(kind: OperationKind, amount: Int) {
        let currency = CurrencyCode(currencyCode: transaction.currency, displayName: nil)
        let identifier = UUID()
        operationPresentation = OperationPresentation(
            id: identifier,
            kind: kind,
            amount: amount,
            currency: currency,
            phase: .processing
        )

        Task {
            do {
                let response = try await executeOperation(kind: kind, amount: amount)
                await MainActor.run {
                    operationPresentation = OperationPresentation(
                        id: identifier,
                        kind: kind,
                        amount: amount,
                        currency: currency,
                        phase: .success(response)
                    )

                    if let updatedTransaction = response.transaction {
                        transaction = updatedTransaction
                    }

                    delegate.onTransactionUpdate()
                }
            } catch {
                await MainActor.run {
                    operationPresentation = OperationPresentation(
                        id: identifier,
                        kind: kind,
                        amount: amount,
                        currency: currency,
                        phase: .failure(error.localizedDescription)
                    )
                }
            }
        }
    }

    public func dismissOperation() {
        operationPresentation = nil
    }

    private func executeOperation(kind: OperationKind, amount: Int) async throws -> TransactionResponse {
        switch kind {
        case .refund(let useTap):
            return try await koardMerchantService.refund(
                transactionID: transaction.transactionId,
                amount: amount,
                eventId: UUID().uuidString,
                withTap: useTap
            )

        case .reverse:
            return try await koardMerchantService.reverse(
                transactionId: transaction.transactionId,
                amount: amount
            )

        case .capture:
            let tipType = transaction.tipType ?? .fixed
            return try await koardMerchantService.captureTransaction(
                transactionId: transaction.transactionId,
                subtotal: transaction.subtotal,
                taxRate: Double(transaction.taxRate) / 100.0,
                tipAmount: transaction.tipAmount,
                tipType: tipType,
                finalAmount: amount
            )
        }
    }
}

extension TransactionDetailsViewModel: Hashable {
    public nonisolated static func == (lhs: TransactionDetailsViewModel, rhs: TransactionDetailsViewModel) -> Bool {
        lhs.id == rhs.id
    }

    public nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
