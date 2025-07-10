import Foundation
import KoardSDK

@MainActor
@Observable
public final class ContentViewModel {
    public private(set) var isAuthenticating: Bool = false
    public private(set) var isPreparingReader: Bool = false
    public private(set) var isFetchingTransactions: Bool = false
    public private(set) var isProcessingSale: Bool = false
    public private(set) var isAuthenticated: Bool = false
    public private(set) var isReaderReady: Bool = false
    public private(set) var isReaderSetupSupported: Bool = false
    public private(set) var authenticationError: String = ""

    @ObservationIgnored private let koardMerchantService: KoardMerchantServiceable

    init(koardMerchantService: KoardMerchantServiceable) {
        self.koardMerchantService = koardMerchantService
    }

    public func onAppear() {
        isAuthenticated = koardMerchantService.isAuthenticated
        isReaderSetupSupported = koardMerchantService.isReaderSetupSupported
    }

    public func authenticateMerchantButtonTapped() async {
        if isAuthenticated {
            logout()
        } else {
            await authenticateMerchant()
        }
    }

    public func setupReader() async {
        isPreparingReader = true

        defer {
            isPreparingReader = false
        }

        do {
            try await koardMerchantService.prepareCardReader()
            isReaderReady = true
        } catch {
            // Handle any errors that occur during reader setup
            print(error)
        }
    }

    public func getTransactions() async {
        isFetchingTransactions = true

        defer {
            isFetchingTransactions = false
        }

        do {
            let transctions = try await koardMerchantService.getTransactionHistory(
                startDate: Date().addingTimeInterval(-86400 * 7), // Last 7 days
                endDate: Date(), // Up to now
                statuses: [.approved, .declined],
                types: [.sale, .refund],
                minAmount: 100, // $1.00
                maxAmount: 10000, // $100.00
                limit: 50
            )

            print(transctions)
        } catch {
            // Handle any errors that occur during reader setup
            print(error)
        }
    }

    public func processSale() async {
        isProcessingSale = true

        defer {
            isProcessingSale = false
        }

        do {
            // Sample sale processing with fixed tip
            let transaction = try await koardMerchantService.processSale(
                subtotal: 1000,
                taxRate: 8.75,
                tipAmount: 100,
                tipType: .fixed
            )

            switch transaction.status {
            case .approved:
                print("Payment approved: \(transaction.transactionId)")
            case .surchargePending:
                // Handle surcharge confirmation
                let confirmed = try await koardMerchantService.transactionConfirmed(
                    transactionId: transaction.transactionId,
                    confirm: true
                )
                
                print("Surcharge confirmed, final status: \(confirmed.status)")
            case .declined:
                print("Payment declined: \(transaction.statusReason ?? "Unknown reason")")
            default:
                print("Payment status: \(transaction.status)")
            }

        } catch let error as KoardDescribableError {
            print(error.errorDescription)
        } catch {
            print(error.localizedDescription)
        }
    }
}

extension ContentViewModel {
    private func authenticateMerchant() async {
        isAuthenticating = true

        defer {
            isAuthenticating = false
        }

        do {
            try await koardMerchantService.authenticateMerchant()
            isAuthenticated = true
            isReaderSetupSupported = koardMerchantService.isReaderSetupSupported
        } catch let merchantError as KoardDescribableError {
            authenticationError = merchantError.errorDescription
        } catch {
            authenticationError = error.localizedDescription
        }
    }

    private func logout() {
        koardMerchantService.logout()
        isAuthenticated = false
        isReaderSetupSupported = false
        isReaderReady = false
    }
}
