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
            taxRate: 875, // 8.75%
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
            parentAccountIds: ["parent_001", "parent_002"]
        )
    }
}
