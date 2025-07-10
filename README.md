# KoardMerchantSDK

KoardSDK is a lightweight, modern SDK designed for iOS apps to enable Tap to Pay functionality, merchant authentication, transaction processing, location management, and digital receipt delivery.

Built with Swift and modularized using Swift Package Manager, KoardSDK provides flexible distribution options including Swift Package, CocoaPods, and XCFramework.

---

## 🚀 Features

- ✅ Tap to Pay support using Apple’s Proximity Reader APIs
- 🔐 Merchant login and token handling
- 💳 Sale, refund, capture, reverse, and pre-auth transactions
- 🧾 Receipt delivery via email or SMS
- 🔁 Fallback payment links for browser-based checkout
- 📍 Multi-location merchant support
- 🧪 Written with modern `@Test`-based Swift Testing (iOS 17+)
- 📦 Distributed via SPM, CocoaPods, or as a binary XCFramework

---

## 📦 Installation

### 🔹 Swift Package Manager (Recommended)

Add this to your `Package.swift`:

```swift
.package(url: "https://github.com/koardlabs/koard-sdk.git", from: "1.0.0")
```

Then add `KoardSDK` as a dependency in your target.

### 🔹 Manual Installation (.xcframework)

1. Go to the [Releases](https://github.com/koardlabs/koardsdk-ios/releases) page
2. Download `KoardSDK.xcframework.zip`
3. Unzip and drag `KoardSDK.xcframework` into your Xcode project
4. In your target’s **General > Frameworks, Libraries & Embedded Content**, select "Embed & Sign"
5. Import it in your code:

```swift
import KoardSDK
```

---

## 📚 Documentation

This SDK uses DocC to generate rich developer documentation.

Full SDK documentation can be found here: [KoardSDK Documentation](https://koardlabs.github.io/koard-ios/documentation/koardsdk/index.html).

### To preview in Xcode:

1. Open `Package.swift` in Xcode (not the `.xcodeproj`)
2. From the menu, select: **Product > Build Documentation**
3. Or Option-click on any symbol to view its documentation

You can also find grouped API overviews in:
```
Sources/KoardSDK/KoardSDK.docc/KoardSDK.md
```

---

## 🧪 Running Tests

Unit tests are written using Swift Testing (iOS 17+).

```bash
swift test
```

Or press **⌘U** in Xcode after opening `Package.swift`.

---

## KoardMerchantSDK Usage Guide

This comprehensive guide covers everything you need to know about integrating and using the KoardMerchantSDK in your iOS application.

### Overview

The KoardMerchantSDK provides a complete payment processing solution for iOS mPOS applications, including:
- **Tap to Pay** functionality using Apple's ProximityReader framework
- **Card reader session management** with automatic token handling
- **Transaction processing** (sales, preauthorizations, refunds, reversals)
- **Location management** for multi-location merchants
- **Real-time transaction monitoring** and history

### Key Concepts

#### 1. Authentication Tokens
The SDK manages several types of tokens automatically:
- **API Key**: Your merchant API key for Koard services
- **Login Token (JWT)**: Obtained after successful merchant login, used for API authentication
- **Card Reader Token**: Apple's ProximityReader token for Tap to Pay functionality

#### 2. Card Reader Sessions
The SDK handles Apple's ProximityReader lifecycle:
- **Preparation**: Refreshes tokens and prepares the reader for transactions
- **Transaction Processing**: Manages card reading and data collection
- **Session Management**: Handles background/foreground transitions automatically

#### 3. Location Management
Multi-location merchants must set an active location before processing payments:
- Retrieve available locations after login
- Set the active location for all subsequent transactions
- Location data is persisted across app sessions

### Complete Implementation Guide

#### Step 1: SDK Initialization

Initialize the SDK early in your app lifecycle (typically in `AppDelegate` or `SceneDelegate`):

```swift
import KoardMerchantSDK

class AppDelegate: UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Configure SDK options
        let options = KoardOptions(
            environment: .uat,           // or .production
            loggingLevel: .debug         // .debug, .info, .warning, .error, .none
        )
        
        // Initialize with your API key
        KoardMerchantSDK.shared.initialize(
            options: options, 
            apiKey: "your-koard-api-key"
        )
        
        return true
    }
}
```

#### Step 2: Merchant Authentication

Before processing any payments, authenticate the merchant:

```swift
private func authenticateMerchant() async throws {
    do {
        // Login with merchant credentials
        try await KoardMerchantSDK.shared.login(
            code: "your-merchant-code",
            pin: "your-merchant-pin"
        )
        
        print("Merchant authenticated successfully")
        
        // After login, set up location
        try await setupLocation()
        
    } catch {
        print("Authentication failed: \(error)")
        throw error
    }
}
```

#### Step 3: Location Setup

Retrieve and set the active location:

```swift
private func setupLocation() async throws {
    do {
        // Get available locations
        let locations = try await KoardMerchantSDK.shared.locations()
        
        guard !locations.isEmpty else {
            throw PaymentError.noLocationsAvailable
        }
        
        // For single location merchants, use the first location
        let activeLocation = locations.first!
        
        // For multi-location merchants, let user select
        // let activeLocation = userSelectedLocation
        
        // Set the active location
        KoardMerchantSDK.shared.setActiveLocationID(activeLocation.id)
        
        print("Active location set: \(activeLocation.name)")
        
    } catch {
        print("Location setup failed: \(error)")
        throw error
    }
}
```

#### Step 4: Card Reader Preparation

Before accepting payments, prepare the card reader:

```swift
private func prepareCardReader() async throws {
    do {
        // Check if account is linked (required for Tap to Pay)
        let isLinked = try await KoardMerchantSDK.shared.isAccountLinked()
        
        if !isLinked {
            // Link the merchant account to Apple Pay
            KoardMerchantSDK.shared.linkAccount()
            
            // Wait for linking to complete
            // This typically requires user interaction
            return
        }
        
        // Prepare the card reader session
        try await KoardMerchantSDK.shared.prepare()
        
        print("Card reader prepared and ready")
        
        // Optional: Monitor reader status
        monitorReaderStatus()
        
    } catch {
        print("Card reader preparation failed: \(error)")
        throw error
    }
}

private func monitorReaderStatus() {
    Task {
        // Monitor reader events
        for await event in KoardMerchantSDK.shared.readerEvents {
            DispatchQueue.main.async {
                self.handleReaderEvent(event)
            }
        }
    }
}

private func handleReaderEvent(_ event: PaymentCardReader.Event) {
    switch event {
    case .readyForTap:
        print("Ready for tap")
    case .cardDetected:
        print("Card detected")
    case .readCompleted:
        print("Card read completed")
    case .readCancelled:
        print("Card read cancelled")
    default:
        print("Reader event: \(event.description)")
    }
}
```

#### Step 5: Processing Transactions

##### Sale Transaction

```swift
private func processSale() async throws {
    // Create payment breakdown (optional)
    let breakdown = PaymentBreakdown(
        subtotal: 1000,        // $10.00 in cents
        taxRate: 875,          // 8.75% (8.75 * 100)
        taxAmount: 88,         // $0.88 in cents
        tipAmount: 200,        // $2.00 in cents
        tipType: .fixed        // or .percentage
    )
    
    // Create currency
    let currency = CurrencyCode(currencyCode: "USD", displayName: "US Dollar")
    
    // Optional: Generate UUID4 for idempotency (prevents duplicate transactions)
    let customTransactionId = UUID().uuidString
    
    do {
        // Process the sale
        let response = try await KoardMerchantSDK.shared.sale(
            amount: 1288,              // Total amount in cents
            breakdown: breakdown,       // Optional breakdown
            currency: currency,
            transactionId: customTransactionId,  // Optional: Use for idempotency. If nil, Koard generates one
            type: .sale                // Transaction type
        )
        
        // Handle the response
        try await handleTransactionResponse(response)
        
    } catch {
        print("Sale failed: \(error)")
        throw error
    }
}
```

##### Preauthorization Transaction

```swift
private func processPreauth() async throws {
    let currency = CurrencyCode(currencyCode: "USD", displayName: "US Dollar")
    
    // Optional: Generate UUID4 for idempotency (prevents duplicate transactions)
    let customTransactionId = UUID().uuidString
    
    do {
        // Process preauthorization (no breakdown needed)
        let response = try await KoardMerchantSDK.shared.preauth(
            amount: 1000,                        // Amount to preauthorize in cents
            currency: currency,
            transactionId: customTransactionId   // Optional: Use for idempotency. If nil, Koard generates one
        )
        
        print("Preauth successful: \(response.transactionId ?? "Unknown")")
        
        // Store transaction ID for later capture/reverse
        UserDefaults.standard.set(response.transactionId, forKey: "lastPreauthId")
        
    } catch {
        print("Preauth failed: \(error)")
        throw error
    }
}
```

##### Handling Transaction Responses

```swift
private func handleTransactionResponse(_ response: TransactionResponse) async throws {
    guard let transaction = response.transaction else {
        throw PaymentError.invalidResponse
    }
    
    switch transaction.status {
    case .approved:
        print("Transaction approved!")
        print("Transaction ID: \(transaction.transactionId)")
        print("Amount: $\(Double(transaction.totalAmount) / 100.0)")
        
    case .surchargePending:
        print("Surcharge pending - customer approval required")
        
        // Show surcharge disclosure to customer
        if let disclosure = transaction.surchargeDisclosure {
            let approved = try await showSurchargeDisclosure(disclosure)
            
            // Confirm or deny the surcharge
            let confirmedTransaction = try await KoardMerchantSDK.shared.confirm(
                transaction: transaction.transactionId,
                confirm: approved
            )
            
            print("Final transaction status: \(confirmedTransaction.status)")
        }
        
    case .declined:
        print("Transaction declined: \(transaction.statusReason ?? "Unknown reason")")
        
    case .error:
        print("Transaction error: \(transaction.statusReason ?? "Unknown error")")
        
    default:
        print("Transaction status: \(transaction.status.string)")
    }
}

private func showSurchargeDisclosure(_ disclosure: String) async throws -> Bool {
    // Show disclosure to customer and get their approval
    // This should be implemented based on your UI requirements
    return await withCheckedContinuation { continuation in
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "Surcharge Notice",
                message: disclosure,
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Accept", style: .default) { _ in
                continuation.resume(returning: true)
            })
            
            alert.addAction(UIAlertAction(title: "Decline", style: .cancel) { _ in
                continuation.resume(returning: false)
            })
            
            // Present alert (you'll need to implement this based on your view hierarchy)
            // self.present(alert, animated: true)
        }
    }
}
```

#### Step 6: Transaction Management

##### Refund a Transaction

```swift
private func processRefund(transactionId: String, amount: Int? = nil) async throws {
    do {
        let response = try await KoardMerchantSDK.shared.refund(
            transactionId: transactionId,
            amount: amount  // nil for full refund
        )
        
        print("Refund successful: \(response.transactionId ?? "Unknown")")
        
    } catch {
        print("Refund failed: \(error)")
        throw error
    }
}
```

##### Reverse a Preauthorization

```swift
private func reversePreauth(transactionId: String, amount: Int? = nil) async throws {
    do {
        let response = try await KoardMerchantSDK.shared.reverse(
            transactionId: transactionId,
            amount: amount  // nil for full reversal
        )
        
        print("Reversal successful: \(response.transactionId ?? "Unknown")")
        
    } catch {
        print("Reversal failed: \(error)")
        throw error
    }
}
```

##### Incremental Authorization

Authorize additional amounts on an existing transaction:

```swift
private func incrementalAuth(transactionId: String, additionalAmount: Int) async throws {
    // Optional: Add breakdown for the additional amount
    let breakdown = PaymentBreakdown(
        subtotal: additionalAmount,
        taxRate: 875,          // 8.75%
        taxAmount: Int(Double(additionalAmount) * 0.0875),
        tipAmount: 0,
        tipType: .fixed
    )
    
    do {
        let response = try await KoardMerchantSDK.shared.auth(
            transactionId: transactionId,
            amount: additionalAmount,
            breakdown: breakdown  // Optional
        )
        
        print("Incremental auth successful: \(response.transactionId ?? "Unknown")")
        
    } catch {
        print("Incremental auth failed: \(error)")
        throw error
    }
}
```

##### Capture a Transaction

Capture a previously authorized transaction:

```swift
private func captureTransaction(transactionId: String, finalAmount: Int? = nil) async throws {
    // Optional: Update breakdown with final tip amount
    let finalBreakdown = PaymentBreakdown(
        subtotal: 1000,        // $10.00
        taxRate: 875,          // 8.75%
        taxAmount: 88,         // $0.88
        tipAmount: 300,        // $3.00 final tip
        tipType: .fixed
    )
    
    do {
        let response = try await KoardMerchantSDK.shared.capture(
            transactionId: transactionId,
            amount: finalAmount,      // nil to capture full authorized amount
            breakdown: finalBreakdown // Optional: updated breakdown with final tip
        )
        
        print("Capture successful: \(response.transactionId ?? "Unknown")")
        
    } catch {
        print("Capture failed: \(error)")
        throw error
    }
}
```

#### Step 7: Transaction History

```swift
private func getTransactionHistory() async throws {
    do {
        // Get recent transactions
        let history = try await KoardMerchantSDK.shared.transactionHistory()
        
        print("Found \(history.transactions.count) transactions")
        
        // Filter by status
        let approvedTransactions = try await KoardMerchantSDK.shared.transactionsByStatus("approved")
        
        // Search transactions
        let searchResults = try await KoardMerchantSDK.shared.searchTransactions("card_number_here")
        
        // Advanced filtering
        let filteredTransactions = try await KoardMerchantSDK.shared.searchTransactionsAdvanced(
            startDate: Date().addingTimeInterval(-86400 * 7), // Last 7 days
            endDate: Date(),
            statuses: ["approved", "declined"],
            types: ["sale", "refund"],
            minAmount: 100,  // $1.00
            maxAmount: 10000, // $100.00
            limit: 50
        )
        
    } catch {
        print("Transaction history failed: \(error)")
        throw error
    }
}
```

#### Step 8: Error Handling

```swift
private func handleSDKError(_ error: Error) {
    if let koardError = error as? KoardMerchantSDKError {
        switch koardError {
        case .missingLocationID:
            print("No active location set")
            // Prompt user to select location
            
        case .missingMerchantCode:
            print("Merchant not authenticated")
            // Redirect to login
            
        case .TTPPaymentFailed(let ttpError):
            print("Tap to Pay error: \(ttpError)")
            // Handle specific TTP errors
            
        default:
            print("Koard SDK error: \(koardError)")
        }
    } else {
        print("General error: \(error)")
    }
}
```

#### Step 9: Session Management

```swift
private func handleAppLifecycle() {
    // The SDK automatically handles background/foreground transitions
    // But you can monitor the status if needed
    
    NotificationCenter.default.addObserver(
        forName: UIApplication.didBecomeActiveNotification,
        object: nil,
        queue: .main
    ) { _ in
        Task {
            // Check if card reader needs re-preparation
            if KoardMerchantSDK.shared.status != .ready {
                try? await self.prepareCardReader()
            }
        }
    }
}
```

#### Step 10: Logout and Cleanup

```swift
private func logout() {
    // Clear all session data
    KoardMerchantSDK.shared.logout()
    
    // Clear any stored transaction IDs
    UserDefaults.standard.removeObject(forKey: "lastPreauthId")
    
    print("Logged out successfully")
    
    // Redirect to login screen
}
```

### Complete Payment Workflows

#### Preauth → Capture Workflow

This is the recommended flow for restaurants and hospitality where tip amounts are added after authorization:

```swift
private func preauthCaptureWorkflow() async throws {
    let currency = CurrencyCode(currencyCode: "USD", displayName: "US Dollar")
    let transactionId = UUID().uuidString
    
    // Step 1: Preauthorize base amount
    let preauthResponse = try await KoardMerchantSDK.shared.preauth(
        amount: 1000,          // $10.00 base amount
        currency: currency,
        transactionId: transactionId
    )
    
    let authorizedTransactionId = preauthResponse.transactionId!
    print("Preauth completed: \(authorizedTransactionId)")
    
    // Step 2: Customer adds tip, create final breakdown
    let finalBreakdown = PaymentBreakdown(
        subtotal: 1000,        // $10.00
        taxRate: 875,          // 8.75%
        taxAmount: 88,         // $0.88
        tipAmount: 200,        // $2.00 tip added
        tipType: .fixed
    )
    
    // Step 3: Capture with final amount and breakdown
    let captureResponse = try await KoardMerchantSDK.shared.capture(
        transactionId: authorizedTransactionId,
        amount: 1288,          // $12.88 final amount
        breakdown: finalBreakdown
    )
    
    print("Capture completed: \(captureResponse.transactionId ?? "Unknown")")
}
```

#### Preauth → Incremental Auth → Capture Workflow

For complex scenarios where additional authorizations are needed:

```swift
private func incrementalAuthWorkflow() async throws {
    let currency = CurrencyCode(currencyCode: "USD", displayName: "US Dollar")
    let transactionId = UUID().uuidString
    
    // Step 1: Initial preauth
    let preauthResponse = try await KoardMerchantSDK.shared.preauth(
        amount: 1000,          // $10.00 initial amount
        currency: currency,
        transactionId: transactionId
    )
    
    let authorizedTransactionId = preauthResponse.transactionId!
    
    // Step 2: Customer orders additional items - incremental auth
    let additionalBreakdown = PaymentBreakdown(
        subtotal: 500,         // $5.00 additional items
        taxRate: 875,          // 8.75%
        taxAmount: 44,         // $0.44 additional tax
        tipAmount: 0,
        tipType: .fixed
    )
    
    let authResponse = try await KoardMerchantSDK.shared.auth(
        transactionId: authorizedTransactionId,
        amount: 544,           // $5.44 additional amount
        breakdown: additionalBreakdown
    )
    
    // Step 3: Final capture with tip
    let finalBreakdown = PaymentBreakdown(
        subtotal: 1500,        // $15.00 total
        taxRate: 875,          // 8.75%
        taxAmount: 131,        // $1.31 total tax
        tipAmount: 300,        // $3.00 tip
        tipType: .fixed
    )
    
    let captureResponse = try await KoardMerchantSDK.shared.capture(
        transactionId: authorizedTransactionId,
        amount: 1931,          // $19.31 final amount
        breakdown: finalBreakdown
    )
    
    print("Final capture completed: \(captureResponse.transactionId ?? "Unknown")")
}
```

#### Sale Workflow (Immediate Capture)

For simple transactions where immediate payment is required:

```swift
private func saleWorkflow() async throws {
    let breakdown = PaymentBreakdown(
        subtotal: 1000,        // $10.00
        taxRate: 875,          // 8.75%
        taxAmount: 88,         // $0.88
        tipAmount: 200,        // $2.00
        tipType: .fixed
    )
    
    let currency = CurrencyCode(currencyCode: "USD", displayName: "US Dollar")
    let transactionId = UUID().uuidString
    
    // Single sale transaction - immediate capture
    let response = try await KoardMerchantSDK.shared.sale(
        amount: 1288,          // $12.88 total
        breakdown: breakdown,
        currency: currency,
        transactionId: transactionId
    )
    
    print("Sale completed: \(response.transactionId ?? "Unknown")")
}
```

### Best Practices

1. **Token Management**: The SDK handles all token refresh automatically
2. **Error Handling**: Always wrap SDK calls in try-catch blocks
3. **Background Handling**: The SDK manages background transitions automatically
4. **Amount Formatting**: Always use cents (e.g., 1050 for $10.50)
5. **Location Setting**: Set active location before any payment operations
6. **Session Preparation**: Call `prepare()` before each payment session
7. **User Experience**: Monitor reader events for better UX feedback
8. **Transaction Idempotency**: Use custom UUID4 transaction IDs to prevent duplicate transactions due to network issues or retries

#### Transaction Idempotency

For critical payment operations, especially in unreliable network conditions, use custom transaction IDs:

```swift
// Generate a UUID4 for the transaction
let transactionId = UUID().uuidString

// Use the same ID for retries - Koard will return the same result
let response = try await KoardMerchantSDK.shared.sale(
    amount: 1000,
    breakdown: nil,
    currency: currency,
    transactionId: transactionId  // This ensures idempotency
)

// If network fails and you retry with the same transactionId,
// Koard will return the original transaction result instead of processing again
```

**Important**: 
- Use UUID4 format for transaction IDs (e.g., `UUID().uuidString`)
- Store transaction IDs before making requests for retry scenarios
- Same transaction ID will always return the same result
- This prevents accidental duplicate charges during network issues

### Troubleshooting

- **Account Linking Issues**: Ensure device has iCloud account and passcode enabled
- **Token Expiration**: SDK automatically refreshes tokens, but check network connectivity
- **Card Reader Not Ready**: Call `prepare()` and ensure proper authentication
- **Missing Location**: Verify location is set with `setActiveLocationID()`
- **Background Issues**: SDK handles this automatically, but test thoroughly

This guide provides a complete implementation pattern for integrating KoardMerchantSDK into your iOS mPOS application.

## Building the Framework

Follow these steps to build the `KoardMerchantSDK.xcframework` for distribution:

### Prerequisites
- Xcode 16.3 or later
- iOS 17.0+ deployment target
- Valid Apple Developer account for code signing

### Build Steps

1. **Clean previous builds** (optional but recommended):
   ```bash
   rm -rf build/
   ```

2. **Create iOS Device archive**:
   ```bash
   xcodebuild archive \
     -project KoardMerchantSDK.xcodeproj \
     -scheme KoardSDK \
     -destination "generic/platform=iOS" \
     -archivePath ./build/KoardSDK-iOS.xcarchive \
     SKIP_INSTALL=NO \
     BUILD_LIBRARY_FOR_DISTRIBUTION=YES
   ```

3. **Create iOS Simulator archive**:
   ```bash
   xcodebuild archive \
     -project KoardMerchantSDK.xcodeproj \
     -scheme KoardSDK \
     -destination "generic/platform=iOS Simulator" \
     -archivePath ./build/KoardSDK-iOS-Simulator.xcarchive \
     SKIP_INSTALL=NO \
     BUILD_LIBRARY_FOR_DISTRIBUTION=YES
   ```

4. **Create XCFramework**:
   ```bash
   xcodebuild -create-xcframework \
     -framework ./build/KoardSDK-iOS.xcarchive/Products/Library/Frameworks/KoardSDK.framework \
     -framework ./build/KoardSDK-iOS-Simulator.xcarchive/Products/Library/Frameworks/KoardSDK.framework \
     -output ./build/KoardMerchantSDK.xcframework
   ```

### Output

The built framework will be located at:
```
./build/KoardMerchantSDK.xcframework
```

This XCFramework supports:
- **iOS Device** (arm64)
- **iOS Simulator** (arm64, x86_64)

## Integration

### Adding to Your Project

1. Drag `KoardMerchantSDK.xcframework` into your Xcode project
2. In your target's "General" tab, add it to "Frameworks, Libraries, and Embedded Content"
3. Set the framework to "Embed & Sign"

### Usage

```swift
import KoardMerchantSDK

class PaymentViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSDK()
    }
    
    private func setupSDK() {
        // Initialize SDK
        let options = KoardOptions(environment: .uat, loggingLevel: .debug)
        KoardMerchantSDK.shared.initialize(options: options, apiKey: "your-api-key")
    }
    
    private func authenticateAndPrepare() async throws {
        // Login with merchant credentials
        try await KoardMerchantSDK.shared.login(code: "merchant-code", pin: "merchant-pin")
        
        // Get locations and set active location
        let locations = try await KoardMerchantSDK.shared.locations()
        if let firstLocation = locations.first {
            KoardMerchantSDK.shared.setActiveLocationID(firstLocation.id)
        }
        
        // Link account (required for Tap to Pay)
        KoardMerchantSDK.shared.linkAccount()
        
        // Prepare card reader
        try await KoardMerchantSDK.shared.prepare()
    }
    
    private func processPayment() async throws {
        // Create payment breakdown (optional)
        let breakdown = PaymentBreakdown(
            subtotal: 1000,        // $10.00
            taxRate: 875,          // 8.75%
            taxAmount: 88,         // $0.88
            tipAmount: 200,        // $2.00
            tipType: .fixed
        )
        
        // Create currency
        let currency = CurrencyCode(currencyCode: "USD", displayName: "US Dollar")
        
        // Process sale
        let response = try await KoardMerchantSDK.shared.sale(
            amount: 1288,          // $12.88 total (subtotal + tax + tip)
            breakdown: breakdown,
            currency: currency
        )
        
        // Handle response
        if let transaction = response.transaction {
            switch transaction.status {
            case .approved:
                print("Payment approved: \(transaction.transactionId)")
            case .surchargePending:
                // Handle surcharge confirmation
                let confirmed = try await KoardMerchantSDK.shared.confirm(
                    transaction: transaction.transactionId,
                    confirm: true
                )
                print("Surcharge confirmed, final status: \(confirmed.status)")
            case .declined:
                print("Payment declined: \(transaction.statusReason ?? "Unknown reason")")
            default:
                print("Payment status: \(transaction.status)")
            }
        }
    }
}
```

#### Key Points

- **Amounts in cents**: All monetary values should be specified in cents (e.g., 1050 for $10.50)
- **Async operations**: Most SDK functions are asynchronous and require `await`
- **Authentication required**: Login and set active location before processing payments
- **Card reader preparation**: Call `prepare()` before accepting payments
- **Error handling**: Wrap calls in try-catch blocks to handle `KoardMerchantSDKError`

---

## Requirements

- iOS 17.0+
- Xcode 16.3+
- Swift 5.9+

---

## 🧭 Migration Guide: `KoardMerchantSDKError` → `KoardSDKError`

As of **v1.0.0**, the old `KoardMerchantSDKError` enum has been replaced with a cleaner, developer-friendly `KoardSDKError`.

### ✅ Why we changed it:
- Fewer error cases to manage
- Clearer categories for UI and logging
- Built-in `LocalizedError` support
- Structured underlying error handling

### 🔄 Mapping of Old → New Errors:

| Old Error                         | New Error                        |
|----------------------------------|----------------------------------|
| `.urlForming`                    | `.invalidRequest`                |
| `.notAuthorized` (401, 403)      | `.unauthorized`                  |
| `.merchantBlocked` (423)         | `.blockedAccount`                |
| `.apiError(ApiErrorDetail)`      | `.server(message:)`              |
| `.unsupportedOSVersion("15.4")`  | `.unsupportedPlatform("15.4")`   |
| `.decodingFailure`               | `.decodingFailure`               |
| `.network(URLError)`             | `.network(...)`                  |
| `.unknownError`                  | `.unknown(...)`                  |

### 🆕 Example Usage

```swift
do {
    try await sdk.login(code: "demo", pin: "1234")
} catch let error as KoardSDKError {
    showAlert(error.localizedDescription)
}
```

### 💡 Custom Handling Still Works

```swift
switch error {
case .unauthorized:
    showLoginScreen()
case .server(let message):
    showAlert(message ?? "Server error")
case .unknown(let underlying):
    logger.error("Unexpected error: \(underlying?.localizedDescription ?? "unknown")")
default:
    showAlert(error.localizedDescription)
}
```

> `KoardMerchantSDKError` is deprecated and will be removed in a future version.

## 📝 License

MIT License. See [LICENSE](LICENSE) for details.

---

## 💬 Support

For questions, issues or contributions, please open a GitHub Issue or email support@koardlabs.com.
