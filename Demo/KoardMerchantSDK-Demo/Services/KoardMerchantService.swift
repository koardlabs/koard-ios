import Combine
import Foundation
import KoardSDK
import UIKit
#if canImport(ProximityReader)
    import ProximityReader
#endif

public class KoardMerchantService: KoardMerchantServiceable {
    private let apiKey: String
    private let configEnvironment: String
    private let customURL: String?
    private var merchantCode: String?
    private var merchantPin: String?
    private var locations: [Location] = []
    private var cachedActiveLocation: Location?
    private var cancellables: Set<AnyCancellable> = []

    private var task: Task<Void, Never>?

    public var isAuthenticated: Bool {
        KoardMerchantSDK.shared.isAuthenticated
    }

    public var activeLocation: Location? {
        if let cachedActiveLocation {
            return cachedActiveLocation
        }

        guard let activeLocationID = KoardMerchantSDK.shared.getActiveLocationID() else {
            return nil
        }

        return locations.first { $0.id == activeLocationID }
    }

    public var isReaderSetupSupported: Bool {
        KoardMerchantSDK.shared.isAuthenticated &&
            KoardMerchantSDK.shared.isReaderSupported
    }

    init(apiKey: String, environment: String, customURL: String? = nil, merchantCode: String? = nil, merchantPin: String? = nil) {
        self.apiKey = apiKey
        self.configEnvironment = environment
        self.customURL = customURL
        self.merchantCode = merchantCode
        self.merchantPin = merchantPin
    }

    /// Initializes any internal state or configuration required before SDK usage begins.
    public func setup() {
        print("[KoardMerchantService] Setting up SDK with environment: \(configEnvironment)")

        // Use the environment from the config file (NOT from environment variables)
        let environment: KoardEnvironment

        switch configEnvironment.uppercased() {
        case "PRODUCTION", "PROD":
            environment = .production
            print("[KoardMerchantService] Using PRODUCTION environment")
        case "PRODUCTION_CUSTOM":
            if let url = customURL {
                environment = .custom(url)
                print("[KoardMerchantService] Using PRODUCTION_CUSTOM environment (\(url))")
            } else {
                environment = .production
                print("[KoardMerchantService] WARNING: PRODUCTION_CUSTOM without customURL, falling back to PRODUCTION")
            }
        case "UAT", "STAGING":
            environment = .uat
            print("[KoardMerchantService] Using UAT environment")
        case "DEV", "DEVELOPMENT":
            if let url = customURL {
                environment = .custom(url)
                print("[KoardMerchantService] Using DEV environment (\(url))")
            } else {
                environment = .uat
                print("[KoardMerchantService] WARNING: DEV without customURL, falling back to UAT")
            }
        default:
            environment = .uat
            print("[KoardMerchantService] Unknown environment '\(configEnvironment)', defaulting to UAT")
        }

        let options = KoardOptions(
            environment: environment,
            loggingLevel: .debug // .debug, .info, .warning, .error, .none
        )

        // Initialize with your API key
        KoardMerchantSDK.shared.initialize(
            options: options,
            apiKey: apiKey
        )

        print("[KoardMerchantService] SDK initialized. isAuthenticated: \(isAuthenticated)")
    }

    /// Performs merchant authentication using credentials stored or provided elsewhere.
    /// - Throws: An error if the operation fails
    public func authenticateMerchant() async throws {
        guard let merchantPin, let merchantCode else {
            throw MerchantError.missingCredentials
        }

        try await authenticateMerchant(code: merchantCode, pin: merchantPin)
    }

    /// Performs merchant authentication using provided credentials.
    /// - Parameters:
    ///   - code: The merchant code
    ///   - pin: The merchant PIN
    /// - Throws: An error if the operation fails
    public func authenticateMerchant(code: String, pin: String) async throws {
        do {
            // Login with merchant credentials
            try await KoardMerchantSDK.shared.login(
                code: code,
                pin: pin
            )

            // Store credentials after successful authentication
            self.merchantCode = code
            self.merchantPin = pin

            print("Merchant authenticated successfully")

            // After login, set up location
            try await setupLocation()

        } catch {
            print("Authentication failed: \(error)")
            throw error
        }
    }

    /// Fetches the list of available merchant locations from the Koard SDK.
    ///
    /// This function asynchronously retrieves the list of `Location` objects
    /// from the `KoardMerchantSDK`. The result is stored locally and returned
    /// to the caller. If no locations are found, a `MerchantError.noLocationsAvailable`
    /// error is thrown.
    ///
    /// - Returns: An array of `Location` objects representing the merchant’s
    ///   available locations.
    /// - Throws:
    ///   - `MerchantError.noLocationsAvailable` if the SDK returns an empty list.
    ///   - Any other error encountered while fetching locations from the SDK.
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

    /// Updates the currently active merchant location in the Koard SDK.
    ///
    /// This function sets the provided `Location` as the active location within the
    /// `KoardMerchantSDK`. The active location ID will be used by the SDK to
    /// associate transactions and other merchant activity with the correct location.
    ///
    /// - Parameter location: The `Location` object representing the merchant
    ///   location to activate. Its `id` will be passed to the SDK.
    public func updateLocation(location: Location) {
        KoardMerchantSDK.shared.setActiveLocationID(location.id)
        cachedActiveLocation = location

        #if canImport(ProximityReader)
            if #available(iOS 17.0, *) {
                Task {
                    do {
                        _ = try await KoardMerchantSDK.shared.getToken()
                        print("Fetched Tap to Pay token after location update")
                        try KoardMerchantSDK.shared.linkAccount()
                        print("Link account invoked after token refresh")
                        try await KoardMerchantSDK.shared.prepare()
                        print("Card reader prepared for new location")
                    } catch {
                        print("Failed to prepare reader after location update: \(error)")
                    }
                }
            }
        #endif
    }
    
    public func loadActiveLocation() async -> Location? {
        do {
            let location = try await KoardMerchantSDK.shared.getActiveLocation()
            cachedActiveLocation = location

            if let index = locations.firstIndex(where: { $0.id == location.id }) {
                locations[index] = location
            } else {
                locations.append(location)
            }

            return location
        } catch {
            print("Failed to load active location: \(error)")
            return nil
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
            cachedActiveLocation = activeLocation

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
            #if canImport(ProximityReader)
                if #available(iOS 17.0, *) {
                    _ = try await KoardMerchantSDK.shared.getToken()
                }
            #endif

            try await KoardMerchantSDK.shared.prepare()


            // Optional: Monitor reader status
            monitorReaderStatus()

        } catch {
            print("Card reader preparation failed: \(error)")
            throw error
        }
    }

    /// Begins listening to card reader status changes and handles updates in real time.
    public func monitorReaderStatus() {
        // Cancel any old task if already running
        task?.cancel()

        task = Task {
            for await event in KoardMerchantSDK.shared.readerEvents {
                await MainActor.run {
                    print("Received reader event: \(event)")
                }
            }
        }
    }

    public func stopListening() {
        task?.cancel()
        task = nil
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
    ///   - tipRate: The percentage rate to apply when `tipType` is `.percentage`.
    /// - Returns: A `KoardTransaction` object containing the transaction details upon success.
    /// - Throws: An error if the transaction fails, is declined, or the reader is not ready.
    public func processSale(
        subtotal: Int,
        taxAmount: Int,
        taxRate: Double? = nil,
        tipAmount: Int? = 0,
        tipRate: Double? = nil,
        tipType: PaymentBreakdown.TipType = .fixed,
        surcharge: PaymentBreakdown.Surcharge? = nil
    ) async throws -> KoardTransaction {
        let tipAmountValue = tipAmount ?? 0
        let surchargeAmount: Int = {
            guard let surcharge else { return 0 }
            if surcharge.bypass { return 0 }
            if let amount = surcharge.amount {
                return amount
            }
            if let percentage = surcharge.percentage {
                let surchargeBase = subtotal + taxAmount + tipAmountValue
                return Int((Double(surchargeBase) * percentage / 100.0).rounded())
            }
            return 0
        }()

        // Only create breakdown if there are actual values to send
        let breakdown: PaymentBreakdown? = {
            let hasTax = taxAmount > 0
            let hasTip = tipAmountValue > 0
            let hasSurcharge = surcharge != nil

            guard hasTax || hasTip || hasSurcharge else {
                return nil
            }

            let normalizedTipRate: Double? = {
                guard tipType == .percentage, let tipRate, tipRate > 0 else { return nil }
                return tipRate
            }()
            let breakdownTipAmount: Int? = normalizedTipRate == nil ? tipAmountValue : nil

            // Only send taxRate if it's provided and non-zero
            let breakdownTaxRate: Double? = {
                guard let rate = taxRate, rate > 0 else { return nil }
                return rate
            }()

            return PaymentBreakdown(
                subtotal: subtotal,
                taxRate: breakdownTaxRate,
                taxAmount: taxAmount,
                tipAmount: breakdownTipAmount,
                tipRate: normalizedTipRate,
                tipType: tipType,
                surcharge: surcharge
            )
        }()

        // To ensure idempotency in sale requests, use the optional eventID parameter.
        // This unique identifier allows Koard to recognize repeat attempts of the same transaction and
        // return the original result instead of initiating a new charge.
        let eventId = UUID().uuidString

        // Create currency
        let currency = CurrencyCode(currencyCode: "USD", displayName: "US Dollar")
        let amount = subtotal + taxAmount + tipAmountValue + surchargeAmount

        print("""
        [KoardMerchantService] Sale Payload:
          Amount (sent to card reader): \(amount) cents ($\(Double(amount)/100.0))
          Subtotal: \(subtotal) cents
          Tax Amount: \(taxAmount) cents
          Tax Rate: \(String(describing: taxRate))
          Tip Amount: \(tipAmountValue) cents
          Surcharge: \(surchargeAmount) cents
          Breakdown: \(breakdown != nil ? "YES" : "NO")
        """)

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
        startDate: Date?,
        endDate: Date?,
        statuses: [KoardTransaction.Status]?,
        types: [PaymentType]?,
        minAmount: Int?,
        maxAmount: Int?,
        limit: Int?
    ) async throws -> TransactionHistoryResponse {
        do {
            let request = GetTransactionHistoryRequest(
                storeId: KoardMerchantSDK.shared.getActiveLocationID(),
                statuses: statuses?.map { $0.rawValue.lowercased() },
                types: types?.map { $0.rawValue.lowercased() },
                minAmount: minAmount,
                maxAmount: maxAmount,
                startDate: startDate,
                endDate: endDate,
                limit: limit ?? 100
            )

            return try await KoardMerchantSDK.shared.transactionHistory(request: request)
        } catch {
            print("Transaction history failed: \(error)")
            throw error
        }
    }

    public func fetchTransaction(transactionId: String) async throws -> KoardTransaction {
        try await KoardMerchantSDK.shared.getTransaction(transactionId: transactionId)
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
    public func transactionConfirmed(
        transactionId: String,
        confirm: Bool,
        amount: Int? = nil,
        breakdown: PaymentBreakdown?,
        eventId: String? = nil
    ) async throws -> KoardTransaction {
        try await KoardMerchantSDK.shared.confirm(
            transaction: transactionId,
            confirm: confirm,
            amount: amount,
            breakdown: breakdown,
            eventId: eventId
        )
    }

    /// Logs out the currently authenticated merchant and clears session data.
    ///
    /// This method resets any stored credentials or tokens related to the merchant session,
    /// and should be called when the user explicitly signs out or when the session is no longer valid.
    ///
    /// - Note: After calling this method, the merchant must re-authenticate before performing additional operations.
    public func logout() {
        // Logout from SDK (clears auth tokens, card reader tokens from Keychain)
        KoardMerchantSDK.shared.logout()

        // Clear stored credentials
        self.merchantCode = nil
        self.merchantPin = nil

        // Clear cached location data
        self.cachedActiveLocation = nil
        self.locations = []

        // Clear any stored transaction IDs
        UserDefaults.standard.removeObject(forKey: "lastPreauthId")

        // Cancel any ongoing reader monitoring tasks
        stopListening()

        print("Logged out successfully - all credentials and session data cleared")
    }

    /// Processes a refund for the specified transaction ID. Optionally provide a partial amount.
    /// - Parameter transactionId: Description
    /// - Parameter amount: Description
    /// - Throws: An error if the operation fails
    public func processRefund(transactionId: String, amount: Int? = nil, withTap: Bool = false) async throws {
        do {
            // To ensure idempotency in sale requests, use the optional eventID parameter.
            // This unique identifier allows Koard to recognize repeat attempts of the same transaction and
            // return the original result instead of initiating a new charge.
            let eventId = UUID().uuidString

            let response = try await KoardMerchantSDK.shared.refund(
                transactionId: transactionId,
                amount: amount, // nil for full refund
                eventId: eventId,
                withTap: withTap
            )

            print("Refund successful: \(response.transactionId ?? "Unknown")")

        } catch {
            print("Refund failed: \(error)")
            throw error
        }
    }

    /// Adds an additional authorized amount to an existing pre-authorized transaction.
    /// - Parameters:
    ///   - transactionId: The identifier of the transaction to increment.
    ///   - amount: The additional amount in cents to authorize.
    /// - Returns: A `TransactionResponse` describing the incremental authorization result.
    /// - Throws: An error if the operation fails.
    public func incrementalAuth(transactionId: String, amount: Int) async throws -> TransactionResponse {
        let eventId = UUID().uuidString

        do {
            let response = try await KoardMerchantSDK.shared.auth(
                transactionId: transactionId,
                amount: amount,
                eventId: eventId
            )

            print("Incremental auth successful: \(response.transactionId ?? "Unknown")")
            return response
        } catch {
            print("Incremental auth failed: \(error)")
            throw error
        }
    }

    /// Cancels or reduces a preauthorized transaction, optionally with a specific amount.
    /// - Parameters:
    ///   - transactionId: The identifier of the transaction to reverse.
    ///   - amount: An optional amount in cents to reverse. Omit to reverse the full authorization.
    /// - Returns: A `TransactionResponse` describing the reversal result.
    /// - Throws: An error if the operation fails.
    public func reverse(transactionId: String, amount: Int? = nil) async throws -> TransactionResponse {
        let eventId = UUID().uuidString

        do {
            let response = try await KoardMerchantSDK.shared.reverse(
                transactionId: transactionId,
                amount: amount,
                eventId: eventId
            )

            print("Reversal successful: \(response.transactionId ?? "Unknown")")
            return response
        } catch {
            print("Reversal failed: \(error)")
            throw error
        }
    }

    /// Cancels or reduces a preauthorized transaction, optionally with a specific amount.
    /// - Parameter transactionId: Description
    /// - Parameter amount: Description
    /// - Throws: An error if the operation fails
    public func reversePreauth(transactionId: String, amount: Int? = nil) async throws {
        _ = try await reverse(transactionId: transactionId, amount: amount)
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
    /// - Returns: A `TransactionResponse` representing the capture result.
    /// - Throws: An error if the capture fails or if the transaction is not in a capturable state.
    public func captureTransaction(
        transactionId: String,
        amount: Int? = nil
    ) async throws -> TransactionResponse {
        // To ensure idempotency in sale requests, use the optional eventID parameter.
        // This unique identifier allows Koard to recognize repeat attempts of the same transaction and
        // return the original result instead of initiating a new charge.
        let eventId = UUID().uuidString

        // For capture, just send the amount - no breakdown
        let response = try await KoardMerchantSDK.shared.capture(
            transactionId: transactionId,
            amount: amount, // nil to capture full authorized amount
            breakdown: nil,
            eventId: eventId
        )

        print("Capture successful: \(response.transactionId ?? "Unknown")")
        return response
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
            breakdown: nil,
            currency: currency
        )

        let authorizedTransactionId = preauthResponse.transactionId!
        print("Preauth completed: \(authorizedTransactionId)")

        // Step 2: Customer adds tip, create final breakdown
        let taxAmount = Int((Double(subtotal) * taxRate / 100.0).rounded())

        // Optional: Update breakdown with final tip amount
        let finalBreakdown = PaymentBreakdown(
            subtotal: subtotal,
            taxRate: taxRate > 0 ? taxRate : nil,
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
        breakdown: PaymentBreakdown?,
        currency: CurrencyCode
    ) async throws -> TransactionResponse {
        try await KoardMerchantSDK.shared.preauth(
            amount: amount,
            breakdown: breakdown,
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
            breakdown: nil,
            currency: currency
        )

        let authorizedTransactionId = preauthResponse.transactionId!

        // Step 2: Incremental authorization for additional items
        let incrementalTax = Int((Double(incrementalSubtotal) * taxRate / 100.0).rounded())
        let additionalBreakdown = PaymentBreakdown(
            subtotal: incrementalSubtotal,
            taxRate: taxRate > 0 ? taxRate : nil,
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
            taxRate: taxRate > 0 ? taxRate : nil,
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
        eventId: String? = nil,
        withTap: Bool = false
    ) async throws -> TransactionResponse {
        try await KoardMerchantSDK.shared.refund(
            transactionId: transactionID,
            amount: amount,
            eventId: eventId,
            withTap: withTap
        )
    }

    public func tipAdjust(
        transactionId: String,
        amount: Int,
        tipType: PaymentBreakdown.TipType?
    ) async throws -> TransactionResponse {
        try await KoardMerchantSDK.shared.tipAdjust(
            transactionId: transactionId,
            amount: amount,
            tipType: tipType,
            eventId: UUID().uuidString
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
                    confirm: approved,
                    amount: nil,
                    breakdown: nil,
                    eventId: nil
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
