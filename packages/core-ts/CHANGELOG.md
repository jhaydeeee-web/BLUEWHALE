# Changelog — @redishfish/bluewhale-core

All notable changes to this package are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Releases are coordinated with `spec/vectors.json` `spec_version`: see
[Changelogs & release versioning](../../CONTRIBUTING.md#changelogs--release-versioning).

## [Unreleased]

### Added

- A cross-language parity test (`src/spec/warning-codes.test.ts`) that reads
  `spec/schema.json` and asserts the `WarningCode` union matches it.

### Fixed

- **Breaking for consumers matching on warning codes:** `extractRouting`
  reported `MEMO_TEXT_UNROUTABLE` for a `hash` or `return` memo and for any
  unrecognized memo type. It now reports `UNSUPPORTED_MEMO_TYPE` with the
  `context.memoType` that `spec/schema.json` requires and that core-go and
  core-dart already emitted (#76). `MEMO_TEXT_UNROUTABLE` is now reserved for
  a `MEMO_TEXT` value that is not a numeric uint64.
- `@stellar/stellar-sdk` v17 removed its default export, so
  `import StellarSdk from "@stellar/stellar-sdk"` left `StrKey` undefined and
  12 test files failed to load. Switched to the named import.
- `extractFromURI.ts` declared `sanitizeSep7UriForLogging` twice (a bad merge),
  which is a hard esbuild error. Kept the documented implementation.
- The spec runner did not account for the legacy 50-character placeholder
  addresses in `spec/vectors.json`, which no implementation can parse.
  core-dart already substitutes canonical addresses and core-go skips those
  vectors; core-ts now substitutes identically. It also stopped asserting
  that a C-destination throws, which contradicted the vector's expected
  `INVALID_DESTINATION` result.

## [1.2.0] - 2026-09-24

Implements spec `1.2.0`.

### Added

- `extractRouting` returns `CONTRACT_SENDER_DETECTED` (severity `info`) and
  clears routing state when `sourceAccount` is a Soroban contract (`C...`),
  matching core-go and core-dart.
- Exported `SEVERITY_ORDER`, `severityWeight` and `filterBySeverity` with the
  normative weights `info = 0`, `warn = 1`, `error = 2`.

### Fixed

- An unknown `minSeverityLevel` no longer drops every warning; unknown
  severities now weigh as `info`, identically to Go and Dart.

## [1.0.1] - 2026-04-24

### Changed

- Synced package documentation for the registry release.

## [1.0.0] - 2026-04-23

### Added

- Initial release: G / M / C address detection, parsing and validation,
  SEP-23 muxed encode/decode, and deposit routing extraction.
