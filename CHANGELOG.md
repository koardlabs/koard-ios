# Changelog

All notable changes to **KoardSDK** are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project aims to follow [Semantic Versioning](https://semver.org/).

> KoardSDK is distributed as a resilient, **static** binary
> `KoardSDK.xcframework` (built with `BUILD_LIBRARY_FOR_DISTRIBUTION=YES`).
> Each release below lists any behavior, API, or ABI changes integrators
> should be aware of; unless a release says otherwise, the public API is
> unchanged.

## [1.0.20] - 2026-07-03

### Fixed

- **Changing the API key now invalidates the stale merchant session.** When the
  host app was reconfigured with a different Koard API key and relaunched, the
  SDK restored the persisted session token / account / active location from the
  **old** key's merchant and kept using it — so the app "didn't update" after a
  key swap. `initialize(options:apiKey:)` now records a one-way SHA-256
  fingerprint of the key and, when it changes, clears the persisted merchant
  session (device enrollment is preserved) so the next request re-authenticates
  under the new key. Mirrors the Android SDK's behavior; the raw key is never
  stored — only its fingerprint.
- **Reader no longer flashes `.preparing` on an unlinked device.** `prepare()`
  set the reader status to `.preparing` *before* checking whether the account was
  linked, so an unlinked prepare — notably the `didBecomeActive` observer
  re-running after the merchant **declined** the Apple linking sheet — briefly
  reported `.preparing` before snapping back to `.notReady`. `.preparing` is now
  set only after the account is confirmed linked, so an unlinked device goes
  straight to `.notReady` / `accountNotLinked` with no flicker.

- **`logout()` now tears down the card-reader session.** It cleared the auth
  token and Keychain but left the reader reporting the previous merchant's
  `.ready`/`.linked` status and holding its prepared session. Logging out and
  back in as a **different** merchant who wasn't linked yet then briefly showed
  "card reader ready" for a few seconds before the new prepare resolved to
  `accountNotLinked`. `logout()` now resets the reader (`status = .notReady`,
  drops the session, recreates the reader) **and invalidates the cached
  Tap-to-Pay token** (minted for the previous merchant, cached ~90 min) so no
  stale readiness — or a wrong linked-state check against the old merchant's
  token — leaks across a merchant switch. Without the token reset, a
  freshly-logged-in **linked** merchant could briefly show "account not linked"
  (the check ran against the previous, unlinked merchant's token).
- **Switching locations no longer marks the reader "ready" against the previous
  location's token.** `setActiveLocationID()` warms a fresh, location-specific
  reader token in the background (keeping the old one usable). Now that `prepare()`
  is faster (no per-prepare `isAccountLinked()` round-trip), it could win the race
  with that refresh and mark the reader ready using the OLD location's token — an
  instant, false "ready" on every switch. `prepare()` now detects a changed active
  location, invalidates the cached token + stale session, and re-prepares against
  the new location's token.

### Added

- `KoardMerchantSDKError.readerTokenInvalid(String?)` — thrown by `prepare()`
  when the Tap to Pay reader token is empty/invalid/expired (commonly a
  sandbox-vs-production environment mismatch). The SDK invalidates its cached
  reader token when this is thrown so a retry fetches a fresh one.

### Changed

- **`prepare()` no longer pre-checks `isAccountLinked()` on every call.** It
  previously ran an extra reader round-trip (under the reader lock) before every
  prepare — added latency to a frequently-called path. It now calls
  `reader.prepare()` directly and maps the `PaymentCardReaderError` it throws:
  `.accountNotLinked` / `.accountLinkingCheckFailed` → `accountNotLinked`;
  `.invalidReaderToken` / `.emptyReaderToken` / `.tokenExpired` /
  `.prepareExpired` → `readerTokenInvalid` (and invalidates the cached token);
  `.merchantBlocked` / `.accountDeactivated` → `blockedAccount`. It also no
  longer pre-sets `.preparing` (progress still arrives via the reader's
  `.configuring` events), so a failed prepare doesn't flash `.preparing`.

- **`linkAccountAsync()` now surfaces link failures instead of swallowing them.**
  It previously caught every error, recorded the reader status, and returned
  normally — so `try await linkAccountAsync()` could not distinguish a successful
  link from a declined/failed one. It now rethrows genuine errors (e.g. the
  merchant declining Apple's linking sheet) while still treating an
  "already linked" account as success. Callers that `try await` it should handle
  the thrown error (e.g. keep presenting the link prompt on decline).

## [1.0.19] - 2026-07-02

### ⚠️ Behavior changes for integrators

- **`prepare()` no longer auto-links the Tap to Pay account.** Previously
  `prepare()` (which also runs from the `didBecomeActive` observer) silently
  presented the Apple account-linking sheet when the device wasn't linked. If
  the merchant declined, it threw and got re-presented on every app activation —
  an endless link prompt. `prepare()` now throws the new
  `KoardMerchantSDKError.accountNotLinked` instead of auto-linking. Guard for it
  and drive linking explicitly via the public `linkAccount()` API (this restores
  merchant-side control over how and when linking is presented). The background
  prepare retry loop treats not-linked as terminal and no longer retries it.

### Added

- `KoardMerchantSDKError.accountNotLinked` — thrown by `prepare()` when the
  device isn't linked to the merchant's Tap to Pay account, so callers can guard
  it and explicitly call `linkAccount()` instead of the SDK silently presenting
  the Apple linking sheet.

### Fixed

- **Endless Tap to Pay account-linking prompt after a decline.** A merchant who
  declined the Apple account-linking sheet was re-prompted on every app
  activation, because `prepare()` (run from `didBecomeActive`) auto-linked and
  the retry loop re-presented the sheet. `prepare()` now surfaces
  `accountNotLinked` and leaves linking to the explicit `linkAccount()` call
  (see **Behavior changes**), breaking the loop.
- **Reader stuck reporting `.preparing` on an unlinked account.** `prepare()`
  set the reader status to `.preparing` before the linked-account check; when the
  account wasn't linked it threw without clearing the status, so callers polling
  `status` saw `.preparing` forever (the UI showed "preparing card reader"
  indefinitely). The status is now reset to `.notReady` before the
  `accountNotLinked` error is thrown.

## [1.0.18] - 2026-06-24

> These do not break compilation or ABI (the new error cases are additive on
> non-`@frozen` enums), but they change the error/value you receive at runtime.
> Update your `catch` / `switch` logic if you key off the old values.

### ⚠️ Behavior changes for integrators

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

## [1.0.17] - 2026-05-13

### Added

- **Partial approval flow.** `preauth(...)` and `sale(...)` now accept an
  optional `partialAuthTransactionId` to complete the remaining amount of a
  partial approval. New `KoardTransaction` properties: `isPartialApproval`,
  `authorizedAmount`, `remainingAmount`. New `StatusReason.partialApproval` case.

### Changed

- `KoardDescribableError` now conforms to `LocalizedError`, exposing
  `errorDescription` and `failureReason` directly.
- **Distribution: KoardSDK now ships as a static framework** (previously
  dynamic). The public API is unchanged. If Xcode warns that
  `KoardSDK.framework` is missing an executable, change the `KoardSDK.xcframework`
  entry under your app target's **General → Frameworks & Libraries** from
  **Embed & Sign** to **Do Not Embed**, clean the build folder (⌘⇧K), and rebuild.

## [1.0.16] - 2026-02-10

### Changed

- Migrated the public distribution off the `develop` branch and refreshed the
  demo / sample code. Baseline release for the public `koard-ios` distribution
  repo (binary `KoardSDK.xcframework` + SwiftPM `Package.swift` + podspec).

[1.0.20]: https://github.com/koardlabs/koard-ios/compare/1.0.19...1.0.20
[1.0.19]: https://github.com/koardlabs/koard-ios/compare/1.0.18...1.0.19
[1.0.18]: https://github.com/koardlabs/koard-ios/compare/1.0.17...1.0.18
[1.0.17]: https://github.com/koardlabs/koard-ios/compare/1.0.16...1.0.17
[1.0.16]: https://github.com/koardlabs/koard-ios/compare/1.0.15...1.0.16
