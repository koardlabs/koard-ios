import KoardSDK
import SwiftUI

struct TransactionInfoView: View {
    var type: String?
    var status: KoardTransaction.Status?
    var statusReason: String?
    var localizedAmount: String?
    var localizedTip: String?
    var localizedSubTotal: String?
    var localizedTax: String?
    var localizedSurchargeAmount: String?
    var surchargeApplied: Bool?
    var date: Date?
    var cardInfo: String?

    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let type {
                InfoRowView(titleText: "Transaction Type", valueText: type)
                Divider()
            }
            if let status {
                InfoRowView(titleText: "Status", valueText: getSimplifiedStatus(status: status, reason: statusReason))
                Divider()
            }
            if let localizedAmount {
                InfoRowView(titleText: "Total Amount", valueText: localizedAmount)
                Divider()
            }
            if let localizedSubTotal {
                InfoRowView(titleText: "Subtotal", valueText: localizedSubTotal)
                Divider()
            }
            if let localizedTax {
                InfoRowView(titleText: "Tax Amount", valueText: localizedTax)
                Divider()
            }
            if let localizedTip {
                InfoRowView(titleText: "Tip Amount", valueText: localizedTip)
                Divider()
            }

            if let localizedSurchargeAmount, let surchargeApplied, surchargeApplied {
                InfoRowView(titleText: "Surcharge Amount", valueText: localizedSurchargeAmount)
                Divider()
            }

            if let date {
                InfoRowView(titleText: "Date", valueText: dateFormatter.string(from: date))
                Divider()
            }

            if let cardInfo {
                InfoRowView(titleText: "Card", valueText: "\(cardInfo)")
            }
        }
    }

    private func getSimplifiedStatus(status: KoardTransaction.Status, reason: String?) -> String {
        switch status {
        case .approved, .captured:
            return "Approved"
        case .declined:
            return "Declined"
        case .refunded:
            return "Refunded"
        case .canceled:
            return "Canceled"
        case .error:
            return "Failed"
        default:
            return "Unknown"
        }
    }
}

struct InfoRowView: View {
    let titleText: String
    let valueText: String
    let icon: String?

    init(titleText: String, valueText: String, icon: String? = nil) {
        self.titleText = titleText
        self.valueText = valueText
        self.icon = icon
    }

    var body: some View {
        HStack(alignment: .center) {
            Text(LocalizedStringKey(titleText))
                .font(.system(size: 14, weight: .medium))

            Spacer()

            if let icon {
                Image(icon)
            }

            Text(valueText)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.gray)
        }
        .padding(.vertical, 8)
    }
}
