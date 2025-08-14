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

    public enum RefundState {
        case confirmation
        case processing
        case success
        case failure
    }

    public private(set) var transaction: KoardTransaction
    public var receiptContent: ReceiptContent = .selection
    public var refundState: RefundState = .confirmation
    public var isLoading: Bool = false
    public private(set) var responseMessage: String = ""
    public private(set) var resultMessage: String = ""

    @ObservationIgnored public let id: UUID = UUID()
    @ObservationIgnored public var delegate: Delegate
    @ObservationIgnored private let koardMerchantService: KoardMerchantServiceable

    public struct Delegate {
        public var onRefundSuccess: () -> Void

        public init(
            onRefundSuccess: @escaping () -> Void
        ) {
            self.onRefundSuccess = onRefundSuccess
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

    public func performRefund() async {
        refundState = .processing

        do {
            let response = try await koardMerchantService.refund(
                transactionID: transaction.transactionId,
                amount: transaction.totalAmount,
                eventId: nil
            )

            await MainActor.run {
                if let refundTransaction = response.transaction {
                    switch refundTransaction.status {
                    case .refunded, .captured, .authorized:
                        resultMessage = "The refund has been processed successfully."
                        refundState = .success
                        delegate.onRefundSuccess()

                    case .declined:
                        resultMessage = "The refund was declined."
                        refundState = .failure

                    case .error, .canceled:
                        resultMessage = "The refund could not be processed."
                        refundState = .failure

                    default:
                        resultMessage = "Unknown refund status: \(refundTransaction.status)"
                        refundState = .failure
                    }
                } else {
                    resultMessage = "No transaction data received from refund."
                    refundState = .failure
                }
            }
        } catch {
            await MainActor.run {
                resultMessage = error.localizedDescription
                refundState = .failure
            }
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
