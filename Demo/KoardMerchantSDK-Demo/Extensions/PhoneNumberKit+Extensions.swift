import PhoneNumberKit
import SwiftUI
import UIKit

extension PhoneNumberUtility {
    public static let allRegions: [Region] = PhoneNumberUtility().allCountries().map { Region(regionCode: $0) }

    public static let defaultRegion: Region = PhoneNumberUtility.allRegions.first(where: { $0.id == PhoneNumberUtility.defaultRegionCode() })!

    public struct Region: Identifiable, Hashable {
        public let id: String
        public let countryCode: UInt64
        public let countryName: String
        public let flagUnicode: String

        public init(regionCode: String) {
            id = regionCode
            countryCode = PhoneNumberUtility().countryCode(for: regionCode) ?? 0
            countryName = Locale.autoupdatingCurrent.localizedString(forRegionCode: regionCode) ?? ""
            flagUnicode = regionCode.uppercased().unicodeScalars.compactMap { UnicodeScalar(UInt32(127397) + $0.value)?.description }.joined()
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }
}
