package routing

import (
	"testing"
)

// These addresses are the same as the ones used in extract_test.go.
const (
	benchGAddr = "GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI"
	benchMAddr = "MAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQACABAAAAAAAAAAEVIG"
)

// BenchmarkNormalizeMemoTextID_Canonical benchmarks the hot path: a valid canonical
// uint64 string with no leading zeros. After optimization this should be 0 allocs/op
// because the normalized sub-slice aliases the input and no big.Int or regex is used.
func BenchmarkNormalizeMemoTextID_Canonical(b *testing.B) {
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = NormalizeMemoTextID("9007199254740993")
	}
}

// BenchmarkNormalizeMemoTextID_MaxUint64 exercises the boundary comparison against
// the uint64 ceiling. Should also be 0 allocs/op after optimization.
func BenchmarkNormalizeMemoTextID_MaxUint64(b *testing.B) {
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = NormalizeMemoTextID("18446744073709551615")
	}
}

// BenchmarkNormalizeMemoTextID_LeadingZeros exercises the leading-zero normalization
// path, which emits a warning and therefore allocates one Warning struct.
func BenchmarkNormalizeMemoTextID_LeadingZeros(b *testing.B) {
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = NormalizeMemoTextID("007")
	}
}

// BenchmarkNormalizeMemoTextID_NonNumeric exercises the early-exit path where the
// input is rejected without any allocation.
func BenchmarkNormalizeMemoTextID_NonNumeric(b *testing.B) {
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = NormalizeMemoTextID("not-a-number")
	}
}

// BenchmarkIsAllDigits shows the zero-allocation cost of the digit scanner that
// replaces regexp.MatchString on the hot path.
func BenchmarkIsAllDigits(b *testing.B) {
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = isAllDigits("18446744073709551615")
	}
}

// BenchmarkFitsUint64 shows the zero-allocation cost of the string-comparison
// range check that replaces big.Int.Cmp.
func BenchmarkFitsUint64(b *testing.B) {
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = fitsUint64("18446744073709551615")
	}
}

// BenchmarkExtractRouting_GAddr_MemoID benchmarks the most common exchange-deposit
// path: a G-address destination with a MEMO_ID routing identifier.
func BenchmarkExtractRouting_GAddr_MemoID(b *testing.B) {
	b.ReportAllocs()
	input := RoutingInput{
		Destination: benchGAddr,
		MemoType:    "id",
		MemoValue:   "100",
	}
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = ExtractRouting(input)
	}
}

// BenchmarkExtractRouting_GAddr_NoMemo benchmarks a G-address with no memo — the
// simplest G-address path.
func BenchmarkExtractRouting_GAddr_NoMemo(b *testing.B) {
	b.ReportAllocs()
	input := RoutingInput{
		Destination: benchGAddr,
		MemoType:    "none",
	}
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = ExtractRouting(input)
	}
}

// BenchmarkExtractRouting_MAddr benchmarks a muxed (M-address) destination, which
// carries the routing ID inline and skips memo processing.
func BenchmarkExtractRouting_MAddr(b *testing.B) {
	b.ReportAllocs()
	input := RoutingInput{
		Destination: benchMAddr,
		MemoType:    "none",
	}
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = ExtractRouting(input)
	}
}

// BenchmarkExtractRouting_GAddr_MemoID_Parallel benchmarks concurrent throughput
// for the most common deposit path under exchange-level parallelism.
// All state is read-only so there is no lock contention.
func BenchmarkExtractRouting_GAddr_MemoID_Parallel(b *testing.B) {
	b.ReportAllocs()
	input := RoutingInput{
		Destination: benchGAddr,
		MemoType:    "id",
		MemoValue:   "9007199254740993",
	}
	b.ResetTimer()
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			_ = ExtractRouting(input)
		}
	})
}

// BenchmarkExtractRouting_MAddr_Parallel benchmarks concurrent muxed-address
// routing to simulate high-throughput trading engine ingestion.
func BenchmarkExtractRouting_MAddr_Parallel(b *testing.B) {
	b.ReportAllocs()
	input := RoutingInput{
		Destination: benchMAddr,
		MemoType:    "none",
	}
	b.ResetTimer()
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			_ = ExtractRouting(input)
		}
	})
}

// BenchmarkNormalizeUnsupportedMemoType covers the canonical fast path, the
// alias normalization path, and the early rejection of over-long inputs.
// Every case should report 0 allocs/op.
func BenchmarkNormalizeUnsupportedMemoType(b *testing.B) {
	cases := []struct {
		name  string
		input string
	}{
		{"hash", "hash"},
		{"return", "return"},
		{"none", "none"},
		{"id", "id"},
		{"text", "text"},
		{"MEMO_HASH", "MEMO_HASH"},
		{"memo-return", "memo-return"},
		{"unknown", "custom"},
		{"too_long", "definitely_not_a_memo_type"},
	}
	for _, tc := range cases {
		b.Run(tc.name, func(b *testing.B) {
			b.ReportAllocs()
			for i := 0; i < b.N; i++ {
				_ = normalizeUnsupportedMemoType(tc.input)
			}
		})
	}
}
