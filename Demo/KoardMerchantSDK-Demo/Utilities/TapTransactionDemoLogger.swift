import Foundation

enum DemoTapTransactionLogger {
    static func logShownOnScreen() {
        print("[KoardSDK] [TapTransaction] demo -- Shown on Screen \(currentGMTTime())")
    }

    static func logSummaryPresented(title: String, transactionId: String?) {
        let txn = (transactionId?.isEmpty == false ? transactionId! : "unknown-tx")
        print("[KoardSDK] [TapTransaction] demo -- \(title) summary presented for tx:\(txn) at \(currentGMTTime())")
    }

    static func logSceneFocusChange(_ description: String) {
        print("[KoardSDK] [TapTransaction] demo -- View focus change: \(description) at \(currentGMTTime())")
    }

    private static func currentGMTTime() -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "HH:mm:ss.SSS 'GMT'"
        return formatter.string(from: Date())
    }
}
