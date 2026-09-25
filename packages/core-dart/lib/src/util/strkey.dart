import 'dart:typed_data';

/// Base32 and CRC-16 primitives for Stellar StrKey encoding.
///
/// Internal: this class is not exported from `bluewhale_core.dart`.
class StrKeyUtil {
  static const String _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  /// Decodes an unpadded RFC 4648 Base32 string (case-insensitive).
  ///
  /// Throws [FormatException] when a character falls outside the Base32
  /// alphabet, or when the encoding is not canonical — i.e. when re-encoding
  /// the decoded bytes does not reproduce the input. The latter rejects
  /// non-zero bits in the final, partially-used group, which would otherwise
  /// give one payload several distinct string encodings.
  ///
  /// The alphabet error names the offending character, its code point and its
  /// index, and reports the **first** such character rather than whichever
  /// one surfaces mid-decode:
  ///
  /// ```dart
  /// try {
  ///   StrKeyUtil.decodeBase32('GAY!C…');
  /// } on FormatException catch (e) {
  ///   print(e.message); // Invalid Base32 character '!' (U+0021) at index 3; …
  ///   print(e.offset);  // 3
  /// }
  /// ```
  ///
  /// [FormatException.source] is the uppercased, unpadded input and
  /// [FormatException.offset] is the same index, so an editor or logger can
  /// point straight at the character.
  static Uint8List decodeBase32(String input) {
    final normalized = input.toUpperCase().replaceAll('=', '');
    final charCount = normalized.length;
    final byteCount = (charCount * 5) ~/ 8;
    final result = Uint8List(byteCount);

    int buffer = 0;
    int bitsLeft = 0;
    int charIndex = 0;
    int byteIndex = 0;

    while (byteIndex < byteCount) {
      if (bitsLeft < 8) {
        if (charIndex < charCount) {
          final start = charIndex;
          final (rune, width) = _codePointAt(normalized, start);
          final char = String.fromCharCode(rune);
          final value = _alphabet.indexOf(char);
          if (value == -1) {
            throw FormatException(
              _describeInvalidCharacter(char, rune, start),
              normalized,
              start,
            );
          }
          // Step over the whole code point: anything above U+FFFF occupies a
          // surrogate pair, and consuming a single code unit would report a
          // lone surrogate in the message.
          charIndex = start + width;
          buffer = (buffer << 5) | value;
          bitsLeft += 5;
        } else {
          break;
        }
      }

      if (bitsLeft >= 8) {
        result[byteIndex++] = (buffer >> (bitsLeft - 8)) & 0xFF;
        bitsLeft -= 8;
      }
    }

    // Unused bits in the final group must be zero. Re-encoding is the
    // cheapest way to assert that: a canonical payload always round-trips.
    if (encodeBase32(result) != normalized) {
      throw FormatException(
        'Invalid Base32 encoding: unused trailing bits must be zero. Only '
        'A-Z and 2-7 are valid, and the final character must not set bits '
        'beyond the decoded payload.',
        normalized,
      );
    }

    return result;
  }

  /// Returns the Unicode code point starting at [index] in [input] together
  /// with the number of UTF-16 code units it occupies.
  ///
  /// A well-formed surrogate pair is reported as a single code point (width
  /// 2); an unpaired surrogate is returned as-is (width 1) so the caller can
  /// still name it.
  static (int rune, int width) _codePointAt(String input, int index) {
    final unit = input.codeUnitAt(index);
    if (unit >= 0xD800 && unit <= 0xDBFF && index + 1 < input.length) {
      final low = input.codeUnitAt(index + 1);
      if (low >= 0xDC00 && low <= 0xDFFF) {
        return (0x10000 + ((unit - 0xD800) << 10) + (low - 0xDC00), 2);
      }
    }
    return (unit, 1);
  }

  /// Builds the `FormatException` message for a character outside
  /// [_alphabet], naming the character, its code point and its [index] within
  /// the normalized input.
  static String _describeInvalidCharacter(String char, int rune, int index) {
    final codePoint = rune.toRadixString(16).toUpperCase().padLeft(4, '0');
    return "Invalid Base32 character '$char' (U+$codePoint) at index $index; "
        'expected a letter A-Z or a digit 2-7';
  }

  /// Encodes [data] as unpadded, uppercase RFC 4648 Base32.
  static String encodeBase32(Uint8List data) {
    final result = StringBuffer();

    int buffer = 0;
    int bitsLeft = 0;
    
    for (var byte in data) {
      buffer = (buffer << 8) | byte;
      bitsLeft += 8;
      while (bitsLeft >= 5) {
        result.write(_alphabet[(buffer >> (bitsLeft - 5)) & 0x1F]);
        bitsLeft -= 5;
      }
    }

    if (bitsLeft > 0) {
      result.write(_alphabet[(buffer << (5 - bitsLeft)) & 0x1F]);
    }

    return result.toString();
  }

  /// Computes the CRC-16/XMODEM checksum of [bytes].
  ///
  /// StrKey stores the result little-endian after the payload.
  static int calculateChecksum(Uint8List bytes) {
    int crc = 0x0000;
    for (int byte in bytes) {
      crc ^= (byte << 8);
      for (int i = 0; i < 8; i++) {
        if ((crc & 0x8000) != 0) {
          crc = (crc << 1) ^ 0x1021;
        } else {
          crc = (crc << 1);
        }
      }
    }
    // Return little-endian CRC bytes
    return crc & 0xFFFF;
  }
}
