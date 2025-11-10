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

    public struct TransactionDetailDisplay: Identifiable {
        public struct Entry: Identifiable {
            public let id = UUID()
            public let key: String
            public let value: String
        }

        public let id = UUID()
        public let title: String
        public let entries: [Entry]
    }

    public struct TransactionSummary {
        public struct Breakdown {
            public let subtotal: String
            public let tax: String
            public let tip: String
            public let surcharge: String?
            public let total: String
        }

        public let title: String
        public let status: String
        public let statusReason: String?
        public let cardBrand: String?
        public let card: String?
        public let breakdown: Breakdown
    }

    public enum FlowType {
        case sale
        case auth

        var title: String {
            switch self {
            case .sale:
                return "Sale"
            case .auth:
                return "Auth"
            }
        }
    }

    public struct SurchargePrompt: Identifiable {
        public let id = UUID()
        public let flow: FlowType
        public let transaction: KoardTransaction
        public let disclosure: String
    }

    public private(set) var tipTypes: [PaymentBreakdown.TipType] = [.fixed, .percentage]
    public private(set) var isProcessingSale: Bool = false
    public var isBreakoutOn = true
    public var tipTypeSelection: PaymentBreakdown.TipType = .fixed
    public private(set) var totalAmount: String = ""
    public private(set) var totalAmountValue: Double = 0
    public private(set) var transactionId: String = ""
    public private(set) var transactionState: TransactionState = .none
    public private(set) var lastTransactionDisplay: TransactionDetailDisplay?
    public private(set) var transactionSummary: TransactionSummary?
    public var isSummaryPresented: Bool = false
    public var surchargePrompt: SurchargePrompt?
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

    public var isSurchargeOverrideOn: Bool = false {
        didSet {
            if isSurchargeOverrideOn && isSurchargeBypassed {
                isSurchargeBypassed = false
            }
            if !isSurchargeOverrideOn {
                surchargeAmount = ""
                surchargePercentage = ""
            }
            calculateTotal()
        }
    }

    public var isSurchargeBypassed: Bool = false {
        didSet {
            if isSurchargeBypassed && isSurchargeOverrideOn {
                isSurchargeOverrideOn = false
            }
            calculateTotal()
        }
    }

    public var surchargeTypeSelection: PaymentBreakdown.TipType = .fixed {
        didSet {
            switch surchargeTypeSelection {
            case .fixed:
                surchargePercentage = ""
            case .percentage:
                surchargeAmount = ""
            }
            calculateTotal()
        }
    }

    public var surchargeAmount: String = "" {
        didSet {
            calculateTotal()
        }
    }

    public var surchargePercentage: String = "" {
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
        transactionState = .none
        transactionSummary = nil
        isSummaryPresented = false
        transactionId = ""

        defer {
            isProcessingSale = false
        }

        do {
            let subtotalCents = Int((Double(transactionAmount) ?? 0.0) * 100)
            let taxRateValue = isBreakoutOn ? (Double(taxRate) ?? 0.0) : 0.0
            let taxAmountCents = Int((Double(subtotalCents) * taxRateValue / 100.0).rounded())

            let tipAmountCents: Int = {
                guard isBreakoutOn else { return 0 }
                switch tipTypeSelection {
                case .fixed:
                    return Int((Double(tipAmount) ?? 0.0) * 100)
                case .percentage:
                    let percentageValue = Double(tipPercentage) ?? 0.0
                    return Int((Double(subtotalCents) * percentageValue / 100.0).rounded())
                }
            }()

            let surcharge = makeSurcharge(subtotalCents: subtotalCents)
            let surchargeAmountCents: Int = {
                guard let surcharge, !surcharge.bypass else { return 0 }
                if let amount = surcharge.amount {
                    return amount
                }
                if let percentage = surcharge.percentage {
                    return Int((Double(subtotalCents) * percentage / 100.0).rounded())
                }
                return 0
            }()

            let totalAmountCents = subtotalCents + taxAmountCents + tipAmountCents + surchargeAmountCents

            let breakdownToSend: PaymentBreakdown? = {
                guard isBreakoutOn || surcharge != nil else { return nil }
                return PaymentBreakdown(
                    subtotal: subtotalCents,
                    taxRate: Int(taxRateValue * 100),
                    taxAmount: taxAmountCents,
                    tipAmount: tipAmountCents,
                    tipType: tipTypeSelection,
                    surcharge: surcharge
                )
            }()

            let response = try await koardMerchantService.preauthorize(
                amount: totalAmountCents,
                breakdown: breakdownToSend,
                currency: CurrencyCode(currencyCode: "USD", displayName: nil)
            )

            guard let transaction = response.transaction else {
                let missingDataError = NSError(domain: "PaymentError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Transaction details missing"])
                throw missingDataError
            }

            switch transaction.status {
            case .pending, .surchargePending:
                let surchargeRate = transaction.surchargeRate ?? 0
                let disclosure = transaction.surchargeDisclosure ?? {
                    if surchargeRate > 0 {
                        return "A \(String(format: "%.2f", surchargeRate))% surcharge is applied to cover processing fees."
                    }
                    return "This transaction is pending merchant confirmation."
                }()
                transactionState = .surcharge(disclosure)
                surchargePrompt = SurchargePrompt(
                    flow: .auth,
                    transaction: transaction,
                    disclosure: disclosure
                )
                lastTransactionDisplay = makeDisplay(from: response, title: "Auth Response (Pending Confirmation)")
                transactionSummary = nil
                isSummaryPresented = false
                transactionId = ""
                return
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

            lastTransactionDisplay = makeDisplay(from: response, title: "Auth Response")
            transactionSummary = makeSummary(from: transaction, title: "Auth")
            isSummaryPresented = true

        } catch let sdkError as KoardMerchantSDKError {
            print("SDK Error: \(sdkError)")
            if case .TTPPaymentFailed(let ttpError) = sdkError {
                print("TTP Payment Error: \(ttpError)")
                if case .paymentCardReaderError(let underlyingError) = ttpError {
                    print("Underlying Error: \(underlyingError)")
                }
            }
            recordError(title: "Auth", error: sdkError)
        } catch let error as KoardDescribableError {
            print("Payment Error: \(error.errorDescription)")
            recordError(title: "Auth", message: error.errorDescription, error: error)
        } catch {
            print("Unexpected Error: \(error.localizedDescription)")
            recordError(title: "Auth", error: error)
        }
    }

    public func processTransaction() async {
        isProcessingSale = true
        transactionState = .none
        transactionSummary = nil
        isSummaryPresented = false
        transactionId = ""

        defer {
            isProcessingSale = false
        }

        do {
            // Use the calculated total amount instead of just the entered amount
            let subtotalCents = Int((Double(transactionAmount) ?? 0.0) * 100)
            let transaction = try await koardMerchantService.processSale(
                subtotal: subtotalCents,
                taxRate: isBreakoutOn ? (Double(taxRate) ?? 0.0) : 0.0,
                tipAmount: isBreakoutOn ? Int((Double(tipAmount) ?? 0.0) * 100) : 0,
                tipType: tipTypeSelection,
                surcharge: makeSurcharge(subtotalCents: subtotalCents)
            )

            var finalTransaction = transaction

            switch transaction.status {
            case .captured:
                print("Payment captured: \(transaction.transactionId)")
                transactionState = .authorized
            case .pending, .surchargePending:
                let surchargeRate = transaction.surchargeRate ?? 0
                let disclosure = transaction.surchargeDisclosure ?? {
                    if surchargeRate > 0 {
                        return "A \(String(format: "%.2f", surchargeRate))% surcharge is applied to cover processing fees."
                    }
                    return "This transaction is pending merchant confirmation."
                }()
                transactionState = .surcharge(disclosure)
                surchargePrompt = SurchargePrompt(
                    flow: .sale,
                    transaction: transaction,
                    disclosure: disclosure
                )
                lastTransactionDisplay = makeDisplay(from: transaction, title: "Sale Response (Pending Confirmation)")
                transactionSummary = nil
                isSummaryPresented = false
                transactionId = ""
                return
            case .declined:
                print("Payment declined: \(transaction.statusReason ?? "Unknown reason")")
                transactionState = .error
            default:
                print("Payment status: \(transaction.status)")
                transactionState = .none
            }

            if finalTransaction.status == .captured || finalTransaction.status == .authorized {
                transactionId = finalTransaction.transactionId
            }

            lastTransactionDisplay = makeDisplay(from: finalTransaction, title: "Sale Response")
            transactionSummary = makeSummary(from: finalTransaction, title: "Sale")
            isSummaryPresented = true

        } catch let sdkError as KoardMerchantSDKError {
            print("SDK Error: \(sdkError)")
            if case .TTPPaymentFailed(let ttpError) = sdkError {
                print("TTP Payment Error: \(ttpError)")
                if case .paymentCardReaderError(let underlyingError) = ttpError {
                    print("Underlying Error: \(underlyingError)")
                }
            }
            recordError(title: "Sale", error: sdkError)
        } catch let error as KoardDescribableError {
            print("Payment Error: \(error.errorDescription)")
            recordError(title: "Sale", message: error.errorDescription, error: error)
        } catch {
            print("Unexpected Error: \(error.localizedDescription)")
            recordError(title: "Sale", error: error)
        }
    }

    public func handleSurchargeDecision(confirm: Bool) async {
        guard let prompt = surchargePrompt else { return }

        isProcessingSale = true

        defer {
            isProcessingSale = false
        }

        do {
            let updatedTransaction = try await koardMerchantService.transactionConfirmed(
                transactionId: prompt.transaction.transactionId,
                confirm: confirm,
                amount: nil,
                breakdown: nil,
                eventId: nil
            )

            let responseTitle = "\(prompt.flow.title) Response"
            lastTransactionDisplay = makeDisplay(from: updatedTransaction, title: responseTitle)
            transactionSummary = makeSummary(from: updatedTransaction, title: prompt.flow.title)
            isSummaryPresented = true

            if updatedTransaction.status == .authorized || updatedTransaction.status == .captured {
                transactionId = updatedTransaction.transactionId
                transactionState = .authorized
            } else if confirm {
                transactionId = ""
                transactionState = .error
            } else {
                transactionId = ""
                transactionState = .none
            }
        } catch let sdkError as KoardMerchantSDKError {
            recordError(title: prompt.flow.title, error: sdkError)
        } catch let error as KoardDescribableError {
            recordError(title: prompt.flow.title, message: error.errorDescription, error: error)
        } catch {
            recordError(title: prompt.flow.title, error: error)
        }

        surchargePrompt = nil
    }

    private func makeDisplay(from response: TransactionResponse, title: String) -> TransactionDetailDisplay {
        var entries = makeEntries(from: response)

        if let createdAtDate = response.createdAtDate {
            entries.append(
                TransactionDetailDisplay.Entry(
                    key: "createdAtDate",
                    value: DateFormatter.mediumDateFormatter.string(from: createdAtDate)
                )
            )
        }

        if let createdAtLocal = response.createdAtLocalString {
            entries.append(
                TransactionDetailDisplay.Entry(
                    key: "createdAtLocalString",
                    value: createdAtLocal
                )
            )
        }

        if let transaction = response.transaction {
            entries.append(contentsOf: makeEntries(from: transaction, prefix: "transaction"))
            entries.append(
                TransactionDetailDisplay.Entry(
                    key: "transaction.createdAtLocalString",
                    value: transaction.createdAtLocalString
                )
            )
        }

        return TransactionDetailDisplay(title: title, entries: entries)
    }

    private func makeDisplay(from transaction: KoardTransaction, title: String) -> TransactionDetailDisplay {
        var entries = makeEntries(from: transaction)
        entries.append(
            TransactionDetailDisplay.Entry(
                key: "createdAtLocalString",
                value: transaction.createdAtLocalString
            )
        )
        return TransactionDetailDisplay(title: title, entries: entries)
    }

    private func makeEntries<T>(from value: T, prefix: String? = nil) -> [TransactionDetailDisplay.Entry] {
        Mirror(reflecting: value).children.compactMap { child in
            guard let label = child.label else { return nil }
            let key = prefix.map { "\($0).\(label)" } ?? label
            let unwrapped = unwrap(child.value)
            return TransactionDetailDisplay.Entry(
                key: key,
                value: describe(unwrapped)
            )
        }
    }

    private func describe(_ value: Any?) -> String {
        guard let value else { return "nil" }

        if let date = value as? Date {
            return DateFormatter.mediumDateFormatter.string(from: date)
        }

        if let bool = value as? Bool {
            return bool ? "true" : "false"
        }

        return String(describing: value)
    }

    private func unwrap(_ value: Any) -> Any? {
        let mirror = Mirror(reflecting: value)
        guard mirror.displayStyle == .optional else {
            return value
        }
        guard let child = mirror.children.first else {
            return nil
        }
        return unwrap(child.value)
    }

    private func recordError(title: String, message: String? = nil, error: Error) {
        var entries: [TransactionDetailDisplay.Entry] = []

        if let message {
            entries.append(TransactionDetailDisplay.Entry(key: "message", value: message))
        }

        entries.append(
            TransactionDetailDisplay.Entry(
                key: "localizedDescription",
                value: error.localizedDescription
            )
        )
        entries.append(
            TransactionDetailDisplay.Entry(
                key: "debugDescription",
                value: String(describing: error)
            )
        )

        lastTransactionDisplay = TransactionDetailDisplay(
            title: "\(title) Error",
            entries: entries
        )
        transactionState = .error
        transactionSummary = nil
        isSummaryPresented = false
    }
}

extension TransactionViewModel {
    private func makeSummary(from transaction: KoardTransaction, title: String) -> TransactionSummary {
        let currencyCode = CurrencyCode(currencyCode: transaction.currency, displayName: nil)
        let subtotal = MoneyUtils.centsToStringWithCurrency(transaction.subtotal, currency: currencyCode)
        let tax = MoneyUtils.centsToStringWithCurrency(transaction.taxAmount, currency: currencyCode)
        let tip = MoneyUtils.centsToStringWithCurrency(transaction.tipAmount, currency: currencyCode)
        let surchargeAmountCents = transaction.surchargeAmount ?? 0
        let surcharge = surchargeAmountCents > 0
            ? MoneyUtils.centsToStringWithCurrency(surchargeAmountCents, currency: currencyCode)
            : nil
        let total = MoneyUtils.centsToStringWithCurrency(transaction.totalAmount, currency: currencyCode)

        return TransactionSummary(
            title: title,
            status: humanReadableStatus(transaction.status.rawValue),
            statusReason: transaction.statusReason,
            cardBrand: transaction.cardBrand,
            card: transaction.card,
            breakdown: .init(
                subtotal: subtotal,
                tax: tax,
                tip: tip,
                surcharge: surcharge,
                total: total
            )
        )
    }

    private func humanReadableStatus(_ status: String) -> String {
        status
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private func makeSurcharge(subtotalCents: Int) -> PaymentBreakdown.Surcharge? {
        if isSurchargeBypassed {
            return PaymentBreakdown.Surcharge(amount: nil, percentage: nil, bypass: true)
        }

        guard isSurchargeOverrideOn else {
            return nil
        }

        switch surchargeTypeSelection {
        case .fixed:
            let cents = Int((Double(surchargeAmount) ?? 0.0) * 100)
            guard cents > 0 else { return nil }
            return PaymentBreakdown.Surcharge(amount: cents, percentage: nil, bypass: false)
        case .percentage:
            let percentageValue = Double(surchargePercentage) ?? 0.0
            guard percentageValue > 0 else { return nil }
            return PaymentBreakdown.Surcharge(amount: nil, percentage: percentageValue, bypass: false)
        }
    }

    private func calculateTotal() {
        clearTransactionOutputsIfNeeded()

        let subtotal = Double(transactionAmount) ?? 0
        let taxRateValue = Double(taxRate) ?? 0.0
        let tipAmountValue = Double(tipAmount) ?? 0
        let tipPercentageValue = Double(tipPercentage) ?? 0.0
        let surchargeAmountValue = Double(surchargeAmount) ?? 0
        let surchargePercentageValue = Double(surchargePercentage) ?? 0.0

        let surchargeContribution: Double = {
            if isSurchargeBypassed {
                return 0
            }
            if isSurchargeOverrideOn {
                if surchargeTypeSelection == .fixed {
                    return surchargeAmountValue
                } else {
                    return subtotal * (surchargePercentageValue / 100.0)
                }
            }
            return 0
        }()

        if !isBreakoutOn {
            totalAmountValue = subtotal + surchargeContribution
            totalAmount = formatCurrency(amount: totalAmountValue)
            return
        }

        // Use same rounding logic as payment service for consistency
        let subtotalCents = Int(subtotal * 100)
        let taxAmountCents = Int((Double(subtotalCents) * taxRateValue / 100.0).rounded())
        let taxAmount = Double(taxAmountCents) / 100.0
        
        if tipTypeSelection == .fixed {
            totalAmountValue = subtotal + taxAmount + tipAmountValue + surchargeContribution
            totalAmount = formatCurrency(amount: totalAmountValue)
        } else {
            let tip = subtotal * (tipPercentageValue / 100.0)
            totalAmountValue = subtotal + taxAmount + tip + surchargeContribution
            totalAmount = formatCurrency(amount: totalAmountValue)
        }
    }

    private func formatCurrency(amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }

    private func clearTransactionOutputsIfNeeded() {
        guard !isProcessingSale else { return }

        let hasDisplay = lastTransactionDisplay != nil ||
            transactionSummary != nil ||
            isSummaryPresented ||
            {
                switch transactionState {
                case .none:
                    return false
                default:
                    return true
                }
            }()

        guard hasDisplay else { return }

        lastTransactionDisplay = nil
        transactionSummary = nil
        isSummaryPresented = false
        transactionState = .none
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
