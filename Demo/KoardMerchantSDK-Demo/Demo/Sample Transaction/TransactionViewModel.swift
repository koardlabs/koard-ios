import Foundation
import KoardSDK
import SwiftUI

@MainActor
@Observable
public final class TransactionViewModel: Identifiable {
    public enum TransactionState {
        case none
        case authorized
        case surcharge(String)
        case error

        var detailString: String {
            switch self {
            case .none:
                ""
            case .authorized:
                "Transaction authorized."
            case let .surcharge(disclosure):
                disclosure
            case .error:
                "Transaction failed or declined."
            }
        }

        var detailColor: Color {
            switch self {
            case .none:
                .primary
            case .authorized:
                .koardGreen
            case .surcharge:
                .red
            case .error:
                .red
            }
        }
    }

    public private(set) var tipTypes: [PaymentBreakdown.TipType] = [.fixed, .percentage]
    public private(set) var isProcessingSale: Bool = false
    public var isBreakoutOn = false
    public var tipTypeSelection: PaymentBreakdown.TipType = .fixed
    public private(set) var totalAmount: String = ""
    public private(set) var totalAmountValue: Double = 0
    public private(set) var transactionId: String = ""
    public private(set) var transactionState: TransactionState = .authorized
    public var transactionAmount: String = "" {
        didSet {
            calculateTotal()
        }
    }

    public var taxRate: String = "" {
        didSet {
            calculateTotal()
        }
    }

    public var tipAmount: String = "" {
        didSet {
            calculateTotal()
        }
    }

    public var tipPercentage: String = "" {
        didSet {
            calculateTotal()
        }
    }

    @ObservationIgnored public let id: UUID = UUID()
    @ObservationIgnored private let koardMerchantService: KoardMerchantServiceable

    init(koardMerchantService: KoardMerchantServiceable) {
        self.koardMerchantService = koardMerchantService
    }

    public func preauthorize() async {
        isProcessingSale = true

        defer {
            isProcessingSale = false
        }

        do {
            // Calculate amount using same logic as payment service to avoid rounding discrepancies
            let subtotalCents = Int((Double(transactionAmount) ?? 0.0) * 100)
            let taxRateValue = Double(taxRate) ?? 0.0
            let tipAmountCents = Int((Double(tipAmount) ?? 0.0) * 100)
            let taxAmountCents = Int((Double(subtotalCents) * taxRateValue / 100.0).rounded())
            let totalAmountCents = subtotalCents + taxAmountCents + (isBreakoutOn ? tipAmountCents : 0)
            
            let response = try await koardMerchantService.preauthorize(
                amount: totalAmountCents,
                currency: CurrencyCode(currencyCode: "USD", displayName: nil)
            )

            guard let transaction = response.transaction else {
                let missingDataError = NSError(domain: "PaymentError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Transaction details missing"])
                throw missingDataError
            }

            switch transaction.status {
            case .surchargePending:
                // Legacy surcharge pending status - show confirmation dialog
                print("Surcharge disclosure: \(transaction.surchargeDisclosure ?? "None")")
                let surchargeRate = transaction.surchargeRate ?? 0
                let customDisclosure = transaction.surchargeDisclosure ??
                    "A \(String(format: "%.2f", surchargeRate))% surcharge is applied to cover processing fees."
                transactionState = .surcharge(customDisclosure)
            case .authorized:
                transactionState = .authorized
            case .captured:
                transactionState = .authorized
            case .declined:
                transactionState = .error
                let declineError = NSError(
                    domain: "PaymentError",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey:
                        transaction.processorResponseMessage ?? "Transaction declined"]
                )

                throw declineError

            case .canceled, .error, .timedOut:
                transactionState = .error
                let failureError = NSError(
                    domain: "PaymentError",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: transaction.processorResponseMessage ?? "Transaction failed"]
                )
                throw failureError

            default:
                transactionState = .error
                let unknownError = NSError(
                    domain: "PaymentError",
                    code: 3,
                    userInfo: [NSLocalizedDescriptionKey: transaction.processorResponseMessage ?? "Unknown transaction status"]
                )
                throw unknownError
            }

        } catch let sdkError as KoardMerchantSDKError {
            print("SDK Error: \(sdkError)")
            if case .TTPPaymentFailed(let ttpError) = sdkError {
                print("TTP Payment Error: \(ttpError)")
                if case .paymentCardReaderError(let underlyingError) = ttpError {
                    print("Underlying Error: \(underlyingError)")
                }
            }
        } catch let error as KoardDescribableError {
            print("Payment Error: \(error.errorDescription)")
        } catch {
            print("Unexpected Error: \(error.localizedDescription)")
        }
    }

    public func processTransaction() async {
        isProcessingSale = true

        defer {
            isProcessingSale = false
        }

        do {
            // Use the calculated total amount instead of just the entered amount
            let transaction = try await koardMerchantService.processSale(
                subtotal: Int((Double(transactionAmount) ?? 0.0) * 100),
                taxRate: isBreakoutOn ? (Double(taxRate) ?? 0.0) : 0.0,
                tipAmount: isBreakoutOn ? Int((Double(tipAmount) ?? 0.0) * 100) : 0,
                tipType: tipTypeSelection
            )

            switch transaction.status {
            case .captured:
                print("Payment captured: \(transaction.transactionId)")
                transactionId = transaction.transactionId
            case .surchargePending:
                // Handle surcharge confirmation
                let confirmed = try await koardMerchantService.transactionConfirmed(
                    transactionId: transaction.transactionId,
                    confirm: true
                )
                transactionId = transaction.transactionId
                print("Surcharge confirmed, final status: \(confirmed.status)")
            case .declined:
                print("Payment declined: \(transaction.statusReason ?? "Unknown reason")")
            default:
                print("Payment status: \(transaction.status)")
            }

        } catch let sdkError as KoardMerchantSDKError {
            print("SDK Error: \(sdkError)")
            if case .TTPPaymentFailed(let ttpError) = sdkError {
                print("TTP Payment Error: \(ttpError)")
                if case .paymentCardReaderError(let underlyingError) = ttpError {
                    print("Underlying Error: \(underlyingError)")
                }
            }
        } catch let error as KoardDescribableError {
            print("Payment Error: \(error.errorDescription)")
        } catch {
            print("Unexpected Error: \(error.localizedDescription)")
        }
    }
}

extension TransactionViewModel {
    private func calculateTotal() {
        let subtotal = Double(transactionAmount) ?? 0
        let taxRateValue = Double(taxRate) ?? 0.0
        let tipAmountValue = Double(tipAmount) ?? 0
        let tipPercentageValue = Double(tipPercentage) ?? 0.0

        if !isBreakoutOn {
            totalAmountValue = subtotal
            totalAmount = formatCurrency(amount: totalAmountValue)
            return
        }

        // Use same rounding logic as payment service for consistency
        let subtotalCents = Int(subtotal * 100)
        let taxAmountCents = Int((Double(subtotalCents) * taxRateValue / 100.0).rounded())
        let taxAmount = Double(taxAmountCents) / 100.0
        
        if tipTypeSelection == .fixed {
            totalAmountValue = subtotal + taxAmount + tipAmountValue
            totalAmount = formatCurrency(amount: totalAmountValue)
        } else {
            let tip = subtotal * (tipPercentageValue / 100.0)
            totalAmountValue = subtotal + taxAmount + tip
            totalAmount = formatCurrency(amount: totalAmountValue)
        }
    }

    private func formatCurrency(amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

extension TransactionViewModel: Hashable {
    public nonisolated static func == (lhs: TransactionViewModel, rhs: TransactionViewModel) -> Bool {
        lhs.id == rhs.id
    }

    public nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension PaymentBreakdown.TipType {
    var displayName: String {
        switch self {
        case .fixed:
            "$"
        case .percentage:
            "%"
        }
    }
}
