import 'package:bluewhale_core/bluewhale_core.dart';

void main() async {
  // 1. Detect and Validate address types
  const gAddress = 'GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI';
  
  if (validate(gAddress)) {
    final kind = detect(gAddress);
    print('Address kind: $kind'); // AddressKind.g
  }

  // 2. High-level Parsing
  final parsed = StellarAddress.parse(gAddress);
  print('Parsed kind: ${parsed.kind}'); // AddressKind.g

  // 3. Encode a Muxed address
  final mAddress = MuxedAddress.encode(baseG: gAddress, id: BigInt.from(12345));
  print('Muxed Address: $mAddress');

  // 4. Decode a Muxed address
  final decoded = MuxedAddress.decode(mAddress);
  print('Decoded ID: ${decoded.id}'); // 12345

  // 5. Extract routing information from an incoming payment (synchronous).
  // This is used to reconcile deposits in a pooled account.
  final result = extractRouting(RoutingInput(
    destination: mAddress,
    memoType: 'none',
    memoValue: null,
  ));

  print('Routing ID: ${result.id}'); // 12345
  print('Routing Source: ${result.source}'); // RoutingSource.muxed

  // 6. Async variant with an optional SEP-0029 memo-requirement check.
  final asyncResult = await extractRoutingAsync(
    RoutingInput(
      destination: gAddress,
      memoType: 'none',
      memoValue: null,
    ),
    fetchMemoRequirement: (baseAccount) async => false,
  );

  print('Async Routing Source: ${asyncResult.source}'); // RoutingSource.none
}
