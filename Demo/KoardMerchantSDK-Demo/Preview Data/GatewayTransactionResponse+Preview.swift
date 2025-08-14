import Foundation
import KoardSDK

extension GatewayTransactionResponse {
    public static var refundedGatewayTransactionResponse: GatewayTransactionResponse {
        .init(
            type: "sale",
            status: "refunded",
            currency: "USD",
            approvalCode: "123456",
            responseCode: "00",
            responseMessage: "Refunded",
            authorizedAmount: 4999,
            processorResponseCode: "1000"
        )
    }

    public static var declinedGatewayTransactionResponse: GatewayTransactionResponse {
        .init(
            type: "sale",
            status: "declined",
            currency: "USD",
            approvalCode: "123456",
            responseCode: "00",
            responseMessage: "Declined",
            authorizedAmount: 4999,
            processorResponseCode: "1000"
        )
    }

    public static var approvedGatewayTransactionResponse: GatewayTransactionResponse {
        .init(
            type: "sale",
            status: "approved",
            currency: "USD",
            approvalCode: "123456",
            responseCode: "00",
            responseMessage: "Approved",
            authorizedAmount: 4999,
            processorResponseCode: "1000"
        )
    }
}
