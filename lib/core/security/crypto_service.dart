import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';


class CryptoService {
  final _algorithm = AesGcm.with256bits();
  final _random = Random.secure();

  // Generate a random encryption key
  Future<String> generateKey() async {
    final key = await _algorithm.newSecretKey();
    final keyBytes = await key.extractBytes();
    return base64Url.encode(keyBytes);
  }

  // Generate key pair for asymmetric encryption (E2E chat)
  Future<Map<String, String>> generateKeyPair() async {
    final algorithm = X25519();
    final keyPair = await algorithm.newKeyPair();
    
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();
    final publicKey = await keyPair.extractPublicKey();
    final publicKeyBytes = publicKey.bytes;

    return {
      'privateKey': base64Url.encode(privateKeyBytes),
      'publicKey': base64Url.encode(publicKeyBytes),
    };
  }

  // Encrypt text with AES-GCM
  Future<String> encrypt(String plainText, String keyString) async {
    try {
      final keyBytes = base64Url.decode(keyString);
      final secretKey = SecretKey(keyBytes);
      
      final nonce = _algorithm.newNonce();
      
      final secretBox = await _algorithm.encrypt(
        utf8.encode(plainText),
        secretKey: secretKey,
        nonce: nonce,
      );

      final combined = Uint8List.fromList([
        ...nonce,
        ...secretBox.cipherText,
        ...secretBox.mac.bytes,
      ]);

      return base64Url.encode(combined);
    } catch (e) {
      throw Exception('Encryption failed: $e');
    }
  }

  // Decrypt text with AES-GCM
  Future<String> decrypt(String encryptedText, String keyString) async {
    try {
      final keyBytes = base64Url.decode(keyString);
      final secretKey = SecretKey(keyBytes);
      
      final combined = base64Url.decode(encryptedText);
      
      // Extract components (nonce: 12 bytes, mac: 16 bytes, rest: ciphertext)
      final nonce = combined.sublist(0, 12);
      final mac = combined.sublist(combined.length - 16);
      final cipherText = combined.sublist(12, combined.length - 16);

      final secretBox = SecretBox(
        cipherText,
        nonce: nonce,
        mac: Mac(mac),
      );

      final decrypted = await _algorithm.decrypt(
        secretBox,
        secretKey: secretKey,
      );

      return utf8.decode(decrypted);
    } catch (e) {
      throw Exception('Decryption failed: $e');
    }
  }

  // Generate shared secret from key pair (for E2E encryption)
  Future<String> generateSharedSecret(
    String privateKeyString,
    String peerPublicKeyString,
  ) async {
    try {
      final algorithm = X25519();
      
      final privateKeyBytes = base64Url.decode(privateKeyString);
      final peerPublicKeyBytes = base64Url.decode(peerPublicKeyString);
      
      final keyPair = await algorithm.newKeyPairFromSeed(privateKeyBytes);
      final peerPublicKey = SimplePublicKey(
        peerPublicKeyBytes,
        type: KeyPairType.x25519,
      );

      final sharedSecret = await algorithm.sharedSecretKey(
        keyPair: keyPair,
        remotePublicKey: peerPublicKey,
      );

      final sharedSecretBytes = await sharedSecret.extractBytes();
      return base64Url.encode(sharedSecretBytes);
    } catch (e) {
      throw Exception('Shared secret generation failed: $e');
    }
  }

  // Hash password with PBKDF2
  Future<String> hashPassword(String password, String salt) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 100000,
      bits: 256,
    );

    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: utf8.encode(salt),
    );

    final bytes = await secretKey.extractBytes();
    return base64Url.encode(bytes);
  }

  // Generate random salt
  String generateSalt() {
    final saltBytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return base64Url.encode(saltBytes);
  }

  // Generate random PIN
  String generatePin({int length = 6}) {
    return List.generate(length, (_) => _random.nextInt(10)).join();
  }

  // Obfuscate string (simple XOR - for non-critical data)
  String obfuscate(String input, String key) {
    final inputBytes = utf8.encode(input);
    final keyBytes = utf8.encode(key);
    final result = List<int>.generate(
      inputBytes.length,
      (i) => inputBytes[i] ^ keyBytes[i % keyBytes.length],
    );
    return base64Url.encode(result);
  }

  // Deobfuscate string
  String deobfuscate(String input, String key) {
    final inputBytes = base64Url.decode(input);
    final keyBytes = utf8.encode(key);
    final result = List<int>.generate(
      inputBytes.length,
      (i) => inputBytes[i] ^ keyBytes[i % keyBytes.length],
    );
    return utf8.decode(result);
  }
}
