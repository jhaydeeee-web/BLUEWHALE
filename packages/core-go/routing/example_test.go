package routing_test

import (
	"fmt"

	"github.com/REDISHFISH/BLUEWHALE/packages/core-go/routing"
)

// ExampleExtractRouting resolves a deposit sent to a G-address with a
// MEMO_ID routing identifier.
func ExampleExtractRouting() {
	result := routing.ExtractRouting(routing.RoutingInput{
		Destination: "GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI",
		MemoType:    "id",
		MemoValue:   "100",
	})

	fmt.Println("base account:", result.DestinationBaseAccount)
	fmt.Println("routing id:", result.RoutingID)
	fmt.Println("source:", result.RoutingSource)
	fmt.Println("warnings:", len(result.Warnings))
	// Output:
	// base account: GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI
	// routing id: 100
	// source: memo
	// warnings: 0
}

// ExampleExtractRouting_muxed shows that the ID embedded in an M-address
// takes precedence over any memo supplied with the payment.
func ExampleExtractRouting_muxed() {
	result := routing.ExtractRouting(routing.RoutingInput{
		Destination: "MAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQACABAAAAAAAAAAEVIG",
		MemoType:    "none",
	})

	fmt.Println("base account:", result.DestinationBaseAccount)
	fmt.Println("routing id:", result.RoutingID)
	fmt.Println("source:", result.RoutingSource)
	// Output:
	// base account: GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI
	// routing id: 9007199254740993
	// source: muxed
}
