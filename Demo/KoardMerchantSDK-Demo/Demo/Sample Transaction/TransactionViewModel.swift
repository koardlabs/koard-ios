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

    public struct TransactionSummary: Identifiable {
        public let id = UUID()
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
        public let baseAmountCents: Int
        public let originalSurchargeCents: Int
    }

    public struct PendingSurchargeSummary {
        public let baseCents: Int
        public let surchargeCents: Int
        public let totalCents: Int
        public let isOverride: Bool
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
    public func clearTransactionSummary() {
        transactionSummary = nil
    }
    public var surchargePrompt: SurchargePrompt? {
        didSet {
            if let prompt = surchargePrompt {
                configurePendingSurchargeOverride(from: prompt)
            } else {
                resetPendingSurchargeOverride()
            }
        }
    }
    public var transactionAmount: String = "" {
        didSet {
            calculateTotal()
        }
    }

    public var taxTypeSelection: PaymentBreakdown.TipType = .percentage {
        didSet {
            switch taxTypeSelection {
            case .fixed:
                taxRate = ""
            case .percentage:
                taxAmount = ""
            }
            calculateTotal()
        }
    }

    public var taxRate: String = "" {
        didSet {
            calculateTotal()
        }
    }

    public var taxAmount: String = "" {
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

    // MARK: - Pending surcharge override state
    public var isPendingSurchargeOverrideOn: Bool = false

    public var pendingSurchargeTypeSelection: PaymentBreakdown.TipType = .fixed {
        didSet {
            switch pendingSurchargeTypeSelection {
            case .fixed:
                pendingSurchargePercentage = ""
            case .percentage:
                pendingSurchargeAmount = ""
            }
        }
    }

    public var pendingSurchargeAmount: String = ""

    public var pendingSurchargePercentage: String = ""

    public var canConfirmPendingSurcharge: Bool {
        guard surchargePrompt != nil else { return false }
        if !isPendingSurchargeOverrideOn {
            return true
        }
        return pendingOverrideComputation() != nil
    }

    // MARK: - Location Selection
    public private(set) var selectedLocation: Location?
    public var showLocationSelection: Bool = false

    public var selectedLocationName: String {
        selectedLocation?.name ?? "Select Location"
    }

    public var locationSelectionViewModel: LocationSelectionViewModel {
        LocationSelectionViewModel(
            koardMerchantService: koardMerchantService,
            delegate: .init(
                onLocationSelected: { [weak self] location in
                    self?.onLocationSelected(location)
                }
            )
        )
    }

    @ObservationIgnored public let id: UUID = UUID()
    @ObservationIgnored private let koardMerchantService: KoardMerchantServiceable

    init(koardMerchantService: KoardMerchantServiceable) {
        self.koardMerchantService = koardMerchantService
        self.selectedLocation = koardMerchantService.activeLocation
    }

    public func loadActiveLocation() async {
        if let refreshed = await koardMerchantService.loadActiveLocation() {
            selectedLocation = refreshed
        }
    }

    public func onLocationSelected(_ location: Location) {
        selectedLocation = location
        koardMerchantService.updateLocation(location: location)
        showLocationSelection = false
    }

    public func preauthorize() async {
        isProcessingSale = true
        transactionState = .none
        transactionSummary = nil
        transactionId = ""

        defer {
            isProcessingSale = false
        }

        do {
            let subtotalCents = Int((Double(transactionAmount) ?? 0.0) * 100)
            let taxRateValue = isBreakoutOn ? (Double(taxRate) ?? 0.0) : 0.0
            let (tipAmountCents, taxAmountCents) = calculateTipAndTaxAmounts(
                subtotalCents: subtotalCents,
                taxRatePercent: taxRateValue
            )
            let tipRateValue = selectedTipRate()

            let (surcharge, surchargeAmountCents) = surchargeDetails(
                subtotalCents: subtotalCents,
                taxAmountCents: taxAmountCents,
                tipAmountCents: tipAmountCents
            )

            let totalAmountCents = subtotalCents + taxAmountCents + tipAmountCents + surchargeAmountCents

            let breakdownToSend: PaymentBreakdown? = {
                let hasTax = taxAmountCents > 0
                let hasTip = tipAmountCents > 0
                let hasSurcharge = surcharge != nil

                guard hasTax || hasTip || hasSurcharge else { return nil }

                // Only send the relevant tip field based on type
                let breakdownTipAmount: Int? = tipRateValue == nil ? tipAmountCents : nil

                // Only send taxRate if using percentage mode
                let breakdownTaxRate: Double? = taxTypeSelection == .percentage ? taxRateValue : nil

                return PaymentBreakdown(
                    subtotal: subtotalCents,
                    taxRate: breakdownTaxRate,
                    taxAmount: taxAmountCents,
                    tipAmount: breakdownTipAmount,
                    tipRate: tipRateValue,
                    tipType: tipTypeSelection,
                    surcharge: surcharge
                )
            }()

            if let breakdownToSend {
                print("""
                [Demo] Preauth Payload ->
                Amount: \(totalAmountCents)
                Breakdown:
                  subtotal: \(breakdownToSend.subtotal)
                  taxRate: \(String(describing: breakdownToSend.taxRate))
                  taxAmount: \(breakdownToSend.taxAmount)
                  tipAmount: \(String(describing: breakdownToSend.tipAmount))
                  tipRate: \(String(describing: breakdownToSend.tipRate))
                  tipType: \(breakdownToSend.tipType.rawValue)
                  surcharge: \(String(describing: breakdownToSend.surcharge))
                """)
            } else {
                print("[Demo] Preauth Payload -> Amount: \(totalAmountCents) (no breakdown provided)")
            }

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
            case .surchargePending:
                let surchargeRate = transaction.surchargeRate ?? 0
                let disclosure = transaction.surchargeDisclosure ?? {
                    if surchargeRate > 0 {
                        return "A \(String(format: "%.2f", surchargeRate))% surcharge is applied to cover processing fees."
                    }
                    return "This transaction is pending merchant confirmation."
                }()
                transactionState = .surcharge(disclosure)
                let originalSurchargeCents = transaction.surchargeAmount ?? 0
                let baseAmountCents = max(0, transaction.totalAmount - originalSurchargeCents)
                surchargePrompt = SurchargePrompt(
                    flow: .auth,
                    transaction: transaction,
                    disclosure: disclosure,
                    baseAmountCents: baseAmountCents,
                    originalSurchargeCents: originalSurchargeCents
                )
                lastTransactionDisplay = makeDisplay(from: response, title: "Auth Response (Pending Confirmation)")
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
            presentSummary(from: transaction, title: "Auth")

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
        transactionId = ""

        defer {
            isProcessingSale = false
        }

        do {
            // Use the calculated total amount instead of just the entered amount
            let subtotalCents = Int((Double(transactionAmount) ?? 0.0) * 100)
            let taxRateValue = isBreakoutOn ? (Double(taxRate) ?? 0.0) : 0.0
            let (tipAmountCents, taxAmountCents) = calculateTipAndTaxAmounts(
                subtotalCents: subtotalCents,
                taxRatePercent: taxRateValue
            )
            let tipRateValue = selectedTipRate()
            let (surcharge, _) = surchargeDetails(
                subtotalCents: subtotalCents,
                taxAmountCents: taxAmountCents,
                tipAmountCents: tipAmountCents
            )

            // Only send taxRate when using percentage mode
            let taxRateToSend: Double? = (taxTypeSelection == .percentage && taxRateValue > 0) ? taxRateValue : nil

            let transaction = try await koardMerchantService.processSale(
                subtotal: subtotalCents,
                taxAmount: taxAmountCents,
                taxRate: taxRateToSend,
                tipAmount: tipAmountCents,
                tipRate: tipRateValue,
                tipType: tipTypeSelection,
                surcharge: surcharge
            )

            var finalTransaction = transaction

            switch transaction.status {
            case .captured:
                print("Payment captured: \(transaction.transactionId)")
                transactionState = .authorized
            case .surchargePending:
                let surchargeRate = transaction.surchargeRate ?? 0
                let disclosure = transaction.surchargeDisclosure ?? {
                    if surchargeRate > 0 {
                        return "A \(String(format: "%.2f", surchargeRate))% surcharge is applied to cover processing fees."
                    }
                    return "This transaction is pending merchant confirmation."
                }()
                transactionState = .surcharge(disclosure)
                let originalSurchargeCents = transaction.surchargeAmount ?? 0
                let baseAmountCents = max(0, transaction.totalAmount - originalSurchargeCents)
                surchargePrompt = SurchargePrompt(
                    flow: .sale,
                    transaction: transaction,
                    disclosure: disclosure,
                    baseAmountCents: baseAmountCents,
                    originalSurchargeCents: originalSurchargeCents
                )
                lastTransactionDisplay = makeDisplay(from: transaction, title: "Sale Response (Pending Confirmation)")
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
            presentSummary(from: finalTransaction, title: "Sale")

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
            let overridePayload = confirm ? pendingOverrideComputation() : nil
            let breakdownOverride = overridePayload.map { payload in
                breakdown(
                    for: prompt.transaction,
                    surcharge: payload.surcharge
                )
            }
            let amountOverride = overridePayload?.totalCents

            let updatedTransaction = try await koardMerchantService.transactionConfirmed(
                transactionId: prompt.transaction.transactionId,
                confirm: confirm,
                amount: amountOverride,
                breakdown: breakdownOverride,
                eventId: nil
            )

            let responseTitle = "\(prompt.flow.title) Response"
            lastTransactionDisplay = makeDisplay(
                from: updatedTransaction,
                title: responseTitle,
                override: overridePayload
            )
            presentSummary(
                from: updatedTransaction,
                title: prompt.flow.title,
                override: overridePayload
            )

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

    private func makeDisplay(
        from transaction: KoardTransaction,
        title: String,
        override: PendingOverrideComputation? = nil
    ) -> TransactionDetailDisplay {
        var entries = makeEntries(from: transaction)
        entries.append(
            TransactionDetailDisplay.Entry(
                key: "createdAtLocalString",
                value: transaction.createdAtLocalString
            )
        )

        if let override {
            let currencyCode = CurrencyCode(currencyCode: transaction.currency, displayName: nil)
            let overrideSurcharge = MoneyUtils.centsToStringWithCurrency(override.surchargeCents, currency: currencyCode)
            let overrideTotal = MoneyUtils.centsToStringWithCurrency(override.totalCents, currency: currencyCode)
            entries.append(
                TransactionDetailDisplay.Entry(
                    key: "override.surcharge",
                    value: overrideSurcharge
                )
            )
            entries.append(
                TransactionDetailDisplay.Entry(
                    key: "override.total",
                    value: overrideTotal
                )
            )
        }

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
    }

    private func presentSummary(
        from transaction: KoardTransaction,
        title: String,
        override: PendingOverrideComputation? = nil
    ) {
        transactionSummary = makeSummary(from: transaction, title: title, override: override)
        DemoTapTransactionLogger.logSummaryPresented(title: title, transactionId: transaction.transactionId)
    }
}

extension TransactionViewModel {
    private func makeSummary(
        from transaction: KoardTransaction,
        title: String,
        override: PendingOverrideComputation? = nil
    ) -> TransactionSummary {
        let currencyCode = CurrencyCode(currencyCode: transaction.currency, displayName: nil)
        let subtotal = MoneyUtils.centsToStringWithCurrency(transaction.subtotal, currency: currencyCode)
        let tax = MoneyUtils.centsToStringWithCurrency(transaction.taxAmount, currency: currencyCode)
        let tip = MoneyUtils.centsToStringWithCurrency(transaction.tipAmount, currency: currencyCode)
        let surchargeAmountCents = override?.surchargeCents ?? transaction.surchargeAmount ?? 0
        let surcharge = surchargeAmountCents > 0
            ? MoneyUtils.centsToStringWithCurrency(surchargeAmountCents, currency: currencyCode)
            : nil
        let totalCents = override?.totalCents ?? transaction.totalAmount
        let total = MoneyUtils.centsToStringWithCurrency(totalCents, currency: currencyCode)

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

    private func selectedTipRate() -> Double? {
        guard isBreakoutOn, tipTypeSelection == .percentage else { return nil }
        let percentageValue = Double(tipPercentage) ?? 0.0
        return percentageValue > 0 ? percentageValue : nil
    }

    private func calculateTipAndTaxAmounts(
        subtotalCents: Int,
        taxRatePercent: Double
    ) -> (tipAmountCents: Int, taxAmountCents: Int) {
        let subtotalDouble = Double(subtotalCents)

        guard isBreakoutOn else {
            let taxCents: Int = {
                switch taxTypeSelection {
                case .fixed:
                    return Int(((Double(taxAmount) ?? 0.0) * 100.0).rounded())
                case .percentage:
                    let taxRateDecimal = taxRatePercent / 100.0
                    return Int((subtotalDouble * taxRateDecimal).rounded())
                }
            }()
            return (0, taxCents)
        }

        let tipCents: Int = {
            switch tipTypeSelection {
            case .fixed:
                return Int(((Double(tipAmount) ?? 0.0) * 100.0).rounded())
            case .percentage:
                let tipRatePercent = Double(tipPercentage) ?? 0.0
                guard tipRatePercent > 0 else { return 0 }
                let tipRateDecimal = tipRatePercent / 100.0
                return Int((subtotalDouble * tipRateDecimal).rounded())
            }
        }()

        let taxCents: Int = {
            switch taxTypeSelection {
            case .fixed:
                return Int(((Double(taxAmount) ?? 0.0) * 100.0).rounded())
            case .percentage:
                let taxRateDecimal = taxRatePercent / 100.0
                let taxBase = subtotalDouble + Double(max(0, tipCents))
                return Int((taxBase * taxRateDecimal).rounded())
            }
        }()

        return (max(0, tipCents), max(0, taxCents))
    }

    private func surchargeDetails(
        subtotalCents: Int,
        taxAmountCents: Int,
        tipAmountCents: Int
    ) -> (surcharge: PaymentBreakdown.Surcharge?, amountCents: Int) {
        if isSurchargeBypassed {
            return (
                PaymentBreakdown.Surcharge(amount: nil, percentage: nil, bypass: true),
                0
            )
        }

        guard isSurchargeOverrideOn else {
            return (nil, 0)
        }

        switch surchargeTypeSelection {
        case .fixed:
            let cents = MoneyUtils.stringToCents(surchargeAmount)
            guard cents > 0 else { return (nil, 0) }
            return (
                PaymentBreakdown.Surcharge(amount: cents, percentage: nil, bypass: false),
                cents
            )
        case .percentage:
            let percentageValue = Double(surchargePercentage) ?? 0.0
            guard percentageValue > 0 else { return (nil, 0) }
            let base = subtotalCents + taxAmountCents + tipAmountCents
            let cents = Int((Double(base) * percentageValue / 100.0).rounded())
            return (
                PaymentBreakdown.Surcharge(amount: nil, percentage: percentageValue, bypass: false),
                cents
            )
        }
    }

    private func calculateTotal() {
        clearTransactionOutputsIfNeeded()

        let subtotalValue = Double(transactionAmount) ?? 0
        let subtotalCents = Int((subtotalValue * 100.0).rounded())
        let taxRateValue = Double(taxRate) ?? 0.0
        let (tipAmountCents, taxAmountCents) = calculateTipAndTaxAmounts(
            subtotalCents: subtotalCents,
            taxRatePercent: taxRateValue
        )

        var totalCents = isBreakoutOn ? subtotalCents + tipAmountCents + taxAmountCents : subtotalCents

        if isSurchargeOverrideOn, !isSurchargeBypassed {
            switch surchargeTypeSelection {
            case .fixed:
                let surchargeCents = Int(((Double(surchargeAmount) ?? 0.0) * 100.0).rounded())
                totalCents += max(0, surchargeCents)
            case .percentage:
                let surchargeRate = Double(surchargePercentage) ?? 0.0
                guard surchargeRate > 0 else {
                    totalAmountValue = Double(totalCents) / 100.0
                    totalAmount = formatCurrency(amount: totalAmountValue)
                    return
                }
                let surchargeCents = Int((Double(totalCents) * surchargeRate / 100.0).rounded())
                totalCents += max(0, surchargeCents)
            }
        }

        totalAmountValue = Double(totalCents) / 100.0
        totalAmount = formatCurrency(amount: totalAmountValue)
    }

    public func pendingSurchargeSummary() -> PendingSurchargeSummary? {
        guard let prompt = surchargePrompt else { return nil }
        if let override = pendingOverrideComputation() {
            return PendingSurchargeSummary(
                baseCents: override.baseCents,
                surchargeCents: override.surchargeCents,
                totalCents: override.totalCents,
                isOverride: true
            )
        }

        let base = max(0, prompt.baseAmountCents)
        let surcharge = max(0, prompt.originalSurchargeCents)
        return PendingSurchargeSummary(
            baseCents: base,
            surchargeCents: surcharge,
            totalCents: base + surcharge,
            isOverride: false
        )
    }

    private func configurePendingSurchargeOverride(from prompt: SurchargePrompt) {
        isPendingSurchargeOverrideOn = false
        pendingSurchargeTypeSelection = prompt.originalSurchargeCents > 0 ? .fixed : .percentage
        if prompt.originalSurchargeCents > 0 {
            pendingSurchargeAmount = MoneyUtils.centsToString(prompt.originalSurchargeCents)
        } else {
            pendingSurchargeAmount = ""
        }

        if let rate = prompt.transaction.surchargeRate, rate > 0 {
            pendingSurchargePercentage = String(format: "%.2f", rate)
        } else {
            pendingSurchargePercentage = ""
        }
    }

    private func resetPendingSurchargeOverride() {
        isPendingSurchargeOverrideOn = false
        pendingSurchargeAmount = ""
        pendingSurchargePercentage = ""
        pendingSurchargeTypeSelection = .fixed
    }

    private struct PendingOverrideComputation {
        let baseCents: Int
        let surchargeCents: Int
        let totalCents: Int
        let surcharge: PaymentBreakdown.Surcharge
    }

    private func pendingOverrideComputation() -> PendingOverrideComputation? {
        guard isPendingSurchargeOverrideOn, let prompt = surchargePrompt else { return nil }
        let base = max(0, prompt.baseAmountCents)

        switch pendingSurchargeTypeSelection {
        case .fixed:
            let cents = MoneyUtils.stringToCents(pendingSurchargeAmount)
            guard cents > 0 else { return nil }
            let total = base + cents
            return PendingOverrideComputation(
                baseCents: base,
                surchargeCents: cents,
                totalCents: total,
                surcharge: PaymentBreakdown.Surcharge(amount: cents, percentage: nil, bypass: false)
            )
        case .percentage:
            let rate = Double(pendingSurchargePercentage) ?? 0
            guard rate > 0 else { return nil }
            let surchargeValue = Int((Double(base) * rate / 100.0).rounded())
            let total = base + surchargeValue
            return PendingOverrideComputation(
                baseCents: base,
                surchargeCents: surchargeValue,
                totalCents: total,
                surcharge: PaymentBreakdown.Surcharge(amount: nil, percentage: rate, bypass: false)
            )
        }
    }

    private func breakdown(
        for transaction: KoardTransaction,
        surcharge: PaymentBreakdown.Surcharge
    ) -> PaymentBreakdown {
        PaymentBreakdown(
            subtotal: transaction.subtotal,
            taxRate: transaction.taxRate > 0 ? Double(transaction.taxRate) / 100.0 : nil,
            taxAmount: transaction.taxAmount,
            tipAmount: transaction.tipAmount,
            tipRate: nil,
            tipType: transaction.tipType ?? .fixed,
            surcharge: surcharge
        )
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
