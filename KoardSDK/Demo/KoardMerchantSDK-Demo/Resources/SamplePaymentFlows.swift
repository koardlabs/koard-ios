import Foundation
import KoardSDK

/// This extension includes reference implementations of advanced payment workflows using the Koard Merchant SDK.
///
/// These functions are not invoked within the demo application UI, but they serve as examples of how to
/// handle full transaction lifecycles including pre-authorization, capture, and incremental authorization.
///
/// Developers can use these workflows as templates when building production-ready implementations
/// that involve delayed capture, tip adjustments, or multi-step authorization flows.
///
/// Each method is structured to demonstrate best practices in breakdown management,
/// transaction response handling, and error propagation.
extension KoardMerchantService {
    /// Finalizes a previously authorized transaction by capturing funds from the cardholder.
    /// - Parameter transactionId: The identifier of the pre-authorized transaction to be captured.
    /// - Parameter finalAmount: An optional updated final amount to capture. If omitted, the originally authorized amount will be captured.
    /// - Throws: An error if the capture fails or if the transaction is not in a capturable state.
    public func captureTransaction(transactionId: String, finalAmount: Int? = nil) async throws {
        // Optional: Update breakdown with final tip amount
        let finalBreakdown = PaymentBreakdown(
            subtotal: 1000, // $10.00
            taxRate: 875, // 8.75%
            taxAmount: 88, // $0.88
            tipAmount: 300, // $3.00 final tip
            tipType: .fixed
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

        } catch {
            print("Capture failed: \(error)")
            throw error
        }
    }

    /// Sample that performs a full pre-authorization workflow followed by capture.
    /// This includes initiating a pre-auth transaction, then capturing it upon success.
    /// - Throws: An error if any part of the pre-authorization or capture process fails.
    public func preauthCaptureWorkflow() async throws {
        let currency = CurrencyCode(currencyCode: "USD", displayName: "US Dollar")

        // Step 1: Preauthorize base amount
        let preauthResponse = try await KoardMerchantSDK.shared.preauth(
            amount: 1000, // $10.00 base amount
            currency: currency
        )

        let authorizedTransactionId = preauthResponse.transactionId!
        print("Preauth completed: \(authorizedTransactionId)")

        // Step 2: Customer adds tip, create final breakdown
        let finalBreakdown = PaymentBreakdown(
            subtotal: 1000, // $10.00
            taxRate: 875, // 8.75%
            taxAmount: 88, // $0.88
            tipAmount: 200, // $2.00 tip added
            tipType: .fixed
        )

        // To ensure idempotency in sale requests, use the optional eventID parameter.
        // This unique identifier allows Koard to recognize repeat attempts of the same transaction and
        // return the original result instead of initiating a new charge.
        let eventId = UUID().uuidString
        
        // Step 3: Capture with final amount and breakdown
        let captureResponse = try await KoardMerchantSDK.shared.capture(
            transactionId: authorizedTransactionId,
            amount: 1288, // $12.88 final amount
            breakdown: finalBreakdown,
            eventId: eventId
        )

        print("Capture completed: \(captureResponse.transactionId ?? "Unknown")")
    }

    /// Sample that executes a workflow to authorize an additional amount on an existing pre-authorized transaction.
    /// Commonly used for scenarios like tip adjustment or delayed charge finalization.
    /// - Throws: An error if the incremental authorization fails.
    public func incrementalAuthWorkflow() async throws {
        let currency = CurrencyCode(currencyCode: "USD", displayName: "US Dollar")

        // Step 1: Initial preauth
        let preauthResponse = try await KoardMerchantSDK.shared.preauth(
            amount: 1000, // $10.00 initial amount
            currency: currency
        )

        let authorizedTransactionId = preauthResponse.transactionId!

        // Step 2: Customer orders additional items - incremental auth
        let additionalBreakdown = PaymentBreakdown(
            subtotal: 500, // $5.00 additional items
            taxRate: 875, // 8.75%
            taxAmount: 44, // $0.44 additional tax
            tipAmount: 0,
            tipType: .fixed
        )

        // To ensure idempotency in sale requests, use the optional eventID parameter.
        // This unique identifier allows Koard to recognize repeat attempts of the same transaction and
        // return the original result instead of initiating a new charge.
        let eventId = UUID().uuidString
        
        let authResponse = try await KoardMerchantSDK.shared.auth(
            transactionId: authorizedTransactionId,
            amount: 544, // $5.44 additional amount
            breakdown: additionalBreakdown,
            eventId: eventId
        )

        // Check if the authorization was successful
        print(authResponse)

        // Step 3: Final capture with tip
        let finalBreakdown = PaymentBreakdown(
            subtotal: 1500, // $15.00 total
            taxRate: 875, // 8.75%
            taxAmount: 131, // $1.31 total tax
            tipAmount: 300, // $3.00 tip
            tipType: .fixed
        )

        let captureResponse = try await KoardMerchantSDK.shared.capture(
            transactionId: authorizedTransactionId,
            amount: 1931, // $19.31 final amount
            breakdown: finalBreakdown,
            eventId: eventId
        )

        print("Final capture completed: \(captureResponse.transactionId ?? "Unknown")")
    }
}
