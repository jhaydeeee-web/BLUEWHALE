import 'package:bluewhale_core/bluewhale_core.dart';

void main() {
  const g = 'GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI';

  print('isWebJsRuntime  : $isWebJsRuntime');

  // The hazard: plain int parsing under JS Number semantics.
  print('int.parse(2^53+1)      : ${int.parse('9007199254740993')}');

  // The fix: string-exact routing extraction.
  final r = extractRouting(RoutingInput(
    destination: g,
    memoType: 'id',
    memoValue: '9007199254740993',
  ));
  print('result.idString        : ${r.idString}');
  print('result.id (BigInt)     : ${r.id}');
  print('safeId.exceedsJsSafe   : ${r.safeId!.exceedsJsSafeRange}');

  // uint64 ceiling.
  final max = extractRouting(RoutingInput(
    destination: g,
    memoType: 'id',
    memoValue: '18446744073709551615',
  ));
  print('uint64 max idString    : ${max.idString}');

  // Muxed vector with the 2^53+1 canary.
  final m = extractRouting(RoutingInput(
    destination:
        'MAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQACABAAAAAAAAAAEVIG',
    memoType: 'none',
  ));
  print('muxed canary idString  : ${m.idString}');

  // fromInt refuses JS-unsafe values.
  try {
    SafeRoutingId.fromInt(9007199254740992);
    print('fromInt(2^53)          : ACCEPTED (native build)');
  } on ArgumentError catch (e) {
    print('fromInt(2^53)          : REFUSED (${e.message})');
  }
}
