import KoardSDK
import SwiftUI

struct TransactionView: View {
    @State private var viewModel: TransactionViewModel

    init(viewModel: TransactionViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .lastTextBaseline) {
                Text("Amount")

                DottedLine()
                    .frame(height: 1)
                    .padding(.horizontal, 4)
                    .alignmentGuide(.lastTextBaseline) { $0[.bottom] }

                CurrencyField(value: $viewModel.transactionAmount)
                    .frame(width: 100)
            }

            Toggle("Show Breakdown", isOn: $viewModel.isBreakoutOn)
                .toggleStyle(SwitchToggleStyle(tint: .koardGreen))

            if viewModel.isBreakoutOn {
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

            HStack {
                Text("Total")
                    .font(.system(size: 32, weight: .bold))
                Spacer()
                let amount = viewModel.totalAmount.isEmpty ? "$0.00" : viewModel.totalAmount
                Text(amount)
                    .font(.system(size: 22, weight: .bold))
            }

            Spacer()

            AsyncButton {
                await viewModel.preauthorize()
            } label: {
                Text("Pre-authorize Transaction")
            }
            .buttonStyle(.primary)
            .disabled(viewModel.totalAmountValue == 0 || !viewModel.transactionId.isEmpty)
            .overlay {
                if viewModel.isProcessingSale {
                    ProgressView()
                        .tint(.white)
                }
            }

            Text(viewModel.transactionState.detailString)
                .foregroundStyle(viewModel.transactionState.detailColor)
                .font(.system(size: 12))
                .padding(.bottom, 20)
            
            AsyncButton {
                await viewModel.processTransaction()
            } label: {
                Text("Process Transaction")
            }
            .buttonStyle(.primary)
            .disabled(viewModel.totalAmountValue == 0 || !viewModel.transactionId.isEmpty)
            .padding(.bottom, 20)
            .overlay {
                if viewModel.isProcessingSale {
                    ProgressView()
                        .tint(.white)
                }
            }
        }
        .animation(.default, value: viewModel.isBreakoutOn)
        .padding(20)
        .navigationTitle("Transaction")
        .toolbarRole(.editor)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KoardBackgroundView())
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

#Preview {
    TransactionView(viewModel: .init(koardMerchantService: .mockMerchantService))
}
