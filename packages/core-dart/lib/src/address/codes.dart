/// The three types of Stellar addresses supported by the kit.
enum AddressKind {
  /// Classic 56-character Stellar account address starting with 'G'.
  g,

  /// Muxed account address starting with 'M', encoding a 'G' address and a 64-bit ID.
  m,

  /// Soroban smart-contract address starting with 'C'.
  c
}

/// Standard error codes returned when address parsing fails.
abstract final class ErrorCode {
  /// The CRC-16 checksum of the address is invalid.
  static const invalidChecksum = 'INVALID_CHECKSUM';

  /// The decoded length of the address does not match its prefix requirements.
  static const invalidLength = 'INVALID_LENGTH';

  /// The input string is not a valid Base32 encoded sequence.
  static const invalidBase32 = 'INVALID_BASE32';

  /// Seed keys (starting with 'S') are not accepted as payment destinations.
  static const rejectedSeedKey = 'REJECTED_SEED_KEY';

  /// Pre-authorized transaction hashes (starting with 'T') are not accepted.
  static const rejectedPreauth = 'REJECTED_PREAUTH';

  /// HashX identifiers (starting with 'X') are not accepted.
  static const rejectedHashX = 'REJECTED_HASH_X';

  /// Federation addresses (name*domain.com) are not supported by this kit.
  static const federationAddressNotSupported =
      'FEDERATION_ADDRESS_NOT_SUPPORTED';

  /// The address prefix is not one of 'G', 'M', or 'C'.
  static const unknownPrefix = 'UNKNOWN_PREFIX';
}

/// Warning codes returned when an address is valid but has non-standard
/// properties.
///
/// Every value here is a normative wire string defined by
/// `spec/schema.json` and is byte-for-byte identical to the equivalent
/// constant in core-ts (`WarningCode`) and core-go
/// (`address.WarnNonCanonicalAddress` and friends). Adding or renaming a code
/// means changing all three SDKs and the spec in the same commit; the
/// cross-language audit lives in `test/warning_code_parity_test.dart`.
abstract final class WarningCode {
  /// The address has non-canonical casing (usually lowercase).
  static const nonCanonicalAddress = 'NON_CANONICAL_ADDRESS';

  /// The routing ID has non-canonical formatting (e.g., leading zeros).
  static const nonCanonicalRoutingId = 'NON_CANONICAL_ROUTING_ID';

  /// A memo was provided but ignored because the M-address already contains an ID.
  static const memoIgnoredForMuxed = 'MEMO_IGNORED_FOR_MUXED';

  /// Both an M-address and a routing memo were present in the transaction.
  static const memoPresentWithMuxed = 'MEMO_PRESENT_WITH_MUXED';

  /// The transaction sender is a smart contract.
  static const contractSenderDetected = 'CONTRACT_SENDER_DETECTED';

  /// The MEMO_TEXT field is not a valid numeric uint64.
  static const memoTextUnroutable = 'MEMO_TEXT_UNROUTABLE';

  /// The MEMO_ID field is malformed or exceeds uint64 range.
  static const memoIdInvalidFormat = 'MEMO_ID_INVALID_FORMAT';

  /// The provided memo type (e.g., HASH or RETURN) is not supported for routing.
  static const unsupportedMemoType = 'UNSUPPORTED_MEMO_TYPE';

  /// The destination is a smart contract, which is invalid for classic payments.
  static const invalidDestination = 'INVALID_DESTINATION';

  /// The destination requires a memo (SEP-0029) but none supplied a routing ID.
  static const missingRequiredMemo = 'MISSING_REQUIRED_MEMO';

  /// Every warning code this SDK can emit, in the order declared by
  /// `spec/schema.json`.
  ///
  /// Use this to validate codes arriving from the wire:
  /// `WarningCode.values.contains(json['code'])`.
  static const values = <String>[
    nonCanonicalAddress,
    nonCanonicalRoutingId,
    memoIgnoredForMuxed,
    memoPresentWithMuxed,
    contractSenderDetected,
    memoTextUnroutable,
    memoIdInvalidFormat,
    unsupportedMemoType,
    invalidDestination,
    missingRequiredMemo,
  ];

  /// Returns `true` when [code] is one of the normative [values].
  static bool isKnown(String code) => values.contains(code);

  /// Returns the [WarningCode] matching [code], or `null` when it is not a
  /// normative warning code.
  static String? tryParse(String code) => isKnown(code) ? code : null;
}

/// Severity levels carried by [Warning.severity] and `RoutingWarning.severity`.
///
/// Severities are plain strings so they serialize identically to the
/// TypeScript and Go implementations; compare against these constants rather
/// than hard-coding the literals. core-ts models them as the union
/// `"info" | "warn" | "error"` and core-go as a bare `string`, so the
/// Dart package deliberately avoids an enum here: an enum would force a
/// conversion at every JSON boundary and break byte-level parity of
/// `RoutingResult.toJson()`.
///
/// ```dart
/// final result = extractRoutingSync(input);
/// final blocking = result.warnings
///     .where((w) => w.severity == WarningSeverity.error);
/// ```
abstract final class WarningSeverity {
  /// Informational only; no action is required.
  static const info = 'info';

  /// The input was accepted, but should be reviewed or normalized.
  static const warn = 'warn';

  /// The payment should not be credited automatically.
  static const error = 'error';

  /// All severities, ordered from least to most severe.
  static const values = <String>[info, warn, error];

  /// Returns the matching severity string, or `null` for an unrecognized
  /// value.
  ///
  /// ```dart
  /// WarningSeverity.tryParse('warn');   // 'warn'
  /// WarningSeverity.tryParse('fatal');  // null
  /// ```
  static String? tryParse(String value) =>
      values.contains(value) ? value : null;
}

/// Represents a warning encountered during address parsing or routing.
class Warning {
  /// The [WarningCode] identifying the type of warning.
  final String code;

  /// A human-readable description of the warning.
  final String message;

  /// The [WarningSeverity] of the warning (`info`, `warn`, or `error`).
  final String severity;

  /// Optional normalization payload if the input was non-canonical.
  final Normalization? normalization;

  /// Optional context providing additional details about the warning.
  final WarningContext? context;

  /// Creates a warning; [normalization] and [context] are optional.
  Warning({
    required this.code,
    required this.message,
    required this.severity,
    this.normalization,
    this.context,
  });
}

/// Details about a non-canonical input that was normalized.
class Normalization {
  /// The original raw input string.
  final String original;

  /// The normalized canonical representation.
  final String normalized;

  /// Records that [original] was rewritten to [normalized].
  Normalization({required this.original, required this.normalized});
}

/// Contextual details for specific warning types.
///
/// `spec/schema.json` couples these fields to the warning code:
/// `INVALID_DESTINATION` allows only `destinationKind: 'C'`, and
/// `UNSUPPORTED_MEMO_TYPE` allows only `memoType` in
/// `hash | return | unknown`. `additionalProperties: false` means a context
/// carrying both fields is rejected, so never populate both.
class WarningContext {
  /// The kind of destination address (G, M, or C).
  final String? destinationKind;

  /// The type of memo provided in the transaction.
  final String? memoType;

  /// Creates a context; every field is optional.
  const WarningContext({this.destinationKind, this.memoType});

  /// Serializes this context, omitting fields that were never set so the
  /// output matches the schema's `required` lists exactly.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (destinationKind != null) 'destinationKind': destinationKind,
      if (memoType != null) 'memoType': memoType,
    };
  }

  @override
  String toString() => 'WarningContext(${toJson()})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WarningContext &&
          destinationKind == other.destinationKind &&
          memoType == other.memoType;

  @override
  int get hashCode => Object.hash(destinationKind, memoType);
}

/// The result of parsing a raw Stellar address string.
class ParseResult {
  /// The detected [AddressKind], or null if parsing failed.
  final AddressKind? kind;

  /// The canonical address string (always uppercase).
  final String address;

  /// A list of non-blocking [Warning]s encountered during parsing.
  final List<Warning> warnings;

  /// Details of the error if [kind] is null.
  final AddressError? error;

  /// Creates a parse result. [error] is set if and only if [kind] is null.
  ParseResult({
    this.kind,
    required this.address,
    required this.warnings,
    this.error,
  });
}

/// Details of a terminal error encountered during address parsing.
class AddressError {
  /// The [ErrorCode] identifying the failure reason.
  final String code;

  /// The original input string that failed parsing.
  final String input;

  /// A human-readable error message.
  final String message;

  /// Creates an error describing why [input] failed to parse.
  AddressError({
    required this.code,
    required this.input,
    required this.message,
  });
}
