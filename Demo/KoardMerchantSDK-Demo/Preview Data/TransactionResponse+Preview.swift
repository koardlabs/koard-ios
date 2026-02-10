import Foundation
import KoardSDK

extension TransactionResponse {
    public static var mockCapturedTransaction: TransactionResponse {
        return .init(
            transactionId: "txn_mock_12345",
            eventId: UUID().uuidString,
            status: "captured",
            statusReason: nil,
            surchargeApplied: false,
            surchargeRate: nil,
            surchargeAmount: nil,
            surcharging: nil,
            mid: "mid_0001",
            tid: "tid_0001",
            batchId: "batch_001",
            processorMid: "proc_mid_001",
            processorTid: "proc_tid_001",
            accountId: "acct_001",
            deviceId: "device_001",
            processor: "Stripe",
            gateway: "KoardGateway",
            currency: "USD",
            locationId: "loc_001",
            gatewayTransactionId: "gtx_abc123",
            subtotal: 1000, // $10.00
            tipAmount: 300, // $3.00
            tipType: "fixed",
            taxAmount: 88, // $0.88
            taxRate: 875.0, // 8.75%
            totalAmount: 1388,
            createdAt: Int(Date().timeIntervalSince1970 * 1000),
            paymentMethod: "card",
            cardType: "credit",
            cardBrand: "Visa",
            card: "4242",
            processorResponseCode: "00",
            processorResponseMessage: "Approved",
            transactionType: "sale",
            appleTransactionId: nil,
            readerIdentifier: "reader_001",
            refunded: 0,
            reversed: 0,
            ownerId: "user_001",
            parentAccountIds: ["parent_001", "parent_002"],
            gatewayTransactionResponse: nil,
            additionalDetails: nil
        )
    }

    public static var mockPreauthorizedTransaction: TransactionResponse {
        return .init(
            transactionId: "txn_mock_67890",
            eventId: UUID().uuidString,
            status: "preauthorized",
            statusReason: nil,
            surchargeApplied: false,
            surchargeRate: nil,
            surchargeAmount: nil,
            surcharging: nil,
            mid: "mid_0002",
            tid: "tid_0002",
            batchId: "batch_002",
            processorMid: "proc_mid_002",
            processorTid: "proc_tid_002",
            accountId: "acct_002",
            deviceId: "device_002",
            processor: "Stripe",
            gateway: "KoardGateway",
            currency: "USD",
            locationId: "loc_002",
            gatewayTransactionId: "gtx_def456",
            subtotal: 2500, // $25.00
            tipAmount: 0,
            tipType: nil,
            taxAmount: 219, // $2.19
            taxRate: 875.0, // 8.75%
            totalAmount: 2719, // $27.19
            createdAt: Int(Date().timeIntervalSince1970 * 1000),
            paymentMethod: "card",
            cardType: "debit",
            cardBrand: "Mastercard",
            card: "4444",
            processorResponseCode: "00",
            processorResponseMessage: "Authorized - Funds on Hold",
            transactionType: "auth",
            appleTransactionId: nil,
            readerIdentifier: "reader_002",
            refunded: 0,
            reversed: 0,
            ownerId: "user_002",
            parentAccountIds: ["parent_003", "parent_004"],
            gatewayTransactionResponse: nil,
            additionalDetails: nil
        )
    }
}
