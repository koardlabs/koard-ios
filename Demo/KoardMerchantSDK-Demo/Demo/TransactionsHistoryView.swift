import SwiftUI
import KoardSDK

struct TransactionsHistoryView: View {
    @State private var viewModel: TransactionsHistoryViewModel
    @State private var actionState: TransactionActionState?
    @State private var isActionSheetPresented: Bool = false
    @State private var actionAlertMessage: String?
    
    init(koardMerchantService: KoardMerchantServiceable) {
        self.viewModel = TransactionsHistoryViewModel(koardMerchantService: koardMerchantService)
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    VStack {
                        ProgressView()
                        Text("Loading transactions...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if viewModel.transactions.isEmpty {
                    VStack {
                        Image(systemName: "doc.text")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No transactions found")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("Transactions will appear here after you process payments")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List(viewModel.transactions, id: \.transactionId) { transaction in
                        NavigationLink(destination: TransactionDetailView(transaction: transaction)) {
                            TransactionRowView(transaction: transaction)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if transaction.status == .authorized {
                                Button {
                                    presentAction(.reverse, for: transaction)
                                } label: {
                                    Label("Reverse", systemImage: "arrow.uturn.backward")
                                }
                                .tint(.red)

                                Button {
                                    presentAction(.incrementalAuth, for: transaction)
                                } label: {
                                    Label("Auth +", systemImage: "plus.circle")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                    .refreshable {
                        await viewModel.loadTransactions()
                    }
                }
            }
            .navigationTitle("Transaction History")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                Task {
                    await viewModel.loadTransactions()
                }
            }
            .alert(
                "Error",
                isPresented: Binding(
                    get: { !viewModel.errorMessage.isEmpty },
                    set: { if !$0 { viewModel.errorMessage = "" } }
                )
            ) {
                Button("OK") {
                    viewModel.errorMessage = ""
                }
            } message: {
                Text(viewModel.errorMessage)
            }
            .sheet(isPresented: $isActionSheetPresented, onDismiss: { actionState = nil }) {
                if actionState != nil {
                    TransactionActionSheet(
                        state: Binding(
                            get: { actionState! },
                            set: { actionState = $0 }
                        ),
                        onConfirm: handleActionConfirmation,
                        onDismiss: {
                            isActionSheetPresented = false
                        }
                    )
                } else {
                    EmptyView()
                }
            }
            .alert(
                "Action Unavailable",
                isPresented: Binding(
                    get: { actionAlertMessage != nil },
                    set: { if !$0 { actionAlertMessage = nil } }
                )
            ) {
                Button("OK") {
                    actionAlertMessage = nil
                }
            } message: {
                Text(actionAlertMessage ?? "")
            }
        }
    }
}

private extension TransactionsHistoryView {
    func presentAction(_ kind: TransactionActionState.Kind, for transaction: KoardTransaction) {
        guard let authorizedAmount = viewModel.authorizedAmount(for: transaction), authorizedAmount > 1 else {
            actionAlertMessage = "Authorized amount details are unavailable for this transaction."
            return
        }

        let maximum = viewModel.maximumActionAmount(for: transaction) ?? max(authorizedAmount - 1, 0)

        guard maximum > 0 else {
            actionAlertMessage = "Authorized amount is too small to adjust."
            return
        }

        actionState = TransactionActionState(
            kind: kind,
            transaction: transaction,
            authorizedAmountCents: authorizedAmount,
            amountInput: CurrencyFormatterHelper.format(cents: maximum)
        )

        isActionSheetPresented = true
    }

    func handleActionConfirmation(amount: Int) {
        guard let currentAction = actionState else { return }

        Task {
            let result: Result<TransactionResponse, Error>

            switch currentAction.kind {
            case .reverse:
                result = await viewModel.performReverse(for: currentAction.transaction, amount: amount)
            case .incrementalAuth:
                result = await viewModel.performIncrementalAuth(for: currentAction.transaction, amount: amount)
            }

            await MainActor.run {
                guard actionState != nil else { return }

                switch result {
                case let .success(response):
                    actionState?.response = response
                    actionState?.errorMessage = ""
                case let .failure(error):
                    actionState?.errorMessage = error.localizedDescription
                }

                actionState?.isSubmitting = false
            }
        }
    }
}

private struct TransactionActionState: Identifiable {
    enum Kind: String {
        case reverse
        case incrementalAuth

        var title: String {
            switch self {
            case .reverse: "Reverse Authorization"
            case .incrementalAuth: "Incremental Authorization"
            }
        }

        var prompt: String {
            switch self {
            case .reverse:
                "Enter the amount to reverse. It must be less than the authorized total."
            case .incrementalAuth:
                "Enter the additional amount to authorize. It must be less than the authorized total."
            }
        }
    }

    let kind: Kind
    let transaction: KoardTransaction
    let authorizedAmountCents: Int
    var amountInput: String
    var isSubmitting: Bool = false
    var errorMessage: String = ""
    var response: TransactionResponse?

    var id: String {
        "\(transaction.transactionId)-\(kind.rawValue)"
    }

    var title: String { kind.title }

    var prompt: String { kind.prompt }

    var maxAmountCents: Int {
        max(authorizedAmountCents - 1, 0)
    }

    var hasResponse: Bool {
        response != nil
    }

    var confirmButtonTitle: String {
        hasResponse ? "Done" : "Confirm"
    }
}

private struct TransactionActionSheet: View {
    @Binding var state: TransactionActionState
    let onConfirm: (Int) -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(state.title)
                    .font(.title3)
                    .fontWeight(.semibold)

                Text(state.prompt)
                    .font(.footnote)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Authorized amount: \(CurrencyFormatterHelper.format(cents: state.authorizedAmountCents))")
                        .font(.footnote)
                        .foregroundColor(.secondary)

                    Text("Maximum allowed: \(CurrencyFormatterHelper.format(cents: state.maxAmountCents))")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                if !state.hasResponse {
                    TextField("Amount", text: $state.amountInput)
                        .keyboardType(.decimalPad)
                        .disabled(state.isSubmitting || state.maxAmountCents <= 0)
                        .textFieldStyle(.roundedBorder)
                }

                if !state.errorMessage.isEmpty {
                    Text(state.errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                }

                if state.isSubmitting {
                    HStack {
                        ProgressView()
                        Text("Processing...")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }

                if let response = state.response {
                    TransactionResponseSummaryView(response: response)
                }

                Spacer()

                HStack {
                    Button("Cancel") {
                        onDismiss()
                    }

                    Spacer()

                    Button(state.confirmButtonTitle) {
                        if state.hasResponse {
                            onDismiss()
                        } else {
                            submit()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(state.isSubmitting || (state.maxAmountCents <= 0 && !state.hasResponse))
                }
            }
            .padding()
        }
    }

    private func submit() {
        guard !state.isSubmitting else { return }

        guard let amount = CurrencyFormatterHelper.parse(state.amountInput) else {
            state.errorMessage = "Enter a valid amount."
            return
        }

        guard amount > 0 else {
            state.errorMessage = "Amount must be greater than zero."
            return
        }

        guard amount <= state.maxAmountCents else {
            state.errorMessage = "Amount must be less than \(CurrencyFormatterHelper.format(cents: state.authorizedAmountCents))."
            return
        }

        state.errorMessage = ""
        state.isSubmitting = true
        onConfirm(amount)
    }
}

private struct TransactionResponseSummaryView: View {
    let response: TransactionResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Response")
                .font(.headline)

            if let status = response.status {
                responseRow(title: "Status", value: status.capitalized)
            }

            if let reason = response.statusReason, !reason.isEmpty {
                responseRow(title: "Reason", value: reason)
            }

            if let transactionId = response.transactionId {
                responseRow(title: "Transaction ID", value: transactionId)
            }

            if let total = response.totalAmount {
                responseRow(title: "Total Amount", value: CurrencyFormatterHelper.format(cents: total))
            }

            if let created = response.createdAtDate {
                responseRow(
                    title: "Created",
                    value: created.formatted(date: .abbreviated, time: .shortened)
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func responseRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .multilineTextAlignment(.trailing)
        }
    }
}

private enum CurrencyFormatterHelper {
    static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale.current
        return formatter
    }()

    static func format(cents: Int) -> String {
        let amount = Double(cents) / 100.0
        return formatter.string(from: NSNumber(value: amount)) ?? String(format: "$%.2f", amount)
    }

    static func parse(_ value: String) -> Int? {
        let currencySymbol = formatter.currencySymbol ?? ""
        let groupingSeparator = formatter.groupingSeparator ?? ","
        let decimalSeparator = formatter.decimalSeparator ?? "."

        var sanitized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized = sanitized.replacingOccurrences(of: currencySymbol, with: "")
        sanitized = sanitized.replacingOccurrences(of: groupingSeparator, with: "")
        sanitized = sanitized.replacingOccurrences(of: " ", with: "")

        if decimalSeparator != "." {
            sanitized = sanitized.replacingOccurrences(of: decimalSeparator, with: ".")
        }

        guard !sanitized.isEmpty, let decimal = Decimal(string: sanitized) else {
            return nil
        }

        var valueDecimal = decimal * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &valueDecimal, 0, .plain)

        return NSDecimalNumber(decimal: rounded).intValue
    }
}

struct TransactionRowView: View {
    let transaction: KoardTransaction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(transaction.card)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("$\(String(format: "%.2f", Double(transaction.totalAmount) / 100.0))")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            HStack {
                Text(transaction.createdAtDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack {
                    Circle()
                        .fill(statusColor(for: transaction.status))
                        .frame(width: 8, height: 8)
                    
                    Text(transaction.status.rawValue.capitalized)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            
            if let statusReason = transaction.statusReason {
                Text(statusReason)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding(.vertical, 4)
    }
    
    private func statusColor(for status: KoardTransaction.Status) -> Color {
        switch status {
        case .captured, .authorized:
            return .green
        case .declined, .error:
            return .red
        case .pending, .surchargePending:
            return .orange
        case .reversed:
            return .blue
        case .refunded:
            return .purple
        @unknown default:
            return .gray
        }
    }
}

#Preview {
    TransactionsHistoryView(koardMerchantService: .mockMerchantService)
}
