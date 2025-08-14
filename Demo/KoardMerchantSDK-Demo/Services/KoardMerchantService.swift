import Combine
import Foundation
import KoardSDK
import UIKit
#if canImport(ProximityReader)
    import ProximityReader
#endif

public class KoardMerchantService: KoardMerchantServiceable {
    private let apiKey: String
    private var merchantCode: String?
    private var merchantPin: String?
    private var locations: [Location] = []
    private var cancellables: Set<AnyCancellable> = []

    public var isAuthenticated: Bool {
        KoardMerchantSDK.shared.isAuthenticated
    }

    public var activeLocation: Location? {
        guard let activeLocationID = KoardMerchantSDK.shared.getActiveLocationID() else {
            return nil
        }

        return locations.first { $0.id == activeLocationID }
    }

    public var isReaderSetupSupported: Bool {
        KoardMerchantSDK.shared.isAuthenticated &&
            KoardMerchantSDK.shared.isReaderSupported
    }

    init(apiKey: String, merchantCode: String? = nil, merchantPin: String? = nil) {
        self.apiKey = apiKey
        self.merchantCode = merchantCode
        self.merchantPin = merchantPin
    }

    /// Initializes any internal state or configuration required before SDK usage begins.
    public func setup() {
        let options = KoardOptions(
            environment: .uat, // .uat, .production, .custom("https://api.example.com")
            loggingLevel: .debug // .debug, .info, .warning, .error, .none
        )

        // Initialize with your API key
        KoardMerchantSDK.shared.initialize(
            options: options,
            apiKey: apiKey
        )
    }

    /// Performs merchant authentication using credentials stored or provided elsewhere.
    /// - Throws: An error if the operation fails
    public func authenticateMerchant() async throws {
        guard let merchantPin, let merchantCode else {
            throw MerchantError.missingCredentials
        }

        do {
            // Login with merchant credentials
            try await KoardMerchantSDK.shared.login(
                code: merchantCode,
                pin: merchantPin
            )

            print("Merchant authenticated successfully")

            // After login, set up location
            try await setupLocation()

        } catch {
            print("Authentication failed: \(error)")
            throw error
        }
    }

    public func fetchLocations() async throws -> [Location] {
        do {
            locations = try await KoardMerchantSDK.shared.locations()
            guard !locations.isEmpty else {
                throw MerchantError.noLocationsAvailable
            }
            return locations
        } catch {
            print("Location setup failed: \(error)")
            throw error
        }
    }

    /// Fetches and configures the merchant location context used for transactions.
    /// - Throws: An error if the operation fails
    public func setupLocation() async throws {
        do {
            locations = try await fetchLocations()

            // For single location merchants, use the first location
            let activeLocation = locations.first!

            // For multi-location merchants, let user select
            // let activeLocation = userSelectedLocation

            // Set the active location
            KoardMerchantSDK.shared.setActiveLocationID(activeLocation.id)

            print("Active location set: \(activeLocation.name)")

        } catch {
            print("Location setup failed: \(error)")
            throw error
        }
    }

    /// Initializes and prepares the card reader device for Tap to Pay transactions.
    /// - Throws: An error if the operation fails
    public func prepareCardReader() async throws {
        do {
            // Check if account is linked (required for Tap to Pay)
            let isLinked = try await KoardMerchantSDK.shared.isAccountLinked()

            if !isLinked {
                // Link the merchant account to Apple Pay
                try KoardMerchantSDK.shared.linkAccount()

                // Wait for linking to complete
                // This typically requires user interaction
                return
            }

            // Prepare the card reader session
            try await KoardMerchantSDK.shared.prepare()

            print("Card reader prepared and ready")

            // Optional: Monitor reader status
            monitorReaderStatus()

        } catch {
            print("Card reader preparation failed: \(error)")
            throw error
        }
    }

    /// Begins listening to card reader status changes and handles updates in real time.
    public func monitorReaderStatus() {
        KoardMerchantSDK.shared.readerEventsPublisher
            .sink { event in
                print("Reader event: \(event)")
            }
            .store(in: &cancellables)
    }

    /// Initiates a Tap to Pay sale transaction with the provided subtotal, tax rate, and tip.
    ///
    /// This method prepares and processes a contactless transaction using the Proximity Reader framework.
    /// It calculates the total amount by applying the specified tax rate and tip, then initiates the transaction flow.
    ///
    /// - Parameters:
    ///   - subtotal: The base transaction amount in cents (before tax or tip).
    ///   - taxRate: The tax rate to apply as a percentage (e.g., 8.25 for 8.25%).
    ///   - tipAmount: The tip amount in cents to apply to the transaction.
    ///   - tipType: The type of tip applied (e.g., `.fixed`, `.percentage`).
    /// - Returns: A `KoardTransaction` object containing the transaction details upon success.
    /// - Throws: An error if the transaction fails, is declined, or the reader is not ready.
    public func processSale(
        subtotal: Int,
        taxRate: Double,
        tipAmount: Int? = 0,
        tipType: PaymentBreakdown.TipType = .fixed
    ) async throws -> KoardTransaction {
        let taxAmount = Int((Double(subtotal) * taxRate / 100.0).rounded())

        // Create payment breakdown (optional)
        let breakdown = PaymentBreakdown(
            subtotal: subtotal,
            taxRate: Int(taxRate * 100),
            taxAmount: taxAmount,
            tipAmount: tipAmount ?? 0,
            tipType: tipType
        )

        // To ensure idempotency in sale requests, use the optional eventID parameter.
        // This unique identifier allows Koard to recognize repeat attempts of the same transaction and
        // return the original result instead of initiating a new charge.
        let eventId = UUID().uuidString

        // Create currency
        let currency = CurrencyCode(currencyCode: "USD", displayName: "US Dollar")
        let amount = subtotal + taxAmount + (tipAmount ?? 0)
        do {
            // Process the sale
            let response = try await KoardMerchantSDK.shared.sale(
                amount: amount, // Total amount in cents
                breakdown: breakdown, // Optional breakdown
                currency: currency,
                eventId: eventId, // (Optional) event ID for tracking
                type: .sale // Transaction type,
            )

            guard let transaction = response.transaction else {
                throw PaymentError.networkError
            }

            return transaction
        } catch {
            print("Sale failed: \(error)")
            throw error
        }
    }

    /// Retrieves a filtered list of transactions using advanced search criteria.
    ///
    /// This method fetches the transaction history, then applies filters such as date range,
    /// statuses, types, and amount bounds to return a refined result set.
    ///
    /// - Parameters:
    ///   - startDate: The beginning of the date range to search within.
    ///   - endDate: The end of the date range. Defaults to the current date/time.
    ///   - statuses: An array of transaction statuses to filter by (e.g., `.captured`, `.refunded`).
    ///   - types: An array of transaction types to include (e.g., `.sale`, `.refund`).
    ///   - minAmount: The minimum total transaction amount (in cents).
    ///   - maxAmount: The maximum total transaction amount (in cents).
    ///   - limit: The maximum number of results to return. Defaults to 50.
    /// - Returns: A list of transactions that match the given filters.
    /// - Throws: An error if the transaction history or filtered query fails.
    public func getTransactionHistory(
        startDate: Date,
        endDate: Date? = Date(),
        statuses: [KoardTransaction.Status],
        types: [PaymentType],
        minAmount: Int,
        maxAmount: Int,
        limit: Int? = 50
    ) async throws -> TransactionHistoryResponse {
        do {
            // Get recent transactions
            let history = try await KoardMerchantSDK.shared.transactionHistory()

            print("Found \(history.transactions.count) transactions")

            // Advanced filtering
            return try await KoardMerchantSDK.shared.searchTransactionsAdvanced(
                startDate: startDate,
                endDate: endDate,
                statuses: statuses.map { $0.rawValue.lowercased() },
                types: types.map { $0.rawValue.lowercased() },
                minAmount: minAmount,
                maxAmount: maxAmount,
                limit: limit ?? 50
            )
        } catch {
            print("Transaction history failed: \(error)")
            throw error
        }
    }

    /// Searches for transactions that match the given term across available metadata (e.g., card number, status, etc.).
    ///
    /// This function first fetches the full transaction history to ensure results are current,
    /// then filters transactions that contain the search term.
    ///
    /// - Parameter searchTerm: A string used to search transactions (e.g., last 4 of a card, transaction ID, etc.).
    /// - Returns: A list of transactions matching the search criteria.
    /// - Throws: An error if fetching the transaction history or performing the search fails.
    public func searchTransactions(searchTerm: String) async throws -> TransactionHistoryResponse {
        try await KoardMerchantSDK.shared.searchTransactions(searchTerm)
    }

    /// Retrieves transactions that match a specific status (e.g., approved, declined, refunded).
    ///
    /// This function first fetches the full transaction history to ensure results are up to date,
    /// then filters transactions by the provided status.
    ///
    /// - Parameter status: The status to filter transactions by (e.g., `.captured`, `.declined`).
    /// - Returns: A list of transactions that match the given status.
    /// - Throws: An error if the transaction history cannot be fetched or filtered.
    public func fetchTransactionsByStatus(status: KoardTransaction.Status) async throws -> TransactionHistoryResponse {
        try await KoardMerchantSDK.shared.transactionsByStatus(status.rawValue.lowercased())
    }

    /// Confirms or rejects a pending transaction based on a merchant decision.
    ///
    /// This method is used in workflows where a transaction requires explicit merchant confirmation
    /// (e.g., surcharges, delayed captures, or regulatory approvals).
    ///
    /// - Parameters:
    ///   - transactionId: The identifier of the transaction to confirm or reject.
    ///   - confirm: A Boolean value indicating whether to confirm (`true`) or reject (`false`) the transaction.
    /// - Returns: The updated `KoardTransaction` reflecting the confirmation result.
    /// - Throws: An error if the confirmation fails or the transaction is not in a confirmable state.
    public func transactionConfirmed(transactionId: String, confirm: Bool) async throws -> KoardTransaction {
        try await KoardMerchantSDK.shared.confirm(transaction: transactionId, confirm: confirm)
    }

    /// Logs out the currently authenticated merchant and clears session data.
    ///
    /// This method resets any stored credentials or tokens related to the merchant session,
    /// and should be called when the user explicitly signs out or when the session is no longer valid.
    ///
    /// - Note: After calling this method, the merchant must re-authenticate before performing additional operations.
    public func logout() {
        KoardMerchantSDK.shared.logout()

        // Clear any stored transaction IDs
        UserDefaults.standard.removeObject(forKey: "lastPreauthId")

        print("Logged out successfully")
    }

    /// Processes a refund for the specified transaction ID. Optionally provide a partial amount.
    /// - Parameter transactionId: Description
    /// - Parameter amount: Description
    /// - Throws: An error if the operation fails
    public func processRefund(transactionId: String, amount: Int? = nil) async throws {
        do {
            // To ensure idempotency in sale requests, use the optional eventID parameter.
            // This unique identifier allows Koard to recognize repeat attempts of the same transaction and
            // return the original result instead of initiating a new charge.
            let eventId = UUID().uuidString

            let response = try await KoardMerchantSDK.shared.refund(
                transactionId: transactionId,
                amount: amount, // nil for full refund
                eventId: eventId
            )

            print("Refund successful: \(response.transactionId ?? "Unknown")")

        } catch {
            print("Refund failed: \(error)")
            throw error
        }
    }

    /// Adds an additional authorized amount to an existing pre-authorized transaction.
    /// - Parameter transactionId: Description
    /// - Parameter additionalAmount: Description
    /// - Throws: An error if the operation fails
    public func incrementalAuth(transactionId: String, additionalAmount: Int) async throws {
        // Optional: Add breakdown for the additional amount
        let breakdown = PaymentBreakdown(
            subtotal: additionalAmount,
            taxRate: 875, // 8.75%
            taxAmount: Int(Double(additionalAmount) * 0.0875),
            tipAmount: 0,
            tipType: .fixed
        )

        // To ensure idempotency in sale requests, use the optional eventID parameter.
        // This unique identifier allows Koard to recognize repeat attempts of the same transaction and
        // return the original result instead of initiating a new charge.
        let eventId = UUID().uuidString

        do {
            let response = try await KoardMerchantSDK.shared.auth(
                transactionId: transactionId,
                amount: additionalAmount,
                breakdown: breakdown, // Optional
                eventId: eventId
            )

            print("Incremental auth successful: \(response.transactionId ?? "Unknown")")

        } catch {
            print("Incremental auth failed: \(error)")
            throw error
        }
    }

    /// Cancels or reduces a preauthorized transaction, optionally with a specific amount.
    /// - Parameter transactionId: Description
    /// - Parameter amount: Description
    /// - Throws: An error if the operation fails
    public func reversePreauth(transactionId: String, amount: Int? = nil) async throws {
        do {
            // To ensure idempotency in sale requests, use the optional eventID parameter.
            // This unique identifier allows Koard to recognize repeat attempts of the same transaction and
            // return the original result instead of initiating a new charge.
            let eventId = UUID().uuidString

            let response = try await KoardMerchantSDK.shared.reverse(
                transactionId: transactionId,
                amount: amount, // nil for full reversal
                eventId: eventId
            )

            print("Reversal successful: \(response.transactionId ?? "Unknown")")

        } catch {
            print("Reversal failed: \(error)")
            throw error
        }
    }

    /// Finalizes a previously authorized transaction by capturing funds from the cardholder.
    ///
    /// This method completes a pre-authorized transaction by capturing either the originally authorized amount
    /// or an updated amount based on a new subtotal, tax, and optional tip. It calculates the final tax from the
    /// provided subtotal and tax rate, and constructs a `PaymentBreakdown` to pass into the capture request.
    ///
    /// A unique `eventId` is generated and included with the capture call to ensure idempotency. If the operation
    /// is retried (e.g. due to a network error), using the same `eventId` ensures Koard returns the original
    /// capture result instead of processing a duplicate charge.
    ///
    /// - Parameters:
    ///   - transactionId: The identifier of the pre-authorized transaction to capture.
    ///   - subtotal: The transaction subtotal in cents (e.g. `1000` = $10.00).
    ///   - taxRate: The tax rate as a decimal percentage (e.g. `8.75` for 8.75%).
    ///   - tipAmount: An optional tip amount in cents. Defaults to `0`.
    ///   - tipType: The tip type, such as `.fixed` or `.percent`. Defaults to `.fixed`.
    ///   - finalAmount: An optional override for the final amount to capture. If `nil`, the full preauthorized amount is captured.
    /// - Returns: A `String` representing the generated `eventId` used for this capture.
    /// - Throws: An error if the capture fails or if the transaction is not in a capturable state.
    public func captureTransaction(
        transactionId: String,
        subtotal: Int,
        taxRate: Double,
        tipAmount: Int? = 0,
        tipType: PaymentBreakdown.TipType = .fixed,
        finalAmount: Int? = nil
    ) async throws -> String {
        let taxAmount = Int((Double(subtotal) * taxRate / 100.0).rounded())

        // Optional: Update breakdown with final tip amount
        let finalBreakdown = PaymentBreakdown(
            subtotal: subtotal,
            taxRate: Int(taxRate * 100),
            taxAmount: taxAmount,
            tipAmount: tipAmount ?? 0,
            tipType: tipType
        )

        // To ensure idempotency in sale requests, use the optional eventID parameter.
        // This unique identifier allows Koard to recognize repeat attempts of the same transaction and
        // return the original result instead of initiating a new charge.
        let eventId = UUID().uuidString

        do {
            let response = try await KoardMerchantSDK.shared.capture(
                transactionId: transactionId,
                amount: finalAmount, // nil to capture full authorized amount
                breakdown: finalBreakdown, // Optional: updated breakdown with final tip
                eventId: eventId
            )

            print("Capture successful: \(response.transactionId ?? "Unknown")")
            return eventId

        } catch {
            print("Capture failed: \(error)")
            throw error
        }
    }

    /// Executes a complete pre-authorization and capture workflow for a card-present transaction.
    ///
    /// This function first performs a pre-authorization for the base `subtotal` amount in USD, then captures
    /// the final amount after applying tax and an optional tip. It constructs a `PaymentBreakdown` using the
    /// provided values and calculates the tax amount from the `taxRate`.
    ///
    /// A unique `eventId` is generated and included in the capture request to ensure idempotency. If the capture
    /// call is retried due to a network failure or timeout, reusing the same `eventId` ensures Koard will return
    /// the original result instead of processing a duplicate charge.
    ///
    /// - Parameters:
    ///   - subtotal: The base transaction amount in cents (e.g., `1000` = $10.00).
    ///   - taxRate: The tax rate as a decimal percentage (e.g., `8.75` for 8.75%).
    ///   - tipAmount: An optional tip amount in cents. Defaults to `0`.
    ///   - tipType: The type of tip (e.g., `.fixed` or `.percent`). Defaults to `.fixed`.
    /// - Returns: A `TransactionResponse` containing the result of the final capture operation.
    /// - Throws: An error if the pre-authorization or capture step fails.
    public func preauthCaptureWorkflow(
        subtotal: Int,
        taxRate: Double,
        tipAmount: Int? = 0,
        tipType: PaymentBreakdown.TipType = .fixed
    ) async throws -> TransactionResponse {
        let currency = CurrencyCode(currencyCode: "USD", displayName: "US Dollar")

        // Step 1: Preauthorize base amount
        let preauthResponse = try await KoardMerchantSDK.shared.preauth(
            amount: subtotal,
            currency: currency
        )

        let authorizedTransactionId = preauthResponse.transactionId!
        print("Preauth completed: \(authorizedTransactionId)")

        // Step 2: Customer adds tip, create final breakdown
        let taxAmount = Int((Double(subtotal) * taxRate / 100.0).rounded())

        // Optional: Update breakdown with final tip amount
        let finalBreakdown = PaymentBreakdown(
            subtotal: subtotal,
            taxRate: Int(taxRate * 100),
            taxAmount: taxAmount,
            tipAmount: tipAmount ?? 0,
            tipType: tipType
        )

        // To ensure idempotency in sale requests, use the optional eventID parameter.
        // This unique identifier allows Koard to recognize repeat attempts of the same transaction and
        // return the original result instead of initiating a new charge.
        let eventId = UUID().uuidString
        let amount = subtotal + taxAmount + (tipAmount ?? 0)

        // Step 3: Capture with final amount and breakdown
        let captureResponse = try await KoardMerchantSDK.shared.capture(
            transactionId: authorizedTransactionId,
            amount: amount, // $12.88 final amount
            breakdown: finalBreakdown,
            eventId: eventId
        )

        return captureResponse
    }

    public func preauthorize(
        amount: Int,
        currency: CurrencyCode) async throws -> TransactionResponse {
        try await KoardMerchantSDK.shared.preauth(
            amount: amount,
            currency: currency
        )
    }

    /// Executes an incremental authorization and final capture workflow on a pre-authorized transaction.
    ///
    /// - Parameters:
    ///   - initialAmount: The amount (in cents) to pre-authorize initially.
    ///   - incrementalSubtotal: The additional subtotal amount for incremental auth (in cents).
    ///   - taxRate: The tax rate as a decimal percentage (e.g. 8.75 for 8.75%).
    ///   - tipAmount: Optional tip amount in cents to include in the final capture. Defaults to `0`.
    ///   - tipType: The type of tip (`.fixed` or `.percent`). Defaults to `.fixed`.
    ///   - finalAmount: The full final amount (in cents) to capture after preauth + incremental + tip.
    /// - Returns: A `TransactionResponse` for the final captured transaction.
    /// - Throws: An error if any step in the preauth, incremental auth, or capture process fails.
    public func incrementalAuthWorkflow(
        initialAmount: Int,
        incrementalSubtotal: Int,
        taxRate: Double,
        tipAmount: Int = 0,
        tipType: PaymentBreakdown.TipType = .fixed,
        finalAmount: Int
    ) async throws -> TransactionResponse {
        let currency = CurrencyCode(currencyCode: "USD", displayName: "US Dollar")

        // Step 1: Initial preauth
        let preauthResponse = try await KoardMerchantSDK.shared.preauth(
            amount: initialAmount,
            currency: currency
        )

        let authorizedTransactionId = preauthResponse.transactionId!

        // Step 2: Incremental authorization for additional items
        let incrementalTax = Int((Double(incrementalSubtotal) * taxRate / 100.0).rounded())
        let additionalBreakdown = PaymentBreakdown(
            subtotal: incrementalSubtotal,
            taxRate: Int(taxRate * 100),
            taxAmount: incrementalTax,
            tipAmount: 0,
            tipType: .fixed
        )

        let eventId = UUID().uuidString

        let _ = try await KoardMerchantSDK.shared.auth(
            transactionId: authorizedTransactionId,
            amount: incrementalSubtotal + incrementalTax,
            breakdown: additionalBreakdown,
            eventId: eventId
        )

        // Step 3: Final capture including all charges and tip
        let totalTax = Int((Double(initialAmount + incrementalSubtotal) * taxRate / 100.0).rounded())
        let finalBreakdown = PaymentBreakdown(
            subtotal: initialAmount + incrementalSubtotal,
            taxRate: Int(taxRate * 100),
            taxAmount: totalTax,
            tipAmount: tipAmount,
            tipType: tipType
        )

        let captureResponse = try await KoardMerchantSDK.shared.capture(
            transactionId: authorizedTransactionId,
            amount: finalAmount,
            breakdown: finalBreakdown,
            eventId: eventId
        )

        return captureResponse
    }

    public func sendReceipts(
        transactionId: String,
        email: String? = nil,
        phoneNumber: String? = nil
    ) async throws -> SendReceiptsResponse {
        try await KoardMerchantSDK.shared.sendReceipts(
            transactionId: transactionId,
            email: email,
            phoneNumber: phoneNumber
        )
    }

    public func refund(
        transactionID: String,
        amount: Int?,
        eventId: String? = nil
    ) async throws -> TransactionResponse {
        try await KoardMerchantSDK.shared.refund(
            transactionID: transactionID,
            amount: amount
        )
    }
}

extension KoardMerchantService {
    private func handleTransactionResponse(_ response: TransactionResponse) async throws {
        guard let transaction = response.transaction else {
            throw PaymentError.invalidTransaction
        }

        switch transaction.status {
        case .captured:
            print("Transaction captured!")
            print("Transaction ID: \(transaction.transactionId)")
            print("Amount: $\(Double(transaction.totalAmount) / 100.0)")

        case .surchargePending:
            print("Surcharge pending - customer approval required")

            // Show surcharge disclosure to customer
            if let disclosure = transaction.surchargeDisclosure {
                let approved = try await showSurchargeDisclosure(disclosure)

                // Confirm or deny the surcharge
                let confirmedTransaction = try await KoardMerchantSDK.shared.confirm(
                    transaction: transaction.transactionId,
                    confirm: approved
                )

                print("Final transaction status: \(confirmedTransaction.status)")
            }

        case .declined:
            print("Transaction declined: \(transaction.statusReason ?? "Unknown reason")")

        case .error:
            print("Transaction error: \(transaction.statusReason ?? "Unknown error")")

        default:
            print("Transaction status: \(transaction.status.string)")
        }
    }

    private func showSurchargeDisclosure(_ disclosure: String) async throws -> Bool {
        // Example using UIAlertController (iOS) - UIKit.  Not used in this demo
        // Show disclosure to customer and get their approval
        // This should be implemented based on your UI requirements

        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let alert = UIAlertController(
                    title: "Surcharge Notice",
                    message: disclosure,
                    preferredStyle: .alert
                )

                alert.addAction(UIAlertAction(title: "Accept", style: .default) { _ in
                    continuation.resume(returning: true)
                })

                alert.addAction(UIAlertAction(title: "Decline", style: .cancel) { _ in
                    continuation.resume(returning: false)
                })

                // Present alert (you'll need to implement this based on your view hierarchy)
                // self.present(alert, animated: true)
            }
        }
    }

    private func handleReaderEvent(_ event: PaymentCardReader.Event) {
        switch event {
        case .readyForTap:
            print("Ready for tap")
        case .cardDetected:
            print("Card detected")
        case .readCompleted:
            print("Card read completed")
        case .readCancelled:
            print("Card read cancelled")
        default:
            print("Reader event: \(event.description)")
        }
    }
}
