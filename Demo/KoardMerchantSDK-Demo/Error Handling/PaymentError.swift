import Foundation
import KoardSDK

/// When defining your own error types (e.g. PaymentError), we recommend conforming to the KoardDescribableError protocol.
/// This protocol standardizes how errors present a user-facing errorDescription string, making it easier to display consistent and meaningful messages throughout your app or UI.
enum PaymentError: Error, KoardDescribableError {
    case insufficientFunds
    case cardDeclined
    case networkError
    case authorizationExceeded
    case invalidTransaction
    case unsupportedDevice

    var errorDescription: String {
        switch self {
        case .insufficientFunds:
            "Card declined - insufficient funds"
        case .cardDeclined:
            "Card was declined"
        case .networkError:
            "Network connection error"
        case .authorizationExceeded:
            "Cannot capture more than authorized amount"
        case .invalidTransaction:
            "Invalid transaction"
        case .unsupportedDevice:
            "Tap to Pay is not supported on this device"
        }
    }
}
