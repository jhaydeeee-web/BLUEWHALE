// Cross-language warning-code parity (issue #76).
//
// `spec/schema.json` splits warning codes across four `oneOf` branches:
//
//   - `warningNormalization`      -> NON_CANONICAL_{ADDRESS,ROUTING_ID}
//   - `warningInvalidDestination` -> INVALID_DESTINATION
//   - `warningUnsupportedMemoType`-> UNSUPPORTED_MEMO_TYPE
//   - `warningGeneric`            -> the context-free remainder
//
// Unioning the `code` enums from every branch yields the normative set. This
// test reads the schema rather than hard-coding the list, so adding a code to
// the spec without adding it to an SDK fails CI instead of silently diverging.
import 'dart:convert';
import 'dart:io';

import 'package:bluewhale_core/bluewhale_core.dart';
import 'package:test/test.dart';

const _schemaPath = '../../spec/schema.json';

/// Every warning code declared anywhere in the schema's `oneOf` branches.
List<String> _specDeclaredCodes() {
  final file = File(_schemaPath);
  if (!file.existsSync()) {
    fail('Expected $_schemaPath but file was not found.');
  }

  final Map<String, dynamic> schema =
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final Map<String, dynamic> definitions =
      schema['definitions'] as Map<String, dynamic>;

  final codes = <String>[];
  for (final definition in definitions.values) {
    final code = ((definition as Map<String, dynamic>)['properties']
            as Map<String, dynamic>?)?['code'] as Map<String, dynamic>?;
    if (code == null) continue;
    if (code['const'] != null) {
      codes.add(code['const'] as String);
    } else if (code['enum'] is List) {
      codes.addAll((code['enum'] as List).cast<String>());
    }
  }
  return codes;
}

/// [SPEC_DECLARED_CODES] minus the codes no SDK emits as a `Warning`.
List<String> _specWarningCodes() {
  // `INVALID_STRKEY` is a `detect`-module sentinel in `spec/vectors.json`,
  // not a routing warning: no SDK emits it, and the normative list in
  // issue #76 omits it.
  return _specDeclaredCodes().where((c) => c != 'INVALID_STRKEY').toList();
}

const _g = 'GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI';
const _m = 'MAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQACAAAAAAAAAAAAD672';
const _c = 'CDLZFC3SYJYDZT7K67VZ75HPJVIEUVNIXF47ZG2FB2RMQQVU2HHGCYSC';

void main() {
  group('Warning code parity with spec/schema.json (#76)', () {
    late List<String> specCodes;
    late List<String> declared;

    setUpAll(() {
      specCodes = _specWarningCodes()..sort();
      declared = WarningCode.values.toList()..sort();
    });

    test('derives a non-empty code set from the schema', () {
      expect(specCodes, isNotEmpty);
    });

    test('declares exactly the schema warning codes', () {
      expect(declared, specCodes);
    });

    test('has no duplicates in WarningCode.values', () {
      expect(WarningCode.values.toSet().length, WarningCode.values.length);
    });

    test('isKnown and tryParse agree with values', () {
      for (final code in WarningCode.values) {
        expect(WarningCode.isKnown(code), isTrue, reason: code);
        expect(WarningCode.tryParse(code), code);
      }
      expect(WarningCode.isKnown('NOT_A_CODE'), isFalse);
      expect(WarningCode.tryParse('NOT_A_CODE'), isNull);
    });

    test('only emits codes that the schema declares', () {
      final specAll = _specDeclaredCodes().toSet();
      final unknown = <String>[];

      final inputs = <RoutingInput>[
        RoutingInput(destination: _g, memoType: 'none'),
        RoutingInput(destination: _g, memoType: 'id', memoValue: '007'),
        RoutingInput(destination: _g, memoType: 'text', memoValue: 'not-a-number'),
        RoutingInput(destination: _g, memoType: 'hash'),
        RoutingInput(destination: _g, memoType: 'return'),
        RoutingInput(destination: _g, memoType: 'signed'),
        RoutingInput(destination: _g, memoType: 'text', memoValue: '7', sourceAccount: _c),
        RoutingInput(destination: _c, memoType: 'none'),
        RoutingInput(destination: _m, memoType: 'none'),
        RoutingInput(destination: _m, memoType: 'id', memoValue: '7'),
        RoutingInput(destination: _m, memoType: 'hash'),
        RoutingInput(destination: _g.toLowerCase(), memoType: 'none'),
      ];

      for (final input in inputs) {
        for (final warning in extractRoutingSync(input).warnings) {
          if (!specAll.contains(warning.code)) {
            unknown.add('${warning.code} (from ${input.memoType})');
          }
        }
        for (final warning in parse(input.destination).warnings) {
          if (!specAll.contains(warning.code)) {
            unknown.add('${warning.code} (from parse ${input.destination})');
          }
        }
      }

      expect(unknown, isEmpty);
    });
  });

  group('Warning code wire shape', () {
    test('UNSUPPORTED_MEMO_TYPE carries context.memoType', () {
      for (final memoType in ['hash', 'return']) {
        final result = extractRoutingSync(
          RoutingInput(destination: _g, memoType: memoType),
        );
        expect(result.warnings, hasLength(1));
        expect(result.warnings.single.code, WarningCode.unsupportedMemoType);
        expect(result.warnings.single.context,
            WarningContext(memoType: memoType));
      }
    });

    test('an unrecognized memo type reports context.memoType "unknown"', () {
      final result = extractRoutingSync(
        RoutingInput(destination: _g, memoType: 'signed'),
      );
      expect(result.warnings.single.code, WarningCode.unsupportedMemoType);
      expect(result.warnings.single.context,
          const WarningContext(memoType: 'unknown'));
    });

    test('INVALID_DESTINATION carries context.destinationKind "C"', () {
      final result =
          extractRoutingSync(RoutingInput(destination: _c, memoType: 'none'));
      expect(result.warnings.single.code, WarningCode.invalidDestination);
      expect(result.warnings.single.context,
          const WarningContext(destinationKind: 'C'));
    });

    test('MEMO_TEXT_UNROUTABLE is reserved for a non-numeric MEMO_TEXT', () {
      final unroutable = extractRoutingSync(
        RoutingInput(
            destination: _g, memoType: 'text', memoValue: 'not-a-number'),
      );
      expect(unroutable.warnings.single.code, WarningCode.memoTextUnroutable);

      for (final memoType in ['hash', 'return', 'signed']) {
        final result =
            extractRoutingSync(RoutingInput(destination: _g, memoType: memoType));
        expect(
          result.warnings.map((w) => w.code),
          isNot(contains(WarningCode.memoTextUnroutable)),
          reason: 'memoType $memoType must not report MEMO_TEXT_UNROUTABLE',
        );
      }
    });

    test('serialized warnings include context only when the code needs it', () {
      final unsupported = extractRoutingSync(
        RoutingInput(destination: _g, memoType: 'hash'),
      ).warnings.single.toJson();
      expect(unsupported, {
        'code': WarningCode.unsupportedMemoType,
        'severity': WarningSeverity.warn,
        'message': 'Memo type hash is not supported for routing.',
        'context': {'memoType': 'hash'},
      });

      final generic = extractRoutingSync(
        RoutingInput(destination: _c, memoType: 'none'),
      ).warnings.single.toJson();
      // INVALID_DESTINATION does require a context.
      expect(generic['context'], {'destinationKind': 'C'});

      final unroutable = extractRoutingSync(
        RoutingInput(destination: _g, memoType: 'text', memoValue: 'nope'),
      ).warnings.single.toJson();
      expect(unroutable.containsKey('context'), isFalse);
    });

    test('RoutingResult.toJson round-trips warning context', () {
      final original = extractRoutingSync(
        RoutingInput(destination: _g, memoType: 'return'),
      );
      final restored = RoutingResult.fromJson(original.toJson());

      expect(restored.warnings, original.warnings);
      expect(restored.warnings.single.context,
          const WarningContext(memoType: 'return'));
    });
  });
}
