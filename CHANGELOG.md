# Changelog

All notable changes to **KoardSDK** are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project aims to follow [Semantic Versioning](https://semver.org/).

> The public SDK ships as a resilient binary `KoardSDK.xcframework`
> (`BUILD_LIBRARY_FOR_DISTRIBUTION=YES`). The changes below introduce **no
> breaking API or ABI changes** — all public method signatures are unchanged,
> and the two new error cases are additive on non-`@frozen` enums (source- and
> binary-compatible). They do, however, include **runtime behavior changes**
> integrators should be aware of — see **⚠️ Behavior changes** under each
> release. Recommended bump: **minor**.

## [1.0.18] - 2026-06-24

### ⚠️ Behavior changes for integrators

These do not break compilation, but they change the error/value you receive at
runtime. Update your `catch` / `switch` logic if you key off the old values:

- **Tap to Pay cancellation now has its own error.** When the customer cancels
  at the Apple Tap to Pay sheet, `sale(...)`, `refund(..., withTap: true)`, and
  the pre-auth flow now throw `KoardMerchantSDKError.TTPPaymentFailed(.canceled)`.
  Previously this surfaced as `.TTPPaymentFailed(.paymentCardReaderNilResult)`.
  If you were treating `.paymentCardReaderNilResult` as "canceled", switch to
  `.canceled`. Other reader read failures now surface as
  `.paymentCardReaderError(underlying)` instead of a nil result.
- **Network/transport errors are now typed.** Offline / timeout / cannot-connect
  failures are thrown as `KoardMerchantSDKError.network(description:underlying:)`
  instead of a raw `URLError`. The original `URLError` is available via
  `underlying`. If you did `catch let e as URLError`, switch to matching
  `.network`.
- **Rate limiting (HTTP 429) is now distinct.** A 429 throws the new
  `KoardMerchantSDKError.rateLimited(message:)`. Previously it surfaced as
  `.server` or `.unknown`. Callers may use this to back off / retry.
- **Server errors no longer leak decoding failures.** HTTP 400/404/5xx with a
  body that isn't the expected JSON (e.g. an HTML 502 page, an empty 500) now
  throw `.server(message:)` with a clean `"Server error (HTTP <code>)"` message
  instead of `.unknown(<JSON decoding error>)` (the old "data couldn't be
  read / unparseable" message).
- **"Not authenticated" precondition is now `.unauthorized`.** Calling a
  payment / refund / pre-auth operation with no active session throws
  `.unauthorized` instead of `.invalidRequest`.

### Fixed

- **`logout()` no longer wipes the host app's Keychain.** `logout()` previously
  issued a blanket Keychain delete scoped to the app's service, removing **all**
  generic-password items the host app owned — not just Koard's. It now deletes
  only the SDK's own keys. (The SDK does not rename its Keychain service, so
  existing logged-in sessions are preserved across this update — no forced
  re-login.)
- **Intermittent `ReceivedNilTokenError` on Tap to Pay.** The merchant session
  token was treated as valid indefinitely; once it passed its real (server-side)
  expiry the SDK kept sending the dead token, the card-reader token endpoint
  returned 401, and that 401 was decoded into a nil token and surfaced as an
  opaque `ReceivedNilTokenError`. The SDK now tracks the JWT's real `exp`
  claim, refuses to reuse an expired token, and surfaces the real HTTP status.
- **`readerBusy` errors when switching location / charging too quickly.**
  `PaymentCardReader` permits one operation at a time; overlapping
  prepare / linkAccount / isAccountLinked / read calls collided
  (`PaymentCardReaderError` error 18). Reader operations are now serialized — a
  sale started while `prepare()` is still running waits for readiness instead of
  failing.
- **Card-reader read failures are no longer swallowed.** A read error
  (cancellation, etc.) previously returned a nil result that collapsed into a
  generic `paymentCardReaderNilResult`; the real outcome is now surfaced (see
  Behavior changes).
- **Charges no longer run against a stale location after a location switch.**
  The reader session now records which location it was prepared for; a sale
  started after the active location changed re-prepares the session (under the
  reader lock) before charging, instead of charging against the session bound to
  the previously-selected location. Closes a race between "switch location" and
  an immediately-following sale.

### Added

- `login(alias:)` — log in with a single opaque alias string instead of a
  code + PIN, for integrators who have already resolved the merchant identity
  (e.g. QR scan, SSO callback, or a server-issued provisioning token). It hits
  the same `/v1/merchant/login` route and yields the same session token as
  `login(code:pin:)`; like that method it is session-auth only — the session
  token is persisted, the alias itself is never stored.
- `deviceType` on transaction responses (`KoardTransaction` /
  `TransactionResponse`) — optional `String?` reporting the device that
  originated the transaction. Additive and decoded via `decodeIfPresent`, so
  existing decoders are unaffected.
- `KoardMerchantSDKError.rateLimited(message:)` — HTTP 429.
- `KoardMerchantSDKError.TTPPaymentError.canceled` — customer canceled at the
  Tap to Pay sheet (a benign outcome, distinct from a failure).
- First unit/integration test suite covering JWT-expiry decoding, session-token
  refresh/expiry, the masked-401 → typed-error path, and Keychain logout
  scoping.

### Changed

- `login(code:pin:)` no longer persists the merchant code or PIN to the
  Keychain. Authentication state is determined solely by the session token;
  credentials are never stored. (Re-authenticate via `login(...)` after a
  session expires.)
- HTTP error mapping is now explicit per status code:
  `400` → `.server`, `401`/`403` → `.unauthorized`, `423` → `.blockedAccount`,
  `429` → `.rateLimited`, other non-2xx (`404`/`408`/`5xx`/…) → `.server` with a
  readable message and the status code.

