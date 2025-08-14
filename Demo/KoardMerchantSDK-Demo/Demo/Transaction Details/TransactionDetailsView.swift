import KoardSDK
import SwiftUI

struct TransactionDetailsView: View {
    @State private var viewModel: TransactionDetailsViewModel
    @State private var showAlert: Bool = false
    @State private var justRefunded: Bool = false
    @Environment(\.dismiss) private var dismiss

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
                        cardInfo: viewModel.transaction.card
                    )
                    .padding(.horizontal, 32.0)

                    VStack(spacing: 12) {
                        TransactionGetReceiptView(viewModel: viewModel)

                        let isRefundable = (viewModel.transaction.status == .authorized || viewModel.transaction.status == .captured) &&
                            viewModel.transaction.status != .refunded &&
                            viewModel.transaction.transactionType != "refund"

                        if justRefunded {
                            Button {
                                // Do nothing - just for visual confirmation
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.white)
                                    Text("Refunded")
                                        .foregroundStyle(.white)
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.koardGreen)
                            .cornerRadius(8)
                            .disabled(true)
                        } else if isRefundable {
                            Button {
                                showAlert = true
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
                    }
                    .padding(.horizontal, 32.0)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            Spacer()
        }
        .alert("Refund \(MoneyUtils.centsToStringWithCurrency(viewModel.transaction.totalAmount))?", isPresented: $showAlert) {
            Button("Refund", role: .cancel) {
                Task {
                    await viewModel.performRefund()
                }
            }
            Button("Cancel", role: .destructive) { }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KoardBackgroundView())
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

#Preview {
    TransactionDetailsView(
        viewModel: .init(
            koardMerchantService: .mockMerchantService,
            transaction: .mockApprovedTransaction,
            delegate: .init(
                onRefundSuccess: { }
            )
        )
    )
}
