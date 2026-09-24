package routing

import (
	"encoding/json"
	"strings"
	"testing"

	"github.com/REDISHFISH/BLUEWHALE/packages/core-go/address"
)

func TestRoutingIDUnmarshalJSONPreservesUint64Number(t *testing.T) {
	t.Parallel()

	payload := []byte(`{"id":18446744073709551615}`)
	var body struct {
		ID RoutingID `json:"id"`
	}

	if err := json.Unmarshal(payload, &body); err != nil {
		t.Fatalf("json.Unmarshal() error = %v", err)
	}

	if got := body.ID.String(); got != "18446744073709551615" {
		t.Fatalf("RoutingID.String() = %q, want %q", got, "18446744073709551615")
	}

	gotUint64, err := body.ID.Uint64()
	if err != nil {
		t.Fatalf("RoutingID.Uint64() error = %v", err)
	}

	if gotUint64 != ^uint64(0) {
		t.Fatalf("RoutingID.Uint64() = %d, want %d", gotUint64, ^uint64(0))
	}
}

func TestRoutingIDUnmarshalJSONAcceptsQuotedDecimalString(t *testing.T) {
	t.Parallel()

	payload := []byte(`{"id":"18446744073709551615"}`)
	var body struct {
		ID RoutingID `json:"id"`
	}

	if err := json.Unmarshal(payload, &body); err != nil {
		t.Fatalf("json.Unmarshal() error = %v", err)
	}

	if got := body.ID.String(); got != "18446744073709551615" {
		t.Fatalf("RoutingID.String() = %q, want %q", got, "18446744073709551615")
	}
}

func TestRoutingIDUnmarshalJSONRejectsInvalidNumbers(t *testing.T) {
	t.Parallel()

	testCases := []string{
		`{"id":18446744073709551616}`,
		`{"id":-1}`,
		`{"id":1.5}`,
		`{"id":"not-a-number"}`,
	}

	for _, payload := range testCases {
		payload := payload
		t.Run(payload, func(t *testing.T) {
			t.Parallel()

			var body struct {
				ID RoutingID `json:"id"`
			}

			if err := json.Unmarshal([]byte(payload), &body); err == nil {
				t.Fatalf("json.Unmarshal(%s) error = nil, want non-nil", payload)
			}
		})
	}
}

func TestRoutingResultMarshalJSONZeroValueOmitsOptionalFields(t *testing.T) {
	t.Parallel()

	got, err := json.Marshal(RoutingResult{})
	if err != nil {
		t.Fatalf("json.Marshal() error = %v", err)
	}

	if want := `{"success":false}`; string(got) != want {
		t.Fatalf("json.Marshal(RoutingResult{}) = %s, want %s", got, want)
	}
}

func TestRoutingResultMarshalJSONDestinationError(t *testing.T) {
	t.Parallel()

	testCases := []struct {
		name string
		err  *DestinationError
		want string
	}{
		{
			name: "nil pointer is omitted",
			err:  nil,
			want: `{"success":false}`,
		},
		{
			name: "empty code and message are omitted",
			err:  &DestinationError{},
			want: `{"success":false,"destinationError":{}}`,
		},
		{
			name: "populated error is serialized",
			err:  &DestinationError{Code: address.ErrUnknownPrefix, Message: "bad prefix"},
			want: `{"success":false,"destinationError":{"code":"` + string(address.ErrUnknownPrefix) + `","message":"bad prefix"}}`,
		},
	}

	for _, tc := range testCases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()

			got, err := json.Marshal(RoutingResult{DestinationError: tc.err})
			if err != nil {
				t.Fatalf("json.Marshal() error = %v", err)
			}

			if string(got) != tc.want {
				t.Fatalf("json.Marshal() = %s, want %s", got, tc.want)
			}
		})
	}
}

func TestExtractRoutingSuccessOmitsDestinationError(t *testing.T) {
	t.Parallel()

	result := ExtractRouting(RoutingInput{Destination: benchGAddr, MemoType: "none"})
	if result.DestinationError != nil {
		t.Fatalf("DestinationError = %+v, want nil", result.DestinationError)
	}

	got, err := json.Marshal(result)
	if err != nil {
		t.Fatalf("json.Marshal() error = %v", err)
	}

	if strings.Contains(string(got), "destinationError") {
		t.Fatalf("json.Marshal() = %s, want no destinationError key", got)
	}
}
