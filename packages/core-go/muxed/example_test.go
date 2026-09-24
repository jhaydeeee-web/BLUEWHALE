package muxed_test

import (
	"fmt"

	"github.com/REDISHFISH/BLUEWHALE/packages/core-go/muxed"
)

// ExampleDecodeMuxed splits a muxed M-address into its base G-address and
// 64-bit routing ID.
func ExampleDecodeMuxed() {
	baseG, id, err := muxed.DecodeMuxed("MAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQACABAAAAAAAAAAEVIG")
	if err != nil {
		fmt.Println("error:", err)
		return
	}

	fmt.Println("base account:", baseG)
	fmt.Println("id:", id)
	// Output:
	// base account: GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI
	// id: 9007199254740993
}
