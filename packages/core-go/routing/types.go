package routing

import "github.com/REDISHFISH/BLUEWHALE/packages/core-go/address"

// RoutingInput is everything needed to resolve a deposit route.
//
// The JSON tags are the wire contract shared with core-ts and core-dart, and
// every field is `omitempty` so an unset field is simply absent from the
// payload rather than appearing as an empty string.
type RoutingInput struct {
	// Destination is the payment destination: a G, M or C address.
	Destination string `json:"destination,omitempty"`

	// MemoType is "none", "id", "text", "hash" or "return". An empty value is
	// treated as "none".
	MemoType string `json:"memoType,omitempty"`

	// MemoValue is the raw memo payload, interpreted according to MemoType.
	MemoValue string `json:"memoValue,omitempty"`

	// SourceAccount is the transaction's source account. A Soroban contract
	// source ("C...") clears the routing state and emits
	// address.WarnContractSenderDetected.
	SourceAccount string `json:"sourceAccount,omitempty"`

	// MinSeverityLevel drops warnings below this severity ("info", "warn" or
	// "error"). Empty means "info": all warnings are returned.
	MinSeverityLevel string `json:"minSeverityLevel,omitempty"`

	// Metadata carries caller-defined annotations through to the consumer of
	// RoutingResult. The routing engine never reads it.
	Metadata map[string]string `json:"metadata,omitempty"`
}

// RoutingResult is the outcome of resolving a RoutingInput.
//
// Success and ErrorMessage are set by the SEP-0007 URI entry point
// (ExtractRoutingFromURI) to describe whether a URI could be parsed at all;
// ExtractRouting itself leaves them zero, because an unusable address is
// reported through DestinationError rather than as a transport failure.
type RoutingResult struct {
	// Success is true when the request produced a routing result. See the
	// type comment for which entry points set it.
	Success bool `json:"success"`

	// ErrorMessage describes a transport-level failure, e.g. a malformed URI.
	// It never contains URI content, so it is safe to log.
	ErrorMessage string `json:"errorMessage,omitempty"`

	// DestinationBaseAccount is the classic G address of the destination, even
	// when the payment was sent to a muxed M address. Empty when the
	// destination could not be resolved.
	DestinationBaseAccount string `json:"destinationBaseAccount,omitempty"`

	// RoutingID is the resolved 64-bit routing ID, or nil when none was found.
	RoutingID *RoutingID `json:"routingId,omitempty"`

	// RoutingSource is "muxed", "memo" or "none".
	RoutingSource string `json:"routingSource,omitempty"`

	// Warnings are the non-blocking findings for this result, already filtered
	// by RoutingInput.MinSeverityLevel.
	Warnings []address.Warning `json:"warnings,omitempty"`

	// DestinationError describes why the destination itself was unusable, e.g.
	// an unknown prefix or a checksum mismatch.
	DestinationError *DestinationError `json:"destinationError,omitempty"`
}

// DestinationError is part of RoutingResult's wire schema. Both fields are
// omitempty for the same reason RoutingResult.ErrorMessage is: a consumer of
// the JSON should not have to distinguish "no message" from "empty message",
// and an error that only carries a code should not advertise a blank string.
type DestinationError struct {
	Code    address.ErrorCode `json:"code,omitempty"`
	Message string            `json:"message,omitempty"`
}
