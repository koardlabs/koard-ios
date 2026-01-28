import SwiftUI
import KoardSDK

struct TransactionDetailView: View {
    let transaction: KoardTransaction
    @State private var showRawJSON = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Transaction Details")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        HStack {
                            Circle()
                                .fill(statusColor(for: transaction.status))
                                .frame(width: 12, height: 12)
                            
                            Text(transaction.status.rawValue.capitalized)
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                    }
                    
                    Text("$\(String(format: "%.2f", Double(transaction.totalAmount) / 100.0))")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Transaction Info
                VStack(alignment: .leading, spacing: 16) {
                    DetailRow(title: "Transaction ID", value: transaction.transactionId)
                    DetailRow(title: "Card Number", value: transaction.card)
                    DetailRow(title: "Amount", value: "$\(String(format: "%.2f", Double(transaction.totalAmount) / 100.0))")
                    DetailRow(title: "Date", value: transaction.createdAtDate.formatted(date: .abbreviated, time: .complete))
                    DetailRow(title: "Status", value: transaction.status.rawValue.capitalized)
                    
                    if let statusReason = transaction.statusReason {
                        DetailRow(title: "Status Reason", value: statusReason)
                    }
                    
                    if let transactionType = transaction.transactionType {
                        DetailRow(title: "Type", value: transactionType)
                    }
                    

                    DetailRow(title: "Currency", value: transaction.currency)
                    
                    if transaction.tipAmount > 0 {
                        DetailRow(title: "Tip Amount", value: "$\(String(format: "%.2f", Double(transaction.tipAmount) / 100.0))")
                    }
                    
                    if transaction.taxAmount > 0 {
                        DetailRow(title: "Tax Amount", value: "$\(String(format: "%.2f", Double(transaction.taxAmount) / 100.0))")
                    }
                    
                    if transaction.surchargeApplied, transaction.surchargeAmount ?? 0 > 0 {
                        DetailRow(title: "Surcharge", value: "$\(String(format: "%.2f", Double(transaction.surchargeAmount ?? 0) / 100.0))")
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                
                // Raw JSON Toggle
                VStack(alignment: .leading, spacing: 12) {
                    Button {
                        withAnimation {
                            showRawJSON.toggle()
                        }
                    } label: {
                        HStack {
                            Text("Raw Transaction Data")
                                .font(.headline)
                            
                            Spacer()
                            
                            Image(systemName: showRawJSON ? "chevron.up" : "chevron.down")
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                    
                    if showRawJSON {
                        /*ScrollView {
                            Text(transactionJSON)
                                .font(.system(.caption, design: .monospaced))
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        .frame(maxHeight: 300)*/
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Transaction")
        .navigationBarTitleDisplayMode(.inline)
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

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
        }
    }
}

#Preview {
    NavigationView {
        TransactionDetailView(transaction: .mockApprovedTransaction)
    }
}
