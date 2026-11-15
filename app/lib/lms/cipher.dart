// 요청 본문 암호화. docs/lms.md '로그인'.
//
// 어떤 요청을 어떤 키로 암호화하는지는 요청 상수(`lms_request_params`의 `ciphers`)에만 있다. 이 파일은 AES-CBC(PKCS#7
// 채움, 결과는 base64)와 요청 상수의 키 규칙([LmsCipherSpec])만 둔다. 키와 평문은 로그에 남기지 않는다.

import 'dart:convert';
import 'dart:typed_data';

import 'package:cnu_ai_assistant/lms/request_spec.dart';
import 'package:pointycastle/export.dart';

/// [spec]의 키 규칙으로 변수 [vars]에서 만든 키. 키 변수가 없거나 길이가 16·24·32바이트가 아니면 null이다.
Uint8List? lmsCipherKey(LmsCipherSpec spec, Map<String, String> vars) {
  var text = vars[spec.keyVar];
  if (text == null) return null;
  for (final char in spec.removeChars.split('')) {
    text = text!.replaceAll(char, '');
  }
  var bytes = utf8.encode(text!);
  final take = spec.takeBytes;
  if (take != null) {
    if (bytes.length < take) return null;
    bytes = bytes.sublist(0, take);
  }
  return const {16, 24, 32}.contains(bytes.length) ? bytes : null;
}

/// [spec]으로 [plain]을 암호화한 base64. 키를 만들지 못하면 null이다.
String? lmsEncrypt(LmsCipherSpec spec, Map<String, String> vars, String plain) {
  final key = lmsCipherKey(spec, vars);
  if (key == null) return null;
  final iv = switch (spec.iv) {
    LmsIv.zero => Uint8List(16),
    LmsIv.key => Uint8List.sublistView(key, 0, 16),
  };
  return aesCbcEncryptBase64(key: key, iv: iv, plain: utf8.encode(plain));
}

/// AES-CBC(PKCS#7 채움)로 [plain]을 암호화한 base64. [key]는 16·24·32바이트, [iv]는 16바이트다. 빈 평문은 채움
/// 블록 하나가 된다(pointycastle의 채움 래퍼는 빈 입력을 받지 못해 채움은 여기서 한다).
String aesCbcEncryptBase64({
  required Uint8List key,
  required Uint8List iv,
  required List<int> plain,
}) {
  const block = 16;
  final padding = block - plain.length % block;
  final padded = Uint8List(plain.length + padding)
    ..setAll(0, plain)
    ..fillRange(plain.length, plain.length + padding, padding);
  final cbc = CBCBlockCipher(AESEngine())
    ..init(true, ParametersWithIV(KeyParameter(key), iv));
  final out = Uint8List(padded.length);
  for (var offset = 0; offset < padded.length; offset += block) {
    cbc.processBlock(padded, offset, out, offset);
  }
  return base64.encode(out);
}
