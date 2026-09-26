/**
 * Cross-language warning-code parity (issue #76).
 *
 * `spec/schema.json` splits warning codes across four `oneOf` branches:
 *
 *  - `warningNormalization`      → NON_CANONICAL_{ADDRESS,ROUTING_ID}
 *  - `warningInvalidDestination` → INVALID_DESTINATION
 *  - `warningUnsupportedMemoType`→ UNSUPPORTED_MEMO_TYPE
 *  - `warningGeneric`            → the context-free remainder
 *
 * Unioning the `code` enums from every branch yields the normative set. This
 * test reads the schema rather than hard-coding the list, so adding a code to
 * the spec without adding it here — or to core-go / core-dart — fails CI
 * instead of silently diverging.
 */
import { describe, it, expect } from "vitest";
import { schema } from "@redishfish/bluewhale-spec";
import { extractRouting } from "../routing/extract";
import { parse } from "../address/parse";
import type { WarningCode } from "../address/types";

type CodeSchema = { enum?: string[]; const?: string };
type Definition = { properties?: { code?: CodeSchema } };

/** Every warning code declared anywhere in the schema's `oneOf` branches. */
const SPEC_DECLARED_CODES: readonly string[] = Object.values(
  schema.definitions as Record<string, Definition>
).flatMap((definition) => {
  const code = definition.properties?.code;
  if (!code) return [];
  if (code.const !== undefined) return [code.const];
  return code.enum ?? [];
});

/**
 * `INVALID_STRKEY` is a `detect`-module sentinel in `spec/vectors.json`, not a
 * routing warning: no SDK emits it as a `Warning`, and the normative list in
 * issue #76 omits it. Everything else the schema declares must be emittable.
 */
const SPEC_WARNING_CODES: readonly string[] = SPEC_DECLARED_CODES.filter(
  (code) => code !== "INVALID_STRKEY"
);

/** The codes core-ts declares in its `WarningCode` union. */
const TS_WARNING_CODES: readonly WarningCode[] = [
  "NON_CANONICAL_ADDRESS",
  "NON_CANONICAL_ROUTING_ID",
  "MEMO_IGNORED_FOR_MUXED",
  "MEMO_PRESENT_WITH_MUXED",
  "CONTRACT_SENDER_DETECTED",
  "MEMO_TEXT_UNROUTABLE",
  "MEMO_ID_INVALID_FORMAT",
  "UNSUPPORTED_MEMO_TYPE",
  "INVALID_DESTINATION",
  "MISSING_REQUIRED_MEMO",
];

const G = "GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI";
const M = "MAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQACAAAAAAAAAAAAD672";
const C = "CDLZFC3SYJYDZT7K67VZ75HPJVIEUVNIXF47ZG2FB2RMQQVU2HHGCYSC";

describe("Warning code parity with spec/schema.json (#76)", () => {
  it("derives a non-empty code set from the schema", () => {
    expect(SPEC_WARNING_CODES.length).toBeGreaterThan(0);
  });

  it("declares exactly the schema's warning codes", () => {
    expect([...TS_WARNING_CODES].sort()).toEqual([...SPEC_WARNING_CODES].sort());
  });

  it("has no duplicates in the schema's code set", () => {
    expect(new Set(SPEC_DECLARED_CODES).size).toBe(SPEC_DECLARED_CODES.length);
  });

  it("only emits codes that are declared in the schema", () => {
    const inputs = [
      { destination: G, memoType: "none" },
      { destination: G, memoType: "id", memoValue: "007" },
      { destination: G, memoType: "text", memoValue: "not-a-number" },
      { destination: G, memoType: "hash" },
      { destination: G, memoType: "return" },
      { destination: G, memoType: "signed" },
      { destination: G, memoType: "text", memoValue: "7", sourceAccount: C },
      { destination: C, memoType: "none" },
      { destination: M, memoType: "none" },
      { destination: M, memoType: "id", memoValue: "7" },
      { destination: M, memoType: "hash" },
      { destination: G.toLowerCase(), memoType: "none" },
    ] as const;

    const unknown: string[] = [];
    for (const input of inputs) {
      for (const warning of extractRouting({ ...input } as any).warnings) {
        if (!SPEC_DECLARED_CODES.includes(warning.code)) {
          unknown.push(`${warning.code} (from ${JSON.stringify(input)})`);
        }
      }
      for (const warning of parse(input.destination).warnings ?? []) {
        if (!SPEC_DECLARED_CODES.includes(warning.code)) {
          unknown.push(`${warning.code} (from parse ${input.destination})`);
        }
      }
    }

    expect(unknown).toEqual([]);
  });

  it("emits UNSUPPORTED_MEMO_TYPE with the required context for hash/return", () => {
    // The schema's `warningUnsupportedMemoType` branch requires `context`, so a
    // bare `MEMO_TEXT_UNROUTABLE` — what this used to emit — could not be
    // validated against the spec at all.
    for (const memoType of ["hash", "return"] as const) {
      const result = extractRouting({ destination: G, memoType });
      expect(result.warnings).toEqual([
        {
          code: "UNSUPPORTED_MEMO_TYPE",
          severity: "warn",
          message: `Memo type ${memoType} is not supported for routing.`,
          context: { memoType },
        },
      ]);
    }
  });

  it("reports an unrecognized memo type as UNSUPPORTED_MEMO_TYPE/unknown", () => {
    const result = extractRouting({ destination: G, memoType: "signed" });
    expect(result.warnings).toEqual([
      {
        code: "UNSUPPORTED_MEMO_TYPE",
        severity: "warn",
        message: "Unrecognized memo type: signed",
        context: { memoType: "unknown" },
      },
    ]);
  });

  it("still reports a non-numeric MEMO_TEXT as MEMO_TEXT_UNROUTABLE", () => {
    const result = extractRouting({
      destination: G,
      memoType: "text",
      memoValue: "not-a-number",
    });
    expect(result.warnings).toEqual([
      {
        code: "MEMO_TEXT_UNROUTABLE",
        severity: "warn",
        message: "MEMO_TEXT was not a valid numeric uint64.",
      },
    ]);
  });

  it("carries context for INVALID_DESTINATION", () => {
    const result = extractRouting({ destination: C, memoType: "none" });
    expect(result.warnings).toEqual([
      {
        code: "INVALID_DESTINATION",
        severity: "error",
        message: "C address is not a valid destination",
        context: { destinationKind: "C" },
      },
    ]);
  });
});
