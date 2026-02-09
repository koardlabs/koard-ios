import KoardSDK
import Observation
import SwiftUI

struct TransactionView: View {
    @State private var viewModel: TransactionViewModel
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case amount, taxRate, taxAmount, tipAmount, tipPercentage
        case surchargeAmount, surchargePercentage
    }

    init(viewModel: TransactionViewModel) {
        self.viewModel = viewModel
    }

    private func dismissKeyboard() {
        focusedField = nil
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
                        .focused($focusedField, equals: .amount)
                }

                HStack(alignment: .lastTextBaseline) {
                    Text("Tax")

                    DottedLine()
                        .frame(height: 1)
                        .padding(.horizontal, 4)
                        .alignmentGuide(.lastTextBaseline) { $0[.bottom] }

                    Picker("Options", selection: $viewModel.taxTypeSelection) {
                        ForEach(viewModel.tipTypes, id: \.self) { taxType in
                            Text(taxType.displayName)
                                .tag(taxType)
                        }
                    }
                    .pickerStyle(.segmented)

                    if viewModel.taxTypeSelection == .fixed {
                        CurrencyField(
                            value: $viewModel.taxAmount,
                            placeholder: "8.75"
                        )
                        .frame(width: 100)
                        .focused($focusedField, equals: .taxAmount)
                    } else {
                        PercentageField(
                            value: $viewModel.taxRate,
                            placeholder: "8.75"
                        )
                        .frame(width: 100)
                        .focused($focusedField, equals: .taxRate)
                    }
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
                        .focused($focusedField, equals: .tipAmount)
                    } else {
                        PercentageField(
                            value: $viewModel.tipPercentage,
                            placeholder: "15"
                        )
                        .frame(width: 100)
                        .focused($focusedField, equals: .tipPercentage)
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
                        .focused($focusedField, equals: .surchargeAmount)
                    } else {
                        PercentageField(
                            value: $viewModel.surchargePercentage,
                            placeholder: "3"
                        )
                        .frame(width: 100)
                        .focused($focusedField, equals: .surchargePercentage)
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
                    dismissKeyboard()
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
                    dismissKeyboard()
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
        .contentShape(Rectangle())
        .onTapGesture {
            dismissKeyboard()
        }
        .navigationTitle("Transaction")
        .toolbarRole(.editor)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.showLocationSelection = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                        Text(viewModel.selectedLocationName)
                    }
                    .foregroundColor(.koardGreen)
                }
            }
        }
        .background {
            KoardBackgroundView()
                .ignoresSafeArea()
        }
        .task {
            await viewModel.loadActiveLocation()
        }
        .sheet(isPresented: $viewModel.showLocationSelection) {
            LocationSelectionView(viewModel: viewModel.locationSelectionViewModel)
        }
        .popover(
            item: Binding(
                get: { viewModel.transactionSummary },
                set: { _ in viewModel.clearTransactionSummary() }
            )
        ) { summary in
            TransactionSummaryPopover(summary: summary)
        }
        .fullScreenCover(
            item: Binding(
                get: { viewModel.surchargePrompt },
                set: { viewModel.surchargePrompt = $0 }
            )
        ) { prompt in
            SurchargeConfirmationView(
                viewModel: viewModel,
                prompt: prompt
            )
        }
    }
}


private struct SurchargeConfirmationView: View {
    @Bindable var viewModel: TransactionViewModel
    let prompt: TransactionViewModel.SurchargePrompt

    private var currency: CurrencyCode {
        CurrencyCode(currencyCode: prompt.transaction.currency, displayName: nil)
    }

    private func formatted(_ cents: Int) -> String {
        MoneyUtils.centsToStringWithCurrency(cents, currency: currency)
    }

    private var summary: TransactionViewModel.PendingSurchargeSummary? {
        viewModel.pendingSurchargeSummary()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(prompt.flow.title) Pending Confirmation")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text(prompt.disclosure)
                            .font(.body)
                            .foregroundStyle(.primary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Transaction Summary")
                            .font(.headline)

                        SummaryRow(
                            title: "Status",
                            value: prompt.transaction.status.displayName
                        )

                        SummaryRow(
                            title: "Transaction ID",
                            value: prompt.transaction.transactionId
                        )
                    }

                    if let summary {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Totals")
                                .font(.headline)
                            SummaryRow(
                                title: "Original Amount",
                                value: formatted(summary.baseCents)
                            )
                            SummaryRow(
                                title: summary.isOverride ? "Override Surcharge" : "Surcharge",
                                value: formatted(summary.surchargeCents)
                            )
                            SummaryRow(
                                title: summary.isOverride ? "Override Total" : "Total Amount",
                                value: formatted(summary.totalCents)
                            )
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Override Surcharge", isOn: $viewModel.isPendingSurchargeOverrideOn)
                            .toggleStyle(SwitchToggleStyle(tint: .koardGreen))

                        if viewModel.isPendingSurchargeOverrideOn {
                            Picker("Type", selection: $viewModel.pendingSurchargeTypeSelection) {
                                ForEach(viewModel.tipTypes, id: \.self) { type in
                                    Text(type.displayName)
                                        .tag(type)
                                }
                            }
                            .pickerStyle(.segmented)

                            if viewModel.pendingSurchargeTypeSelection == .fixed {
                                CurrencyField(
                                    value: $viewModel.pendingSurchargeAmount,
                                    placeholder: "2.50"
                                )
                                .frame(width: 140)
                            } else {
                                PercentageField(
                                    value: $viewModel.pendingSurchargePercentage,
                                    placeholder: "3"
                                )
                                .frame(width: 140)
                            }
                        }

                        if viewModel.isPendingSurchargeOverrideOn && !viewModel.canConfirmPendingSurcharge {
                            Text("Enter a valid surcharge before confirming.")
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }

                    if viewModel.isProcessingSale {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Submitting decision…")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(spacing: 12) {
                        Button {
                            Task {
                                await viewModel.handleSurchargeDecision(confirm: false)
                            }
                        } label: {
                            Text("Decline")
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .disabled(viewModel.isProcessingSale)

                        Button {
                            Task {
                                await viewModel.handleSurchargeDecision(confirm: true)
                            }
                        } label: {
                            Text("Confirm")
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.koardGreen)
                        .disabled(viewModel.isProcessingSale || !viewModel.canConfirmPendingSurcharge)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .navigationTitle("\(prompt.flow.title) Review")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        viewModel.surchargePrompt = nil
                    }
                }
            }
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
