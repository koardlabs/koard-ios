import KoardSDK
import SwiftUI

extension KoardTransaction {
    var transactionTypeDisplayName: String {
        switch transactionType {
        case "sale":
            return "Sale"
        case "manually_keyed_sale":
            return "Keyed Sale"
        case "auth":
            return "Auth"
        case "capture":
            return "Capture"
        case "refund":
            return "Refund"
        case "reverse":
            return "Reverse"
        case "tip_adjust":
            return "Tip Adjust"
        case "incremental_auth":
            return "Incremental Auth"
        case "verification":
            return "Verification"
        default:
            return "Unknown"
        }
    }
}

extension KoardTransaction.Status {
    var simple: Simple {
        switch self {
        case .surchargeApplied, .approved, .captured: .approved
        case .declined, .timedOut, .error, .canceled, .cancelled: .failed
        case .surchargePending, .refunded, .unknown, .reversed, .pickupCard, .pending, .authorized, .settled: .other
        @unknown default: .other
        }
    }

    enum Simple {
        case approved
        case failed
        case other
    }

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .authorized: return "Authorized"
        case .captured: return "Captured"
        case .surchargePending: return "Surcharge Pending"
        case .surchargeApplied: return "Surcharge Applied"
        case .approved: return "Approved"
        case .declined: return "Declined"
        case .refunded: return "Refunded"
        case .reversed: return "Reversed"
        case .pickupCard: return "Pickup Card"
        case .timedOut: return "Timed Out"
        case .canceled, .cancelled: return "Canceled"
        case .error: return "Error"
        case .unknown: return "Unknown"
        case .settled: return "Settled"
        @unknown default: return "Unknown"
        }
    }

    var statusColor: Color {
        switch simple {
        case .approved: .koardGreen
        case .failed: .red
        case .other: .orange
        }
    }
}
