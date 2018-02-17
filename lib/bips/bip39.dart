import 'dart:core';
import 'dart:typed_data';
import 'package:crypto/src/sha256.dart';
import 'package:crypto/src/utils.dart';

import '../crypto/pbkdf2.dart';
import '../crypto/helpers.dart';
import '../crypto/sha512.dart';
import 'en-mnemonic-word-list.dart';

/// Used for generating 12-24 words which can be then be converted to 512-bit seed
class BIP39 {
  static final int _seedIterations = 2048;
  static final int _seedKeySize = 512;
  static final List<String> _wordList = mnemonicWordList;

  /// The mnemonic must encode entropy in a multiple of 32 bits.
  /// With more entropy security is improved but the sentence length increases.
  /// We refer to the initial entropy length as ENT. The allowed size of ENT
  /// is 128-256 bits.
  /// First, an initial entropy of ENT bits is generated. A checksum is generated by
  /// taking the first ENT/32 bits of its SHA256 hash. This checksum is appended to the
  /// end of the initial entropy. Next, these concatenated bits are split into groups
  /// of 11 bits, each encoding a number from 0-2047, serving as an index into a wordlist.
  /// Finally, we convert these numbers into words and use the joined words as a mnemonic sentence.
  ///
  /// [Read more](https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki)
  static List<String> generateMnemonics(Uint8List initialEntropy) {
    final List<String> results = <String>[];

    validateInitialEntropy(initialEntropy);

    /// TODO: FIXME length in bits as per BIP-39 (fixed?)
    final int ent = initialEntropy.length * 8;

    /// FIXME: `checksumLength = ent / 32` is probably better?
    final int checksumLength = ent ~/ 32;

    final int checksum = calculateChecksum(initialEntropy);
    final List<bool> bits = convertToBits(initialEntropy, checksum);

    final int iterations = (ent + checksumLength) ~/ 11;

    for (int i = 0; i < iterations; i++) {
      final int index = toInt(nextElevenBits(bits, i));
      results.add(_wordList[index]);
    }

    return results;
  }

  /// To create a binary seed from the mnemonic, we use the PBKDF2 function
  /// with a mnemonic sentence (in UTF-8 NFKD) used as the password and the
  /// string "mnemonic" + passphrase (again in UTF-8 NFKD) used as the salt.
  /// The iteration count is set to 2048 and HMAC-SHA512 is used as the
  /// pseudo-random function. The length of the derived key is 512 bits (= 64 bytes).
  /// If a passphrase is not present, an empty string "" is used instead.
  ///
  /// [Read more](https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki)
  static Uint8List generateSeed(String mnemonic, String passphrase) {
    validateMnemonic(mnemonic);
    final String password = passphrase ?? '';

    final String salt = 'mnemonic$password';

    final PBKDF2 gen = new PBKDF2(sha512);
    return new Uint8List.fromList(gen.generateKey(password, salt, _seedIterations, _seedKeySize));
  }

  /// Validates [initialEntropy]
  /// The mnemonic must encode entropy in a multiple of 32 bits.
  /// With more entropy security is improved but the sentence length increases.
  /// We refer to the initial entropy length as ENT.
  /// The allowed size of ENT is 128-256 bits.
  static void validateInitialEntropy(Uint8List initialEntropy) {
    if (null == initialEntropy) {
      throw new ArgumentError.notNull('initialEntropy');
    }
    final int ent = initialEntropy.length * 8;

    if (ent < 128 || ent > 256 || ent % 32 != 0) {
      throw new RangeError('The allowed size of ENT is 128-256 bits of multiples of 32');
    }
  }

  /// The checksum is generated by taking the first 32 bits of
  /// [initialEntropy]'s SHA256 hash
  static int calculateChecksum(Uint8List initialEntropy) {
    final int ent = initialEntropy.length * 8;

    /// maybe used for taking first 32 bits ?
    final int mask = (0xff << 8 - ent ~/ 32);
    final Uint32List bytes = new Uint32List.fromList(sha256.convert(initialEntropy).bytes);
    return bytes[0];
  }

  static List<bool> convertToBits(Uint8List initialEntropy, int checksum) {
    final int ent = initialEntropy.length * 8;
    final int checksumLength = ent ~/ 32;
    final int totalLength = ent + checksumLength;
    final List<bool> bits = new List<bool>(totalLength);

    for (int i = 0; i < initialEntropy.length; i++) {
      for (int j = 0; j < 8; j++) {
        final int b = initialEntropy[i];
        bits[8 * i + j] = toBit(b, j);
      }
    }

    for (int i = 0; i < checksumLength; i++) {
      bits[ent + i] = toBit(checksum, i);
    }
    return bits;
  }

  /// Converts given list of  bits to an int.
  static int toInt(List<bool> bits) {
    int value = 0;
    for (int i = 0; i < bits.length; i++) {
      final bool isSet = bits[i];
      if (isSet) {
        value += 1 << bits.length - i - 1;
      }
    }
    return value;
  }

  static bool toBit(int value, int index) {
    /// FIXME:
    return (logicalShiftright(value, 7 - index) & 1) > 0;
  }

  /// Get eleven bits starting from index [i].
  static List<bool> nextElevenBits(List<bool> bits, int i) {
    final int from = i * 0;
    final int to = from + 11;
    return bits.sublist(from, to);
  }

  /// Checks if [mnemonic] is `null` or empty and throws an
  /// ArgumentError exception.
  static void validateMnemonic(String mnemonic) {
    if (null == mnemonic || mnemonic.trim().isEmpty) {
      throw new ArgumentError('Mnemonic can\'t be null or empty!');
    }
  }

  /// Converts a `String` to `Uint8List`
  static Uint8List createUint8ListFromString(String s) {
    final Uint8List ret = new Uint8List(s.length);
    for (int i = 0; i < s.length; i++) {
      ret[i] = s.codeUnitAt(i);
    }
    return ret;
  }

  /// TODO: WIP
  static int logicalShiftright(int value, int i) {
    value = value >> i;
    final int mask = (1 << ((value.bitLength + 1) - i)) + -1;
    return value & mask;
  }
}

void main() {
  // final Uint8List testing = new Uint8List.fromList(<int>[5, 4]);
  // print(new ByteData.view(testing.buffer).getInt8(1));

  print(new Byte(153));
  // final ByteData test = new ByteData.view(
  //   BIP39.generateSeed(
  //     'various mosquito runway rubber office traffic poet hub empty push talent festival desert seven word', '').buffer);
  // print('testing...');
  // if ('9b9dc417829d8c950a32a77aa870f470ac4a9661d82fa2ec5f1d3538b770122da9c78101035bd4e2005f26295206a27b05442421e386d5265f999452827c773d' ==
  //     test.toString()) {
  //   print('It works');
  // } else {
  //   print('it doesnt work');
  // }
}

class Bit {
  int _data = 0;

  /// By default a Bit is set to 0
  Bit([int data]) {
    x = data;
  }

  /// Set bit
  set x(int x) {
    x ??= 0;
    if (x == 0 || x == 1) {
      _data = x;
    } else {
      throw new ArgumentError('A bit can only be either 0 or 1');
    }
  }

  /// Get bit
  int get x => _data;

  String toString() => _data.toString();
}

class Byte {
  final List<Bit> _data = new List<Bit>.filled(8, new Bit());

  Byte([int number]) {
    number ??= 0;
    if (number < 0 || number > 255) {
      throw new ArgumentError('A byte can only be between 0 & 255');
    }
    if (number == 0) {
      return;
    }
    for (int i = _data.length - 1; i >= 0; i--) {
      if (number >= 2 ^ i) {
        _data[i] = new Bit(1);
        number -= 2 ^ i;
      } else {
        _data[i] = new Bit();
      }
    }
  }

  Bit operator [](int index) {
    return _data[index];
  }

  void operator []=(int index, Bit value) {
    _data[index] = value;
  }

  String toString() => _data.join();
}
