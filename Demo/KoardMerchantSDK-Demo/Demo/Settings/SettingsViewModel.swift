import Foundation
import KoardSDK

@MainActor
@Observable
public final class SettingsViewModel {
    public private(set) var selectedLocation: Location?

    @ObservationIgnored private let koardMerchantService: KoardMerchantServiceable
    @ObservationIgnored public var onLogout: () -> Void

    init(
        koardMerchantService: KoardMerchantServiceable,
        onLogout: @escaping () -> Void
    ) {
        self.koardMerchantService = koardMerchantService
        self.onLogout = onLogout
        self.selectedLocation = koardMerchantService.activeLocation
    }

    public func onAppear() {
        selectedLocation = koardMerchantService.activeLocation

        Task { [weak self] in
            guard let self else { return }
            if let refreshed = await self.koardMerchantService.loadActiveLocation() {
                self.selectedLocation = refreshed
            }
        }
    }

    public func logout() {
        koardMerchantService.logout()
        onLogout()
    }
}
