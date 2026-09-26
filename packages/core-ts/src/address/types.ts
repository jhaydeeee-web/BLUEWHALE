import { ErrorCode } from "./errors";
export type AddressKind = "G" | "M" | "C";

/**
 * Severity levels for validation warnings.
 * Used with `minSeverityLevel` to filter warnings by importance.
 *
 * The string union (rather than an enum) is deliberate: the wire format is
 * `"info" | "warn" | "error"`, so an enum would force a conversion at every
 * JSON boundary and break byte-level parity with core-go and core-dart.
 */
export type WarningSeverity = "info" | "warn" | "error";

/**
 * Every warning code this SDK can emit.
 *
 * These identifiers are normative wire strings defined by
 * `spec/schema.json` and are byte-for-byte identical to the equivalent
 * constant in core-go (`address.WarnNonCanonicalAddress`, …) and core-dart
 * (`WarningCode.nonCanonicalAddress`, …). Adding or renaming a code means
 * changing all three SDKs and the spec in the same commit; the cross-language
 * audit lives in `src/spec/warning-codes.test.ts`.
 */
export type WarningCode =
  | "NON_CANONICAL_ADDRESS"
  | "NON_CANONICAL_ROUTING_ID"
  | "MEMO_IGNORED_FOR_MUXED"
  | "MEMO_PRESENT_WITH_MUXED"
  | "CONTRACT_SENDER_DETECTED"
  | "MEMO_TEXT_UNROUTABLE"
  | "MEMO_ID_INVALID_FORMAT"
  | "UNSUPPORTED_MEMO_TYPE"
  | "INVALID_DESTINATION"
  | "MISSING_REQUIRED_MEMO";

export type Warning =
  | {
      code: "NON_CANONICAL_ADDRESS" | "NON_CANONICAL_ROUTING_ID";
      severity: "warn";
      message: string;
      normalization: {
        original: string;
        normalized: string;
      };
    }
  | {
      code: "INVALID_DESTINATION";
      severity: "error";
      message: string;
      context: {
        destinationKind: "C";
      };
    }
  | {
      code: "UNSUPPORTED_MEMO_TYPE";
      severity: "warn";
      message: string;
      context: {
        memoType: "hash" | "return" | "unknown";
      };
    }
  | {
      code: Exclude<
        WarningCode,
        | "NON_CANONICAL_ADDRESS"
        | "NON_CANONICAL_ROUTING_ID"
        | "INVALID_DESTINATION"
        | "UNSUPPORTED_MEMO_TYPE"
        | "MISSING_REQUIRED_MEMO"
      >;
      severity: "info" | "warn" | "error";
      message: string;
    }
  | {
      code: "MISSING_REQUIRED_MEMO";
      severity: "error";
      message: string;
    };

export type Address =
  | {
      kind: "G";
      address: string;
      warnings: Warning[];
    }
  | {
      kind: "M";
      address: string;
      baseG: string;
      muxedId: bigint;
      warnings: Warning[];
    }
  | {
      kind: "C";
      address: string;
      warnings: Warning[];
    };

export type ParseResult =
  | Address
  | {
      kind: "invalid";
      error: {
        code: ErrorCode;
        input: string;
        message: string;
      };
    };

export { ErrorCode } from "./errors";
