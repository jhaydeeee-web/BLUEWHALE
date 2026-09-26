package routing

import "testing"

func BenchmarkNormalizeUnsupportedMemoType(b *testing.B) {
	for _, mt := range []string{"none", "id", "text", "hash", "return", "MEMO_HASH", "memo-return", "bogus"} {
		b.Run(mt, func(b *testing.B) {
			b.ReportAllocs()
			for i := 0; i < b.N; i++ {
				_ = normalizeUnsupportedMemoType(mt)
			}
		})
	}
}
