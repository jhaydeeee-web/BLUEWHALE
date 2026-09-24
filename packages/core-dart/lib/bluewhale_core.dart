/// Stellar address parsing, muxed-account encoding and deposit routing.
///
/// Routing entry points (exported from `src/routing/extract.dart`):
/// - [extractRouting]: primary, synchronous routing extraction.
/// - [extractRoutingAsync]: async variant supporting network checks such as
///   SEP-0029 memo requirements.
/// - `extractRoutingSync`: deprecated alias of [extractRouting].
library bluewhale_core;

export 'src/address/stellar_address.dart';
export 'src/address/detect.dart';
export 'src/address/validate.dart';
export 'src/address/parse.dart';
export 'src/address/codes.dart';
export 'src/muxed/encode.dart';
export 'src/muxed/decode.dart';
export 'src/muxed/decoded_muxed_address.dart';
export 'src/routing/extract.dart';
export 'src/routing/routing_result.dart';
export 'src/routing/memo.dart';
export 'src/routing/safe_routing_id.dart';
export 'src/util/web_platform.dart';
export 'src/muxed/muxed_address.dart';
export 'src/exceptions.dart';
