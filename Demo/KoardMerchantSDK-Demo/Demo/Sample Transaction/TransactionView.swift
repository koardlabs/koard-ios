import KoardSDK
import SwiftUI

struct TransactionView: View {
    @State private var viewModel: TransactionViewModel

    init(viewModel: TransactionViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .lastTextBaseline) {
                    Text("Amount")

                    DottedLine()
                        .frame(height: 1)
                        .padding(.horizontal, 4)
                        .alignmentGuide(.lastTextBaseline) { $0[.bottom] }

                    CurrencyField(value: $viewModel.transactionAmount)
                        .frame(width: 100)
                }

                HStack(alignment: .lastTextBaseline) {
                    Text("Tax Rate")

                    DottedLine()
                        .frame(height: 1)
                        .padding(.horizontal, 4)
                        .alignmentGuide(.lastTextBaseline) { $0[.bottom] }

                    PercentageField(value: $viewModel.taxRate)
                        .frame(width: 100)
                }

                HStack(alignment: .lastTextBaseline) {
                    Text("Tip")

                    DottedLine()
                        .frame(height: 1)
                        .padding(.horizontal, 4)
                        .alignmentGuide(.lastTextBaseline) { $0[.bottom] }

                    Picker("Options", selection: $viewModel.tipTypeSelection) {
                        ForEach(viewModel.tipTypes, id: \.self) { tipType in
                            Text(tipType.displayName)
                                .tag(tipType)
                        }
                    }
                    .pickerStyle(.segmented)

                    if viewModel.tipTypeSelection == .fixed {
                        CurrencyField(
                            value: $viewModel.tipAmount,
                            placeholder: "20.00"
                        )
                        .frame(width: 100)
                    } else {
                        PercentageField(
                            value: $viewModel.tipPercentage,
                            placeholder: "15"
                        )
                        .frame(width: 100)
                    }
                }
            }

            Toggle("Override Surcharge", isOn: $viewModel.isSurchargeOverrideOn)
                .toggleStyle(SwitchToggleStyle(tint: .koardGreen))
                .disabled(viewModel.isSurchargeBypassed)

            if viewModel.isSurchargeOverrideOn {
                HStack(alignment: .lastTextBaseline) {
                    Text("Surcharge")

                    DottedLine()
                        .frame(height: 1)
                        .padding(.horizontal, 4)
                        .alignmentGuide(.lastTextBaseline) { $0[.bottom] }

                    Picker("Options", selection: $viewModel.surchargeTypeSelection) {
                        ForEach(viewModel.tipTypes, id: \.self) { type in
                            Text(type.displayName)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    if viewModel.surchargeTypeSelection == .fixed {
                        CurrencyField(
                            value: $viewModel.surchargeAmount,
                            placeholder: "2.50"
                        )
                        .frame(width: 100)
                    } else {
                        PercentageField(
                            value: $viewModel.surchargePercentage,
                            placeholder: "3"
                        )
                        .frame(width: 100)
                    }
                }
            }

            Toggle("Bypass Surcharge", isOn: $viewModel.isSurchargeBypassed)
                .toggleStyle(SwitchToggleStyle(tint: .red))
                .disabled(viewModel.isSurchargeOverrideOn)

            HStack {
                Text("Total")
                    .font(.system(size: 32, weight: .bold))
                Spacer()
                let amount = viewModel.totalAmount.isEmpty ? "$0.00" : viewModel.totalAmount
                Text(amount)
                    .font(.system(size: 22, weight: .bold))
            }

            HStack(spacing: 12) {
                AsyncButton {
                    await viewModel.preauthorize()
                } label: {
                    Text("Auth")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary)
                .disabled(viewModel.totalAmountValue == 0 || viewModel.isProcessingSale)
                .overlay {
                    if viewModel.isProcessingSale {
                        ProgressView()
                            .tint(.white)
                    }
                }

                AsyncButton {
                    await viewModel.processTransaction()
                } label: {
                    VStack(spacing: 2) {
                        Text("Sale")
                        Text("Auth+Capture")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary)
                .disabled(viewModel.totalAmountValue == 0 || viewModel.isProcessingSale)
                .overlay {
                    if viewModel.isProcessingSale {
                        ProgressView()
                            .tint(.white)
                    }
                }
            }
            .padding(.top, 12)

            if viewModel.isProcessingSale {
                Text("Payment processing...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if case let .surcharge(message) = viewModel.transactionState {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.top, 8)
            }

            if let display = viewModel.lastTransactionDisplay {
                TransactionResultSection(display: display)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .navigationTitle("Transaction")
        .toolbarRole(.editor)
        .background {
            KoardBackgroundView()
                .ignoresSafeArea()
        }
        .popover(isPresented: $viewModel.isSummaryPresented) {
            if let summary = viewModel.transactionSummary {
                TransactionSummaryPopover(summary: summary)
            } else {
                Text("No transaction details available.")
                    .padding()
            }
        }
        .sheet(
            item: Binding(
                get: { viewModel.surchargePrompt },
                set: { viewModel.surchargePrompt = $0 }
            )
        ) { prompt in
            SurchargeConfirmationSheet(
                prompt: prompt,
                isProcessing: viewModel.isProcessingSale,
                onDecision: { confirm in
                    Task {
                        await viewModel.handleSurchargeDecision(confirm: confirm)
                    }
                }
            )
            .presentationDetents(Set([PresentationDetent.medium]))
            .presentationDragIndicator(Visibility.visible)
            .interactiveDismissDisabled(true)
        }
    }
}


private struct SurchargeConfirmationSheet: View {
    let prompt: TransactionViewModel.SurchargePrompt
    let isProcessing: Bool
    let onDecision: (Bool) -> Void

    private var currency: CurrencyCode {
        CurrencyCode(currencyCode: prompt.transaction.currency, displayName: nil)
    }

    private var totalAmount: String {
        MoneyUtils.centsToStringWithCurrency(prompt.transaction.totalAmount, currency: currency)
    }

    private var surchargeAmount: String? {
        guard let amount = prompt.transaction.surchargeAmount, amount > 0 else { return nil }
        return MoneyUtils.centsToStringWithCurrency(amount, currency: currency)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(prompt.flow.title) Pending Confirmation")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text(prompt.disclosure)
                        .font(.body)
                        .foregroundStyle(.primary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Transaction Summary")
                        .font(.headline)

                    SummaryRow(
                        title: "Total Amount",
                        value: totalAmount
                    )

                    if let surchargeAmount {
                        SummaryRow(
                            title: "Surcharge",
                            value: surchargeAmount
                        )
                    }

                    SummaryRow(
                        title: "Status",
                        value: prompt.transaction.status.displayName
                    )

                    SummaryRow(
                        title: "Transaction ID",
                        value: prompt.transaction.transactionId
                    )
                }

                if isProcessing {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Submitting decision…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        onDecision(false)
                    } label: {
                        Text("Decline")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(isProcessing)

                    Button {
                        onDecision(true)
                    } label: {
                        Text("Confirm")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.koardGreen)
                    .disabled(isProcessing)
                }
            }
            .padding()
        }
    }
}

struct CurrencyField: View {
    @Binding var value: String
    var placeholder: String = "9.99"
    var body: some View {
        ZStack(alignment: .leading) {
            HStack {
                Text("$")
                    .foregroundColor(.koardGreen)
                    .padding(.leading, 8)
                Spacer()
            }

            TextField(placeholder, text: $value)
                .keyboardType(.decimalPad)
                .padding(.leading, 20)
                .padding(.vertical, 6)
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.gray.opacity(0.5))
        )
    }
}

struct PercentageField: View {
    @Binding var value: String
    var placeholder: String = "8.75"
    var body: some View {
        ZStack(alignment: .leading) {
            HStack {
                Spacer()
                Text("%")
                    .foregroundColor(.koardGreen)
                    .padding(.trailing, 8)
            }

            TextField(placeholder, text: $value)
                .keyboardType(.decimalPad)
                .padding(.leading, 20)
                .padding(.trailing, 26)
                .padding(.vertical, 6)
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.gray.opacity(0.5))
        )
    }
}

struct TransactionResultSection: View {
    let display: TransactionViewModel.TransactionDetailDisplay
    private let cardBrandKeys: Set<String> = ["cardBrand", "transaction.cardBrand"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(display.title)
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                if let cardBrandEntry = display.entries.first(where: { cardBrandKeys.contains($0.key) }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Card Brand")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(cardBrandEntry.value)
                            .font(.system(size: 14, weight: .regular, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    if display.entries.contains(where: { !cardBrandKeys.contains($0.key) }) {
                        Divider()
                    }
                }

                let filteredEntries = display.entries.filter { !cardBrandKeys.contains($0.key) }

                ForEach(Array(filteredEntries.enumerated()), id: \.element.id) { index, entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.key)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(entry.value)
                            .font(.system(size: 14, weight: .regular, design: .monospaced))
                            .textSelection(.enabled)
                    }

                    if index < filteredEntries.count - 1 {
                        Divider()
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.25))
            )
        }
    }
}

struct TransactionSummaryPopover: View {
    let summary: TransactionViewModel.TransactionSummary
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("\(summary.title) Summary")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .font(.subheadline)
            }

            VStack(alignment: .leading, spacing: 12) {
                SummaryRow(title: "Status", value: summary.status)

                if let statusReason = summary.statusReason, !statusReason.isEmpty {
                    SummaryRow(title: "Status Reason", value: statusReason)
                }

                if let cardBrand = summary.cardBrand, !cardBrand.isEmpty {
                    SummaryRow(title: "Card Brand", value: cardBrand)
                }

                if let card = summary.card, !card.isEmpty {
                    SummaryRow(title: "Card", value: card)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Breakdown")
                    .font(.headline)
                SummaryRow(title: "Subtotal", value: summary.breakdown.subtotal)
                SummaryRow(title: "Tax", value: summary.breakdown.tax)
                SummaryRow(title: "Tip", value: summary.breakdown.tip)
                if let surcharge = summary.breakdown.surcharge {
                    SummaryRow(title: "Surcharge", value: surcharge)
                }
                SummaryRow(title: "Total", value: summary.breakdown.total)
            }

            Spacer(minLength: 0)
        }
        .padding()
        .frame(minWidth: 280, idealWidth: 320)
    }
}

private struct SummaryRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 15, weight: .medium, design: .default))
        }
    }
}

#Preview {
    TransactionView(viewModel: .init(koardMerchantService: .mockMerchantService))
}
