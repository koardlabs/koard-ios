import Foundation
import KoardSDK

/// When defining your own error types (e.g. MerchantError), we recommend conforming to the KoardDescribableError protocol.
/// This protocol standardizes how errors present a user-facing errorDescription string, making it easier to display consistent and meaningful messages throughout your app or UI.
enum MerchantError: Error, KoardDescribableError {
    case noLocationsAvailable
    case missingCredentials

    var errorDescription: String {
        switch self {
        case .noLocationsAvailable:
            "No locations available. Please ensure your merchant account has locations set up."
        case .missingCredentials:
            "Missing merchant credentials. Please provide a valid code and pin."
        }
    }
}
