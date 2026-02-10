import Foundation
import KoardSDK

@MainActor
@Observable
public final class LoginViewModel {
    public private(set) var isAuthenticating: Bool = false
    public private(set) var authenticationError: String = ""
    public var merchantCode: String = ""
    public var merchantPin: String = ""

    public var canLogin: Bool {
        !merchantCode.trimmingCharacters(in: .whitespaces).isEmpty &&
        !merchantPin.trimmingCharacters(in: .whitespaces).isEmpty
    }

    @ObservationIgnored private let koardMerchantService: KoardMerchantServiceable
    @ObservationIgnored public var onAuthenticationSuccess: () -> Void

    init(
        koardMerchantService: KoardMerchantServiceable,
        onAuthenticationSuccess: @escaping () -> Void
    ) {
        self.koardMerchantService = koardMerchantService
        self.onAuthenticationSuccess = onAuthenticationSuccess
    }

    public func authenticate() async {
        isAuthenticating = true
        authenticationError = ""

        defer {
            isAuthenticating = false
        }

        do {
            try await koardMerchantService.authenticateMerchant(
                code: merchantCode.trimmingCharacters(in: .whitespaces),
                pin: merchantPin.trimmingCharacters(in: .whitespaces)
            )
            onAuthenticationSuccess()
        } catch let merchantError as KoardDescribableError {
            authenticationError = merchantError.errorDescription
        } catch {
            authenticationError = error.localizedDescription
        }
    }
}
