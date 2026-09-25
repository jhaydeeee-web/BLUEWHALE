import { describe, it, expect } from "vitest";
import { vectors } from "@redishfish/bluewhale-spec";
import {
  detect,
  encodeMuxed,
  decodeMuxed,
  extractRouting,
  extractRoutingFromURI,
} from "../index";
import { parse } from "../address/parse";

/**
 * Legacy placeholder addresses used by `spec/vectors.json` for the
 * `extract_routing` vectors. They predate checksum enforcement and are only
 * 50 characters long, so no implementation can parse them. core-dart already
 * substitutes canonical addresses for these; core-go skips the affected
 * vectors. core-ts does the same so all three SDKs exercise identical
 * routing behaviour.
 */
const LEGACY_VECTOR_G = "GA7QYNF7SZFX4X7X5JFZZ3UQ6BXHDSY2RKVKZKX5FFQJ1ZMZX1";
const LEGACY_VECTOR_M_PREFIX =
  "MA7QYNF7SZFX4X7X5JFZZ3UQ6BXHDSY2RKVKZKX5FFQJ1ZMZX1";
const LEGACY_VECTOR_C_PREFIX =
  "CA7QYNF7SZFX4X7X5JFZZ3UQ6BXHDSY2RKVKZKX5FFQJ1ZMZX1";

const VALID_G = "GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI";
const VALID_C = "CDLZFC3SYJYDZT7K67VZ75HPJVIEUVNIXF47ZG2FB2RMQQVU2HHGCYSC";

/**
 * Maps a legacy placeholder destination onto a canonical, checksum-valid
 * address. The routing ID encoded into a substituted M-address is taken from
 * the vector's own `expected.routingId` so the decoded ID still matches.
 */
function normalizeVectorDestination(
  destination: string,
  expectedRoutingId: unknown
): string {
  if (destination === LEGACY_VECTOR_G) return VALID_G;
  if (destination.startsWith(LEGACY_VECTOR_M_PREFIX)) {
    return encodeMuxed(VALID_G, BigInt(String(expectedRoutingId)));
  }
  if (destination.startsWith(LEGACY_VECTOR_C_PREFIX)) return VALID_C;
  return destination;
}

function normalizeExpectedBaseAccount(
  destinationBaseAccount: unknown
): string | null {
  if (destinationBaseAccount === null || destinationBaseAccount === undefined) {
    return null;
  }
  if (destinationBaseAccount === LEGACY_VECTOR_G) return VALID_G;
  return String(destinationBaseAccount);
}

function normalizeRoutingId(value: any): string | null {
  if (value === null || value === undefined) return null;
  return typeof value === "bigint" ? value.toString() : String(value);
}

describe("Normative Vector Tests", () => {
  vectors.cases.forEach((c: any) => {
    it(`[${c.module}] ${c.description}`, () => {
      switch (c.module) {
        case "detect": {
          const kind = detect(c.input.address);
          expect(kind).toBe(c.expected.kind);
          break;
        }
        case "muxed_encode": {
          const baseG = c.input.base_g ?? c.input.gAddress;
          const mAddress = encodeMuxed(baseG, BigInt(c.input.id));
          expect(mAddress).toBe(c.expected.mAddress);
          break;
        }
        case "muxed_decode": {
          if (c.expected.expected_error) {
            expect(() => decodeMuxed(c.input.mAddress)).toThrow();
          } else {
            const result = decodeMuxed(c.input.mAddress);
            expect(result.baseG).toBe(c.expected.base_g);
            expect(result.id).toBe(BigInt(c.expected.id));
          }
          break;
        }
        case "extract_routing": {
          const input = c.input as any;
          const destination = normalizeVectorDestination(
            input.destination,
            c.expected.routingId
          );
          const routingInput = {
            destination,
            memoType: input.memoType,
            memoValue: input.memoValue || null,
            sourceAccount: input.sourceAccount || null,
          };

          const result = extractRouting(routingInput);
          expect(result.destinationBaseAccount).toBe(
            normalizeExpectedBaseAccount(c.expected.destinationBaseAccount)
          );
          expect(normalizeRoutingId(result.routingId)).toBe(
            normalizeRoutingId(c.expected.routingId)
          );
          expect(result.routingSource).toBe(c.expected.routingSource);
          expect(result.warnings).toEqual(c.expected.warnings);
          break;
        }
        case "extract_from_uri": {
          const result = extractRoutingFromURI(c.input.uri);
          expect(result.success).toBe(c.expected.success);
          if (c.expected.success && result.success) {
            expect(result.routing.destinationBaseAccount).toBe(
              normalizeExpectedBaseAccount(
                c.expected.routing.destinationBaseAccount
              )
            );
            expect(normalizeRoutingId(result.routing.routingId)).toBe(
              normalizeRoutingId(c.expected.routing.routingId)
            );
            expect(result.routing.routingSource).toBe(
              c.expected.routing.routingSource
            );
            expect(result.routing.warnings).toEqual(
              c.expected.routing.warnings
            );
          } else if (!c.expected.success && !result.success) {
            expect(result.code).toBe(c.expected.code);
          }
          break;
        }
      }
    });
  });
});

describe("Legacy placeholder vector normalization", () => {
  it("substitutes a parseable G-address for the legacy placeholder", () => {
    const substituted = normalizeVectorDestination(LEGACY_VECTOR_G, null);
    expect(parse(substituted).kind).toBe("G");
  });

  it("re-encodes the legacy M-address placeholder with the vector's routing ID", () => {
    const substituted = normalizeVectorDestination(
      `${LEGACY_VECTOR_M_PREFIX}AAJZRE6LRE6LRE6LRE6LRE6LRE6LRE6LRE6LRE6LRE6LRE6LRE6LR`,
      "9007199254740993"
    );
    const parsed = parse(substituted);
    expect(parsed.kind).toBe("M");
    expect((parsed as any).muxedId).toBe(BigInt("9007199254740993"));
  });

  it("substitutes a parseable C-address for the legacy placeholder", () => {
    const substituted = normalizeVectorDestination(LEGACY_VECTOR_C_PREFIX, null);
    expect(parse(substituted).kind).toBe("C");
  });

  it("leaves canonical destinations untouched", () => {
    expect(normalizeVectorDestination(VALID_G, null)).toBe(VALID_G);
    expect(normalizeVectorDestination(VALID_C, null)).toBe(VALID_C);
  });
});
