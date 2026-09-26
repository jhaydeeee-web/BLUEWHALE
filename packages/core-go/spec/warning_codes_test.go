// Cross-language warning-code parity (issue #76).
//
// spec/schema.json splits warning codes across four `oneOf` branches:
//
//	warningNormalization       -> NON_CANONICAL_{ADDRESS,ROUTING_ID}
//	warningInvalidDestination  -> INVALID_DESTINATION
//	warningUnsupportedMemoType -> UNSUPPORTED_MEMO_TYPE
//	warningGeneric             -> the context-free remainder
//
// Unioning the `code` enums from every branch yields the normative set. This
// test reads the schema rather than hard-coding the list, so adding a code to
// the spec without adding it to an SDK fails CI instead of silently diverging.
package spec

import (
	"encoding/json"
	"os"
	"reflect"
	"sort"
	"testing"

	"github.com/REDISHFISH/BLUEWHALE/packages/core-go/address"
	"github.com/REDISHFISH/BLUEWHALE/packages/core-go/routing"
)

type schemaDoc struct {
	Definitions map[string]struct {
		Properties struct {
			Code struct {
				Const string   `json:"const"`
				Enum  []string `json:"enum"`
			} `json:"code"`
		} `json:"properties"`
	} `json:"definitions"`
}

const schemaPath = "../../../spec/schema.json"

// specWarningCodes returns every warning code declared in the schema.
//
// INVALID_STRKEY is excluded: it is a `detect`-module sentinel in
// spec/vectors.json rather than a routing warning. No SDK emits it as a
// Warning, and the normative list in issue #76 omits it.
func specWarningCodes(t *testing.T) []string {
	t.Helper()

	raw, err := os.ReadFile(schemaPath)
	if err != nil {
		t.Fatalf("failed to read %s: %v", schemaPath, err)
	}

	var doc schemaDoc
	if err := json.Unmarshal(raw, &doc); err != nil {
		t.Fatalf("failed to unmarshal %s: %v", schemaPath, err)
	}

	var codes []string
	for _, definition := range doc.Definitions {
		switch {
		case definition.Properties.Code.Const != "":
			codes = append(codes, definition.Properties.Code.Const)
		default:
			codes = append(codes, definition.Properties.Code.Enum...)
		}
	}

	var filtered []string
	for _, code := range codes {
		if code != "INVALID_STRKEY" {
			filtered = append(filtered, code)
		}
	}
	if len(filtered) == 0 {
		t.Fatal("derived no warning codes from the schema")
	}
	return filtered
}

func TestWarningCodesMatchSpec(t *testing.T) {
	want := specWarningCodes(t)
	sort.Strings(want)

	got := make([]string, 0, len(address.AllWarningCodes))
	for _, code := range address.AllWarningCodes {
		got = append(got, code.String())
	}
	sort.Strings(got)

	if !reflect.DeepEqual(got, want) {
		t.Errorf("address.AllWarningCodes = %v, want %v", got, want)
	}
}

func TestWarningCodesHaveNoDuplicates(t *testing.T) {
	seen := make(map[address.WarningCode]bool, len(address.AllWarningCodes))
	for _, code := range address.AllWarningCodes {
		if seen[code] {
			t.Errorf("duplicate warning code %q in address.AllWarningCodes", code)
		}
		seen[code] = true
	}
}

func TestWarningCodeIsKnown(t *testing.T) {
	for _, code := range address.AllWarningCodes {
		if !code.IsKnown() {
			t.Errorf("%q.IsKnown() = false, want true", code)
		}
	}
	if address.WarningCode("NOT_A_CODE").IsKnown() {
		t.Error("NOT_A_CODE.IsKnown() = true, want false")
	}
}

// TestExtractedWarningsAreSpecCodes exercises the routing entry points and
// asserts that every warning they emit is a code the schema declares.
func TestExtractedWarningsAreSpecCodes(t *testing.T) {
	known := make(map[address.WarningCode]bool, len(address.AllWarningCodes))
	for _, code := range address.AllWarningCodes {
		known[code] = true
	}

	const (
		g = "GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI"
		m = "MAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQACAAAAAAAAAAAAD672"
		c = "CDLZFC3SYJYDZT7K67VZ75HPJVIEUVNIXF47ZG2FB2RMQQVU2HHGCYSC"
	)

	inputs := []routing.RoutingInput{
		{Destination: g, MemoType: "none"},
		{Destination: g, MemoType: "id", MemoValue: "007"},
		{Destination: g, MemoType: "text", MemoValue: "not-a-number"},
		{Destination: g, MemoType: "hash"},
		{Destination: g, MemoType: "return"},
		{Destination: g, MemoType: "signed"},
		{Destination: g, MemoType: "text", MemoValue: "7", SourceAccount: c},
		{Destination: c, MemoType: "none"},
		{Destination: m, MemoType: "none"},
		{Destination: m, MemoType: "id", MemoValue: "7"},
		{Destination: m, MemoType: "hash"},
		{Destination: g, MemoType: "none", SourceAccount: c},
	}

	for _, input := range inputs {
		result := routing.ExtractRouting(input)
		for _, warning := range result.Warnings {
			if !known[warning.Code] {
				t.Errorf("ExtractRouting(%+v) emitted undeclared code %q", input, warning.Code)
			}
		}
	}
}

// TestUnsupportedMemoTypeCarriesContext pins the wire shape that
// spec/schema.json requires for UNSUPPORTED_MEMO_TYPE and
// INVALID_DESTINATION, and that core-ts and core-dart also emit.
func TestUnsupportedMemoTypeCarriesContext(t *testing.T) {
	const g = "GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI"
	const c = "CDLZFC3SYJYDZT7K67VZ75HPJVIEUVNIXF47ZG2FB2RMQQVU2HHGCYSC"

	tests := []struct {
		name     string
		input    routing.RoutingInput
		wantCode address.WarningCode
		wantCtx  address.WarningContext
	}{
		{
			name:     "hash",
			input:    routing.RoutingInput{Destination: g, MemoType: "hash"},
			wantCode: address.WarnUnsupportedMemoType,
			wantCtx:  address.WarningContext{MemoType: "hash"},
		},
		{
			name:     "return",
			input:    routing.RoutingInput{Destination: g, MemoType: "return"},
			wantCode: address.WarnUnsupportedMemoType,
			wantCtx:  address.WarningContext{MemoType: "return"},
		},
		{
			name:     "unrecognized",
			input:    routing.RoutingInput{Destination: g, MemoType: "signed"},
			wantCode: address.WarnUnsupportedMemoType,
			wantCtx:  address.WarningContext{MemoType: "unknown"},
		},
		{
			name:     "invalid destination",
			input:    routing.RoutingInput{Destination: c, MemoType: "none"},
			wantCode: address.WarnInvalidDestination,
			wantCtx:  address.WarningContext{DestinationKind: "C"},
		},
	}

	for _, tc := range tests {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			result := routing.ExtractRouting(tc.input)
			if len(result.Warnings) != 1 {
				t.Fatalf("warnings = %+v, want exactly 1", result.Warnings)
			}
			got := result.Warnings[0]
			if got.Code != tc.wantCode {
				t.Errorf("code = %q, want %q", got.Code, tc.wantCode)
			}
			if got.Context == nil {
				t.Fatalf("context = nil, want %+v", tc.wantCtx)
			}
			if *got.Context != tc.wantCtx {
				t.Errorf("context = %+v, want %+v", *got.Context, tc.wantCtx)
			}
		})
	}
}

// TestMemoTextUnroutableIsNotUsedForUnsupportedTypes guards the distinction
// the three SDKs previously disagreed on: MEMO_TEXT_UNROUTABLE describes a
// MEMO_TEXT value that is not a numeric uint64, while an unusable *memo type*
// is UNSUPPORTED_MEMO_TYPE.
func TestMemoTextUnroutableIsNotUsedForUnsupportedTypes(t *testing.T) {
	const g = "GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI"

	unroutable := routing.ExtractRouting(routing.RoutingInput{
		Destination: g, MemoType: "text", MemoValue: "not-a-number",
	})
	if len(unroutable.Warnings) != 1 || unroutable.Warnings[0].Code != address.WarnMemoTextUnroutable {
		t.Errorf("non-numeric MEMO_TEXT warnings = %+v, want a single %q", unroutable.Warnings, address.WarnMemoTextUnroutable)
	}

	for _, memoType := range []string{"hash", "return", "signed"} {
		result := routing.ExtractRouting(routing.RoutingInput{Destination: g, MemoType: memoType})
		for _, warning := range result.Warnings {
			if warning.Code == address.WarnMemoTextUnroutable {
				t.Errorf("memoType %q emitted %q; want %q", memoType, warning.Code, address.WarnUnsupportedMemoType)
			}
		}
	}
}
