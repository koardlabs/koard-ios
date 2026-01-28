import UIKit

extension String {
    public var isValidEmail: Bool {
        let emailRegEx = ".+@.+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: self)
    }

    public func isPhoneNumber() -> Bool {
        return isOfType(type: .phoneNumber)
    }

    public func isDate() -> Bool {
        return isOfType(type: .date)
    }

    public func isAddress() -> Bool {
        return isOfType(type: .address)
    }

    public func isOfType(type: NSTextCheckingResult.CheckingType) -> Bool {
        do {
            let detector = try NSDataDetector(types: type.rawValue)
            let matches = detector.matches(in: self, options: [], range: NSMakeRange(0, count))

            if let firstMatch = matches.first {
                return firstMatch.resultType == type && firstMatch.range.location == 0 && firstMatch.range.length == count
            } else {
                return false
            }
        } catch {
            return false
        }
    }
}
