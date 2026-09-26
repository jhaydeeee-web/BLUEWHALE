package routing

import (
	"encoding/json"
	"testing"
)

// The legacy multi-chain fields removed in #42 must not reappear in the wire
// format. This test decodes a fully-populated RoutingInput / RoutingResult
// and asserts the exact key set, so a stray field (or a dropped `omitempty`)
// shows up as a diff rather than as a silently-growing payload.
func TestRoutingInputJSONKeys(t *testing.T) {
	raw := `{
		"destination": "GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI",
		"memoType": "id",
		"memoValue": "007",
		"sourceAccount": "GA7QYNF7SZFX4X7X5JFZZ3UQ6BXHDSY2RKVKZKX5FFQJ1ZMZX1",
		"minSeverityLevel": "warn",
		"metadata": {"k": "v"}
	}`

	var decoded RoutingInput
	if err := json.Unmarshal([]byte(raw), &decoded); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}

	if decoded.Destination != "GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI" {
		t.Errorf("Destination = %q", decoded.Destination)
	}
	if decoded.MemoType != "id" || decoded.MemoValue != "007" {
		t.Errorf("memo fields = %q / %q", decoded.MemoType, decoded.MemoValue)
	}
	if decoded.MinSeverityLevel != "warn" {
		t.Errorf("MinSeverityLevel = %q", decoded.MinSeverityLevel)
	}
	if decoded.Metadata["k"] != "v" {
		t.Errorf("Metadata = %v", decoded.Metadata)
	}

	// The removed multi-chain fields must be ignored, not decoded.
	var generic map[string]json.RawMessage
	if err := json.Unmarshal([]byte(raw), &generic); err != nil {
		t.Fatalf("Unmarshal generic: %v", err)
	}
	encoded, err := json.Marshal(decoded)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}
	var roundTripped map[string]json.RawMessage
	if err := json.Unmarshal(encoded, &roundTripped); err != nil {
		t.Fatalf("Unmarshal round-tripped: %v", err)
	}

	want := map[string]bool{
		"destination": true, "memoType": true, "memoValue": true,
		"sourceAccount": true, "minSeverityLevel": true, "metadata": true,
	}
	for key := range roundTripped {
		if !want[key] {
			t.Errorf("unexpected key %q in RoutingInput JSON; removed legacy fields must stay gone", key)
		}
		delete(want, key)
	}
	for key := range want {
		t.Errorf("RoutingInput JSON is missing key %q", key)
	}
}

func TestRoutingInputOmitsUnsetFields(t *testing.T) {
	encoded, err := json.Marshal(RoutingInput{})
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}
	if string(encoded) != "{}" {
		t.Errorf("empty RoutingInput marshalled to %s, want {}", encoded)
	}
}

func TestRoutingResultJSONKeys(t *testing.T) {
	const g = "GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI"
	result := ExtractRouting(RoutingInput{Destination: g, MemoType: "id", MemoValue: "100"})

	encoded, err := json.Marshal(result)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}
	var keys map[string]json.RawMessage
	if err := json.Unmarshal(encoded, &keys); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}

	want := map[string]bool{
		"success": true, "destinationBaseAccount": true, "routingId": true,
		"routingSource": true,
	}
	for key := range keys {
		if !want[key] {
			t.Errorf("unexpected key %q in RoutingResult JSON; removed legacy fields must stay gone", key)
		}
		delete(want, key)
	}
	for key := range want {
		t.Errorf("RoutingResult JSON is missing key %q", key)
	}

	// `success` has no omitempty on purpose: a consumer must be able to
	// distinguish "false" from "absent".
	if _, ok := keys["success"]; !ok {
		t.Error("RoutingResult JSON must always carry \"success\"")
	}
}

func TestRoutingResultOmitsUnsetFields(t *testing.T) {
	encoded, err := json.Marshal(RoutingResult{})
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}
	if string(encoded) != `{"success":false}` {
		t.Errorf("zero RoutingResult marshalled to %s, want {\"success\":false}", encoded)
	}
}
