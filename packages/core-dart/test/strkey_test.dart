// Illegal-Base32 diagnostics for `StrKeyUtil.decodeBase32` (#72).
//
// The decoder runs underneath `detect`, `MuxedDecoder` and `StellarAddress`,
// all of which collapse failures into a generic error. This suite pins the
// detail a developer actually needs when a payload is rejected: which
// character was wrong, and where in the string it sat.
import 'dart:typed_data';

import 'package:bluewhale_core/src/util/strkey.dart';
import 'package:test/test.dart';

/// Runs [body] and returns the [FormatException] it throws.
FormatException captureFormatException(void Function() body) {
  try {
    body();
  } on FormatException catch (e) {
    return e;
  }
  fail('expected a FormatException, but none was thrown');
}

void main() {
  const validG = 'GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI';

  group('decodeBase32 — valid input', () {
    test('decodes a canonical 56-character G-address to 35 bytes', () {
      final decoded = StrKeyUtil.decodeBase32(validG);
      expect(decoded, hasLength(35));
      expect(decoded[0], 0x30, reason: 'G version byte');
    });

    test('is case-insensitive and tolerates padding', () {
      expect(
        StrKeyUtil.decodeBase32(validG.toLowerCase()),
        StrKeyUtil.decodeBase32(validG),
      );
      expect(
        StrKeyUtil.decodeBase32('$validG===='),
        StrKeyUtil.decodeBase32(validG),
      );
    });

    test('round-trips through encodeBase32', () {
      final bytes = Uint8List.fromList(
        List<int>.generate(43, (i) => (i * 7) & 0xFF),
      );
      expect(
        StrKeyUtil.decodeBase32(StrKeyUtil.encodeBase32(bytes)),
        bytes,
      );
    });
  });

  group('decodeBase32 — illegal character diagnostics (#72)', () {
    test('names the offending character and its index', () {
      const input = 'GAY!UYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI';
      final error = captureFormatException(() => StrKeyUtil.decodeBase32(input));

      expect(error.message, contains("'!'"));
      expect(error.message, contains('U+0021'));
      expect(error.message, contains('index 3'));
      expect(error.message, contains('expected a letter A-Z or a digit 2-7'));
    });

    test('exposes the same index via FormatException.offset', () {
      const input = 'GAY!UYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI';
      final error = captureFormatException(() => StrKeyUtil.decodeBase32(input));

      expect(error.offset, 3);
      expect(error.source, input);
      // The index must address the character the message names.
      expect(input.substring(error.offset!, error.offset! + 1), '!');
    });

    test('reports the digit 0 as illegal, since Base32 stops at 7', () {
      // The spec vector "non-base32 digit '0' injected into address must be
      // rejected" depends on this: 0 and 1 look numeric but are not in the
      // alphabet.
      const input = 'GA0CUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI';
      final error = captureFormatException(() => StrKeyUtil.decodeBase32(input));

      expect(error.message, contains("'0'"));
      expect(error.message, contains('index 2'));
      expect(error.offset, 2);
    });

    test('reports punctuation', () {
      const input = 'GA!CUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI';
      final error = captureFormatException(() => StrKeyUtil.decodeBase32(input));

      expect(error.message, contains("'!'"));
      expect(error.offset, 2);
    });

    test('reports the FIRST illegal character when several are present', () {
      const input = 'G@YC#YT';
      final error = captureFormatException(() => StrKeyUtil.decodeBase32(input));

      expect(error.message, contains("'@'"));
      expect(error.message, contains('index 1'));
      expect(error.message, isNot(contains("'#'")));
    });

    test('reports a non-ASCII character by code point, not a lone surrogate', () {
      // U+1F600 is a surrogate pair in a Dart String. Reporting one half of
      // it would print an unpaired surrogate into the log.
      const input = 'G😀UYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI';
      final error = captureFormatException(() => StrKeyUtil.decodeBase32(input));

      expect(error.message, contains('U+1F600'));
      expect(error.message, contains('index 1'));
      expect(error.offset, 1);
      // The source string is intact, so the two code units still line up.
      expect(error.source, input);
    });

    test('reports an embedded null byte with its index', () {
      const input = 'GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRS\u0000';
      final error = captureFormatException(() => StrKeyUtil.decodeBase32(input));

      expect(error.message, contains('U+0000'));
      expect(error.message, contains('index ${input.length - 1}'));
      expect(error.offset, input.length - 1);
    });

    test('index is reported against the uppercased, unpadded input', () {
      // Lowercase input is normalized before validation, so the offset lines
      // up with `error.source` — not with the caller's original casing.
      final error = captureFormatException(
        () => StrKeyUtil.decodeBase32('gay!uyt553c5lhve2xpw5gmejt4bxgm7ahmjwlapzp53kjo7eiqadrsi'),
      );

      expect(error.source, 'GAY!UYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI');
      expect(error.offset, 3);
      expect(error.message, contains('index 3'));
    });
  });

  group('decodeBase32 — non-canonical encodings', () {
    test('rejects non-zero unused bits in the final group', () {
      // MAYC…D672 is valid; the last character '3' sets bits the payload does
      // not use, so '2' is its only canonical spelling.
      const tampered =
          'MAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQACAAAAAAAAAAAAD673';
      final error = captureFormatException(() => StrKeyUtil.decodeBase32(tampered));

      expect(error.message, contains('unused trailing bits must be zero'));
      expect(error.source, tampered);
    });

    test('does not report a character error for a trailing-bit failure', () {
      const tampered =
          'MAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQACAAAAAAAAAAAAD673';
      final error = captureFormatException(() => StrKeyUtil.decodeBase32(tampered));

      expect(error.message, isNot(contains('Invalid Base32 character')));
    });
  });

  group('decodeBase32 — diagnostics on a malformed M-address', () {
    test('surfaces the character and index for a bad M-address', () {
      const bad =
          'MAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQACAAAAAAAAAAAAD67!';

      expect(
        () => StrKeyUtil.decodeBase32(bad),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          allOf(contains("'!'"), contains('index ${bad.length - 1}')),
        )),
      );
    });
  });
}
