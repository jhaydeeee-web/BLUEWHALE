package routing

// foldedMemoTypeEquals reports whether s, after lower-casing ASCII letters and
// skipping '_' and '-', equals want (which must already be lower-case with no
// separators). It performs no allocations.
func foldedMemoTypeEquals(s, want string) bool {
	j := 0
	for i := 0; i < len(s); i++ {
		c := s[i]
		if c == '_' || c == '-' {
			continue
		}
		if 'A' <= c && c <= 'Z' {
			c += 'a' - 'A'
		}
		if j >= len(want) || want[j] != c {
			return false
		}
		j++
	}
	return j == len(want)
}
