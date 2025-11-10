import KoardSDK
import Observation
import SwiftUI

struct TransactionDetailsView: View {
    @State private var viewModel: TransactionDetailsViewModel
    @State private var pendingAction: PendingAction?
    @Environment(\.dismiss) private var dismiss
    
    enum PendingAction: String, Identifiable {
        case refund
        case reverse
        case capture

        var id: String { rawValue }
    }

    init(viewModel: TransactionDetailsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .bold))
                }
                .padding(.horizontal, 32.0)

                Text("ID: \(viewModel.transaction.transactionId)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 32.0)
            }
            .padding(.top, 20)
            .padding(.bottom, 16)

            ScrollView {
                VStack(spacing: 12) {
                    let formattedSurcharge = viewModel.transaction.surchargeApplied ? MoneyUtils.centsToStringWithCurrency(viewModel.transaction.surchargeAmount ?? 0) : MoneyUtils.centsToStringWithCurrency(0)
                    TransactionInfoView(
                        type: viewModel.transaction.transactionTypeDisplayName,
                        status: viewModel.transaction.status,
                        statusReason: viewModel.transaction.statusReason,
                        localizedAmount: MoneyUtils.centsToStringWithCurrency(viewModel.transaction.totalAmount),
                        localizedTip: MoneyUtils.centsToStringWithCurrency(viewModel.transaction.tipAmount),
                        localizedSubTotal: MoneyUtils.centsToStringWithCurrency(viewModel.transaction.subtotal),
                        localizedTax: MoneyUtils.centsToStringWithCurrency(viewModel.transaction.taxAmount),
                        localizedSurchargeAmount: formattedSurcharge,
                        surchargeApplied: viewModel.transaction.surchargeApplied,
                        date: viewModel.transaction.createdAtDate,
                        cardInfo: viewModel.transaction.card,
                        cardBrand: viewModel.transaction.cardBrand
                    )
                    .padding(.horizontal, 32.0)

                    VStack(spacing: 8) {
                        let status = viewModel.transaction.status
                        let transactionType = viewModel.transaction.transactionType?.lowercased()
                        let isRefundable = (status == .authorized || status == .captured) &&
                            status != .refunded &&
                            transactionType != "refund"
                        let canReverse = status == .authorized || status == .captured
                        let canCapture = status == .authorized

                        if isRefundable {
                            Button {
                                pendingAction = .refund
                            } label: {
                                Text("Refund")
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                            .cornerRadius(8)
                        }

                        if canReverse {
                            Button {
                                pendingAction = .reverse
                            } label: {
                                Text("Reverse")
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                            .cornerRadius(8)
                        }

                        if canCapture {
                            Button {
                                pendingAction = .capture
                            } label: {
                                Text("Capture")
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.koardGreen)
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 32.0)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KoardBackgroundView())
        .sheet(item: $pendingAction) { action in
            TransactionAmountActionSheet(
                action: action,
                transaction: viewModel.transaction,
                onDismiss: { pendingAction = nil },
                onPerform: { operationKind, amount in
                    pendingAction = nil
                    viewModel.performOperation(kind: operationKind, amount: amount)
                }
            )
            .presentationDetents(Set([PresentationDetent.medium]))
            .presentationDragIndicator(Visibility.visible)
        }
        .fullScreenCover(item: $viewModel.operationPresentation) { _ in
            OperationStatusView(viewModel: viewModel)
        }
    }
}

/* private struct TransactionDetailsIdView: View {
     let transactionID: String
     @State private var showToast = false

     var body: some View {
         Button(action: {
             UIPasteboard.general.string = transactionID
             withAnimation(.easeInOut(duration: 0.3)) {
                 showToast = true
             }
             // Hide toast after 2 seconds
             DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                 withAnimation(.easeInOut(duration: 0.3)) {
                     showToast = false
                 }
             }
         }) {
             Text("ID: \(transactionID)")
                 .font(.secondaryFont(size: 16))
                 .fontWeight(.w600)
                 .foregroundStyle(R.color.accentColor.color)
                 .lineLimit(1)
                 .truncationMode(.middle)
         }
         .overlay(
             // Toast overlay
             Group {
                 if showToast {
                     Text("Copied to clipboard")
                         .font(.secondaryFont(size: 12))
                         .foregroundColor(.white)
                         .padding(.horizontal, 12)
                         .padding(.vertical, 6)
                         .background(Color.black.opacity(0.8))
                         .cornerRadius(16)
                         .offset(y: -40)
                         .transition(.opacity.combined(with: .move(edge: .top)))
                 }
             }
         )
     }
 }
 */

private struct TransactionAmountActionSheet: View {
    let action: TransactionDetailsView.PendingAction
    let transaction: KoardTransaction
    let onDismiss: () -> Void
    let onPerform: (TransactionDetailsViewModel.OperationKind, Int) -> Void

    @State private var amountText: String
    @Environment(\.dismiss) private var dismiss

    init(
        action: TransactionDetailsView.PendingAction,
        transaction: KoardTransaction,
        onDismiss: @escaping () -> Void,
        onPerform: @escaping (TransactionDetailsViewModel.OperationKind, Int) -> Void
    ) {
        self.action = action
        self.transaction = transaction
        self.onDismiss = onDismiss
        self.onPerform = onPerform
        _amountText = State(initialValue: MoneyUtils.centsToString(transaction.totalAmount))
    }

    private var amountInCents: Int {
        max(0, MoneyUtils.stringToCents(amountText))
    }

    private var amountDisplay: String {
        MoneyUtils.centsToStringWithCurrency(transaction.totalAmount)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text(title)
                    .font(.title3)
                    .bold()

                Text("Amount")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Text(MoneyUtils.symbol())
                        .foregroundStyle(.koardGreen)
                        .font(.system(size: 20, weight: .semibold))
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 22, weight: .semibold))
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )

                Text("Original total: \(amountDisplay)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer()

                actionButtons
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                        onDismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        switch action {
        case .refund:
            VStack(spacing: 12) {
                Button {
                    perform(.refund(useTap: false))
                } label: {
                    Text("Refund")
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(amountInCents <= 0)

                Button {
                    perform(.refund(useTap: true))
                } label: {
                    Text("Refund With Tap")
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(amountInCents <= 0)
            }
            Text("Choose how you want to issue the refund.")
                .font(.footnote)
                .foregroundStyle(.secondary)

        case .reverse:
            VStack(spacing: 12) {
                Button {
                    perform(.reverse)
                } label: {
                    Text("Reverse")
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(amountInCents <= 0)
            }
            Text("Reverse the authorization. Adjust the amount if needed.")
                .font(.footnote)
                .foregroundStyle(.secondary)

        case .capture:
            VStack(spacing: 12) {
                Button {
                    perform(.capture)
                } label: {
                    Text("Capture")
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
                .tint(.koardGreen)
                .disabled(amountInCents <= 0)
            }
            Text("Capture the authorized funds. Edit the amount to make partial captures.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func perform(_ kind: TransactionDetailsViewModel.OperationKind) {
        guard amountInCents > 0 else { return }
        dismiss()
        onDismiss()
        onPerform(kind, amountInCents)
    }

    private var title: String {
        switch action {
        case .refund:
            return "Issue a Refund"
        case .reverse:
            return "Reverse Authorization"
        case .capture:
            return "Capture Authorization"
        }
    }
}

private struct OperationStatusView: View {
    @Bindable var viewModel: TransactionDetailsViewModel

    var body: some View {
        ZStack {
            KoardBackgroundView()
                .ignoresSafeArea()

            if let presentation = viewModel.operationPresentation {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            viewModel.dismissOperation()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 16)
                        .padding(.trailing, 16)
                    }

                    Spacer()

                    content(for: presentation)
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .padding(.horizontal, 24)

                    Spacer()
                }
            }
        }
    }

    @ViewBuilder
    private func content(for presentation: TransactionDetailsViewModel.OperationPresentation) -> some View {
        let amount = MoneyUtils.centsToStringWithCurrency(presentation.amount, currency: presentation.currency)

        switch presentation.phase {
        case .processing:
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.koardGreen)
                    .scaleEffect(1.4)

                Text(presentation.kind.progressMessage)
                    .font(.title3)
                    .bold()

                Text("Amount: \(amount)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

        case .success(let response):
            let displayTransaction = response.transaction ?? viewModel.transaction
            let statusText = displayTransaction.status.displayTitle
            let transactionId = response.transaction?.transactionId ?? response.transactionId ?? displayTransaction.transactionId
            let processorMessage = response.transaction?.statusReason ?? response.statusReason ?? response.processorResponseMessage

            VStack(spacing: 16) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.koardGreen)

                Text("\(presentation.kind.title) Completed")
                    .font(.title2)
                    .bold()

                VStack(spacing: 6) {
                    Text("Status: \(statusText)")
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text("Amount: \(amount)")
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text("Transaction ID: \(transactionId)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if let processorMessage, !processorMessage.isEmpty {
                        Text(processorMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)

                Button {
                    viewModel.dismissOperation()
                } label: {
                    Text("Done")
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
                .tint(.koardGreen)
            }

        case .failure(let errorMessage):
            VStack(spacing: 16) {
                Image(systemName: "xmark.octagon.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.red)

                Text("Unable to Complete")
                    .font(.title2)
                    .bold()

                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    viewModel.dismissOperation()
                } label: {
                    Text("Dismiss")
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
    }
}

private extension KoardTransaction.Status {
    var displayTitle: String {
        rawValue
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}

#Preview {
    TransactionDetailsView(
        viewModel: .init(
            koardMerchantService: .mockMerchantService,
            transaction: .mockApprovedTransaction,
            delegate: .init(
                onTransactionUpdate: { }
            )
        )
    )
}
