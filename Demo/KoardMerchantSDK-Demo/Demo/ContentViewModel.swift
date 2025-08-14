import Foundation
import KoardSDK

@MainActor
@Observable
public final class ContentViewModel {
    public private(set) var isAuthenticating: Bool = false
    public private(set) var isPreparingReader: Bool = false
    public private(set) var isAuthenticated: Bool = false
    public private(set) var isReaderReady: Bool = false
    public private(set) var isReaderSetupSupported: Bool = false
    public private(set) var authenticationError: String = ""
    public private(set) var selectedLocation: Location?

    public var navigationDestination: NavigationDestination?
    public var destination: Destination?

    @ObservationIgnored private let koardMerchantService: KoardMerchantServiceable

    public enum NavigationDestination: Identifiable, Hashable {
        public var id: Self { self }
        case sampleTransactionFlow(TransactionViewModel)
    }

    public enum Destination: Identifiable, Hashable {
        public var id: Self { self }
        case locationSelection(LocationSelectionViewModel)
        case transactionHistory(TransactionHistoryViewModel)
    }

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

    public func showLocationSelectionTapped() {
        let viewModel = LocationSelectionViewModel(
            koardMerchantService: koardMerchantService,
            delegate: .init(
                onLocationSelected: { [weak self] location in
                    self?.selectedLocation = location
                    self?.destination = nil
                }
            )
        )
        
        destination = .locationSelection(viewModel)
    }

    public func transactionFlowTapped() {
        let viewModel = TransactionViewModel(koardMerchantService: koardMerchantService)
        navigationDestination = .sampleTransactionFlow(viewModel)
    }
    
    public func transactionHistoryTapped() {
        let viewModel = TransactionHistoryViewModel(koardMerchantService: koardMerchantService)
        destination = .transactionHistory(viewModel)
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
            selectedLocation = koardMerchantService.activeLocation

            // selectedLocation = try await koardMerchantService.setupLocation()
        } catch let merchantError as KoardDescribableError {
            authenticationError = merchantError.errorDescription
        } catch {
            authenticationError = error.localizedDescription
        }
    }

    private func logout() {
        koardMerchantService.logout()
        selectedLocation = nil
        isAuthenticated = false
        isReaderSetupSupported = false
        isReaderReady = false
    }
}
