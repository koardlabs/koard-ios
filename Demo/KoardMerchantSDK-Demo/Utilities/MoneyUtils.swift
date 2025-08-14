import Foundation
import KoardSDK

struct MoneyUtils {
    static func symbol(_ currency: CurrencyCode? = nil) -> String {
        if let currencyCode = currency?.currencyCode {
            switch currencyCode.uppercased() {
            case "USD":
                return "$"
            default:
                return "$"
            }
        }
        return "$"
    }

    static func centsToStringWithCurrency(_ value: Int, currency: CurrencyCode? = nil) -> String {
        symbol(currency) + centsToString(value)
    }

    static func centsToString(_ value: Int) -> String {
        String(format: "%.2f", Double(value) / 100)
    }

    static func centsToDigits(_ value: Int) -> String {
        String(value)
    }

    static func digitsToCents(_ digits: String) -> Int {
        Int(digits) ?? 0
    }

    static func stringToCents(_ stringValue: String) -> Int {
        Double(stringValue)?.inCents ?? 0
    }

    static func applying(taxRate: Int, tipsValue: Int, to value: Int) -> Int {
        value + value.applying(rate: taxRate) + tipsValue
    }
}

extension Int {
    var inMoney: Double {
        Double(self) / 100
    }

    func applying(rate: Int) -> Int {
        Int((Double(rate * self) / 100).rounded())
    }
}

extension Double {
    var inCents: Int {
        Int((100 * self).rounded())
    }
}
