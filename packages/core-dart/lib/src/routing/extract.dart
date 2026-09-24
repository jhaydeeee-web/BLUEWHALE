import '../address/codes.dart' as codes;
import '../address/parse.dart';
import '../muxed/decode.dart';
import 'routing_result.dart';
import 'memo.dart';
import 'safe_routing_id.dart';

/// Extracts deposit routing information from a Stellar payment input.
/// Following the standard priority policy, M-address identifiers take
/// precedence over any provided memo.
///
/// Web safety: routing IDs are resolved through [SafeRoutingId], which
/// parses the canonical decimal **string** exactly and never converts
/// through `int`/JS `Number`. Combined with the `BigInt`-backed
/// [RoutingResult.id], [RoutingResult.idString], and
/// [RoutingResult.safeId] accessors, MEMO_IDs and muxed IDs up to the
/// uint64 ceiling survive Flutter Web without truncation.
///
/// This is the primary, synchronous entry point and mirrors `extractRouting`
/// in the TypeScript SDK and `ExtractRouting` in the Go SDK. It performs pure
/// string parsing only; for async network checks (e.g. SEP-0029 memo
/// requirements) use [extractRoutingAsync].
///
/// Throws [ExtractRoutingException] when the destination is empty or is not
/// a G or M address.
RoutingResult extractRouting(RoutingInput input) {
  final trimmed = input.destination.trim();
  if (trimmed.isEmpty) {
    throw const ExtractRoutingException('Invalid input: destination must be a non-empty string.');
  }

  final prefix = trimmed[0].toUpperCase();
  if (prefix != 'G' && prefix != 'M') {
    throw ExtractRoutingException(
      'Invalid destination: expected a G or M address, got "${input.destination}".',
    );
  }

  if (input.sourceAccount != null && input.sourceAccount!.isNotEmpty) {
    try {
      final source = parse(input.sourceAccount!);
      if (source.kind == codes.AddressKind.c) {
        return RoutingResult(
          source: RoutingSource.none,
          warnings: [RoutingWarning.contractSender],
        );
      }
    } catch (_) {
      // Ignore source account parsing errors for routing extraction
    }
  }

  final parsed = parse(input.destination);

  if (parsed.kind == null) {
    return RoutingResult(
      source: RoutingSource.none,
      warnings: [],
      destinationError: parsed.error != null
          ? DestinationError(
              code: parsed.error!.code,
              message: parsed.error!.message,
            )
          : null,
    );
  }

  final warnings = <RoutingWarning>[];
  for (final w in parsed.warnings) {
    warnings.add(RoutingWarning(
      code: w.code,
      severity: w.severity,
      message: w.message,
    ));
  }

  if (parsed.kind == codes.AddressKind.m) {
    final decoded = MuxedDecoder.decodeMuxedString(parsed.address);
    final baseG = decoded.baseG;
    final muxedId = decoded.id;

    if (input.memoType == 'none') {
      return RoutingResult(
        destinationBaseAccount: baseG,
        id: muxedId,
        source: RoutingSource.muxed,
        warnings: warnings,
      );
    }

    BigInt? routingId;
    RoutingSource routingSource = RoutingSource.none;

    warnings.add(RoutingWarning.memoIgnored);

    if (input.memoType == 'id') {
      final norm = normalizeMemoId(input.memoValue ?? '');
      if (norm.normalized != null) {
        routingId = SafeRoutingId.tryParse(norm.normalized!)?.toBigInt;
        routingSource = RoutingSource.memo;
      } else {
        warnings.add(
          const RoutingWarning(
            code: codes.WarningCode.memoIdInvalidFormat,
            severity: 'warn',
            message: 'MEMO_ID was empty, non-numeric, or exceeded uint64 max.',
          ),
        );
      }
      for (final w in norm.warnings) {
        warnings.add(RoutingWarning(
          code: w.code,
          severity: w.severity,
          message: w.message,
        ));
      }
    } else if (input.memoType == 'text' && input.memoValue != null) {
      final norm = normalizeMemoTextId(input.memoValue!);
      if (norm.normalized != null) {
        routingId = SafeRoutingId.tryParse(norm.normalized!)?.toBigInt;
        routingSource = RoutingSource.memo;
      } else {
        warnings.add(
          const RoutingWarning(
            code: codes.WarningCode.memoTextUnroutable,
            severity: 'warn',
            message: 'MEMO_TEXT was not a valid numeric uint64.',
          ),
        );
      }
      for (final w in norm.warnings) {
        warnings.add(RoutingWarning(
          code: w.code,
          severity: w.severity,
          message: w.message,
        ));
      }
    } else if (input.memoType == 'hash' || input.memoType == 'return') {
      warnings.add(
        RoutingWarning(
          code: codes.WarningCode.unsupportedMemoType,
          severity: 'warn',
          message: 'Memo type ${input.memoType} is not supported for routing.',
        ),
      );
    } else {
      warnings.add(
        const RoutingWarning(
          code: codes.WarningCode.unsupportedMemoType,
          severity: 'warn',
          message: 'Unrecognized memo type: unknown',
        ),
      );
    }

    return RoutingResult(
      destinationBaseAccount: baseG,
      id: routingId,
      source: routingSource,
      warnings: warnings,
    );
  }

  BigInt? routingId;
  RoutingSource routingSource = RoutingSource.none;

  if (input.memoType == 'id') {
    final norm = normalizeMemoId(input.memoValue ?? '');
    if (norm.normalized != null) {
      routingId = SafeRoutingId.tryParse(norm.normalized!)?.toBigInt;
      routingSource = RoutingSource.memo;
    } else {
      warnings.add(
        const RoutingWarning(
          code: codes.WarningCode.memoIdInvalidFormat,
          severity: 'warn',
          message: 'MEMO_ID was empty, non-numeric, or exceeded uint64 max.',
        ),
      );
    }
    for (final w in norm.warnings) {
      warnings.add(RoutingWarning(
        code: w.code,
        severity: w.severity,
        message: w.message,
      ));
    }
  } else if (input.memoType == 'text' && input.memoValue != null) {
    final norm = normalizeMemoTextId(input.memoValue!);
    if (norm.normalized != null) {
      routingId = SafeRoutingId.tryParse(norm.normalized!)?.toBigInt;
      routingSource = RoutingSource.memo;
    } else {
      warnings.add(
        const RoutingWarning(
          code: codes.WarningCode.memoTextUnroutable,
          severity: 'warn',
          message: 'MEMO_TEXT was not a valid numeric uint64.',
        ),
      );
    }
    for (final w in norm.warnings) {
      warnings.add(RoutingWarning(
        code: w.code,
        severity: w.severity,
        message: w.message,
      ));
    }
  } else if (input.memoType == 'hash' || input.memoType == 'return') {
    warnings.add(
      RoutingWarning(
        code: codes.WarningCode.unsupportedMemoType,
        severity: 'warn',
        message: 'Memo type ${input.memoType} is not supported for routing.',
      ),
    );
  } else if (input.memoType != 'none') {
    warnings.add(
      const RoutingWarning(
        code: codes.WarningCode.unsupportedMemoType,
        severity: 'warn',
        message: 'Unrecognized memo type: unknown',
      ),
    );
  }

  return RoutingResult(
    destinationBaseAccount: parsed.address,
    id: routingId,
    source: routingSource,
    warnings: warnings,
  );
}

/// Retrieves whether a destination account requires a routing memo
/// (SEP-0029). Implementations can use Horizon, an indexer, or a cache.
typedef MemoRequirementFetcher = Future<bool> Function(String baseAccount);

/// Asynchronous variant of [extractRouting] that can additionally perform
/// network checks.
///
/// When [fetchMemoRequirement] is provided and the destination is a classic
/// account with no routing ID, it is consulted to determine whether the
/// account requires a memo (SEP-0029); if so,
/// [RoutingWarning.missingRequiredMemo] is appended. Fetch failures fail open,
/// returning the same result as [extractRouting].
///
/// Parsing errors are reported as a failed [Future] with an
/// [ExtractRoutingException].
Future<RoutingResult> extractRoutingAsync(
  RoutingInput input, {
  MemoRequirementFetcher? fetchMemoRequirement,
}) async {
  final result = extractRouting(input);
  if (fetchMemoRequirement == null ||
      result.destinationBaseAccount == null ||
      result.id != null ||
      result.destinationError != null) {
    return result;
  }

  try {
    if (await fetchMemoRequirement(result.destinationBaseAccount!)) {
      return RoutingResult(
        source: result.source,
        id: result.id,
        destinationBaseAccount: result.destinationBaseAccount,
        destinationError: result.destinationError,
        warnings: [...result.warnings, RoutingWarning.missingRequiredMemo],
      );
    }
  } catch (_) {
    // Network/configuration failures must not change the synchronous result.
  }
  return result;
}

/// Synchronous routing extraction.
///
/// **Deprecated:** [extractRouting] is now synchronous, so this alias is no
/// longer needed. Migrate by renaming the call:
///
/// ```dart
/// // Before
/// final result = extractRoutingSync(input);
/// // After
/// final result = extractRouting(input);
/// ```
///
/// Code that previously awaited `extractRouting(...)` should either drop the
/// `await` or, if it needs SEP-0029 memo checks, call [extractRoutingAsync].
@Deprecated(
  'extractRouting is now synchronous; use extractRouting(input) instead. '
  'For async network checks use extractRoutingAsync. '
  'extractRoutingSync will be removed in the next major release.',
)
RoutingResult extractRoutingSync(RoutingInput input) => extractRouting(input);
