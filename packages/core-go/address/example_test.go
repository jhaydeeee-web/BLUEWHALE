package address_test

import (
	"fmt"

	"github.com/REDISHFISH/BLUEWHALE/packages/core-go/address"
)

// ExampleDetect identifies the kind of a Stellar address from its version byte.
func ExampleDetect() {
	for _, addr := range []string{
		"GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI",
		"MAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQACABAAAAAAAAAAEVIG",
	} {
		kind, err := address.Detect(addr)
		if err != nil {
			fmt.Println("error:", err)
			continue
		}
		fmt.Println(kind)
	}

	if _, err := address.Detect("not-an-address"); err != nil {
		fmt.Println("invalid address rejected")
	}
	// Output:
	// G
	// M
	// invalid address rejected
}
