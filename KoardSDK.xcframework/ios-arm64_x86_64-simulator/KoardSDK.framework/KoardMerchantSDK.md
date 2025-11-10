# KoardMerchantSDK

KoardMerchantSDK is a Swift SDK for integrating Tap to Pay, transaction processing, and merchant authentication using Koard's backend platform.

This SDK allows merchants to authenticate, process transactions, manage location context, and generate fallback payment links in cases where in-person payments are not possible.

---

## Topics

### Getting Started
- ``initialize(options:apiKey:)``
- ``presentTutorial(from:)``

### Authentication
- ``login(code:pin:)``
- ``logout()``
- ``isAccountLinked()``
- ``linkAccount()``

### Account and Location
- ``getMerchantAccount()``
- ``locations(request:)``
- ``setActiveLocationID(_:)``
- ``getActiveLocationID()``

### Tap to Pay
- ``prepare()``
- ``getToken()``
- ``deinitializeCardReader()``

### Transactions
- ``sale(amount:breakdown:currency:eventId:type:)``
- ``refund(transactionId:amount:eventId:)``
- ``tipAdjust(transactionId:amount:tipType:eventId:)``
- ``reverse(transactionId:amount:eventId:)``
- ``capture(transactionId:amount:breakdown:eventId:)``
- ``preauth(amount:breakdown:currency:eventId:type:)``
- ``confirm(transactionID:confirm:amount:breakdown:)``

### Transaction Queries
- ``transactionHistory(request:)``
- ``searchTransactions(_:)``
- ``searchTransactionsAdvanced(startDate:endDate:statuses:types:minAmount:maxAmount:limit:)``
- ``transactionsByStatus(_:)``
- ``transactionsByStatuses(_:)``
- ``transactionsByType(_:)``
- ``transactionsByStatusesAndTypes(statuses:types:)``

### Receipts & Fallback
- ``sendReceipts(transactionId:email:phoneNumber:)``
- ``createFallbackLink(amount:breakdown:)``
