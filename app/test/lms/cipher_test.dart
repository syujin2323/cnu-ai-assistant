// 요청 본문 암호화 테스트. docs/lms.md '로그인'.
//
// 기대값은 같은 키·초기 벡터·평문을 openssl `enc -aes-*-cbc`로 암호화해 얻은 값이다. 키와 평문은 모두 합성 값이다.

import 'dart:convert';
import 'dart:typed_data';

import 'package:cnu_ai_assistant/lms/cipher.dart';
import 'package:cnu_ai_assistant/lms/request_spec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const key32 = '0123456789abcdef0123456789abcdef';

  group('aesCbcEncryptBase64', () {
    test('openssl과 같은 암호문을 낸다(AES-128·192·256, PKCS#7)', () {
      for (final (key, iv, plain, expected) in [
        (
          key32,
          '\x00' * 16,
          '{"a":"가나","b":"x"}',
          'Pq0NrPFCwlLgi8At+TUM36T43b7aSYikgAYPdvbQ2Pg=',
        ),
        (
          'synthetictoken01',
          'synthetictoken01',
          'synthetic field',
          'vtVD7APZT1DtxSJS8UwK8g==',
        ),
        (
          'synthetictoken01',
          'synthetictoken01',
          '',
          'ndclmaMgCSq7U1knePdX/A==',
        ),
        (
          'abcdefghijklmnopqrstuvwx',
          '\x00' * 16,
          '0123456789abcdef',
          'eWBLXL6ES6oBl2YvoF+iZBUB/aTuw4mponoAxRvRsfE=',
        ),
      ]) {
        expect(
          aesCbcEncryptBase64(
            key: Uint8List.fromList(utf8.encode(key)),
            iv: Uint8List.fromList(utf8.encode(iv)),
            plain: utf8.encode(plain),
          ),
          expected,
          reason: '${key.length}바이트 키, "$plain"',
        );
      }
    });
  });

  group('lmsEncrypt', () {
    test('초기 벡터 zero는 0으로 채운 16바이트, key는 키의 앞 16바이트다', () {
      expect(
        lmsEncrypt(const LmsCipherSpec(keyVar: 'k'), {
          'k': key32,
        }, '{"a":"가나","b":"x"}'),
        'Pq0NrPFCwlLgi8At+TUM36T43b7aSYikgAYPdvbQ2Pg=',
      );
      expect(
        lmsEncrypt(const LmsCipherSpec(keyVar: 'k', iv: LmsIv.key), {
          'k': key32,
        }, 'x'),
        'kKf15JKJ/tKklphhwDVvnA==',
      );
    });

    test('키 글자에서 removeChars를 지우고 앞 takeBytes바이트를 쓴다', () {
      expect(
        lmsEncrypt(
          const LmsCipherSpec(
            keyVar: 'token',
            removeChars: '-',
            takeBytes: 16,
            iv: LmsIv.key,
          ),
          {'token': 'synthetic-token-01-extra'},
          'synthetic field',
        ),
        'vtVD7APZT1DtxSJS8UwK8g==',
      );
    });

    test('키 변수가 없거나 길이가 16·24·32바이트가 아니면 null이다', () {
      expect(
        lmsEncrypt(const LmsCipherSpec(keyVar: 'k'), const {}, 'x'),
        isNull,
      );
      for (final key in ['', 'short', '0123456789abcdef0', '가' * 6]) {
        expect(
          lmsEncrypt(const LmsCipherSpec(keyVar: 'k'), {'k': key}, 'x'),
          isNull,
          reason: key,
        );
      }
      expect(
        lmsEncrypt(const LmsCipherSpec(keyVar: 'k', takeBytes: 32), {
          'k': 'synthetictoken01',
        }, 'x'),
        isNull,
      );
    });
  });

  test('lmsCipherKey는 여러 글자를 지우고 UTF-8 바이트로 자른다', () {
    expect(
      lmsCipherKey(
        const LmsCipherSpec(keyVar: 'k', removeChars: '-_', takeBytes: 16),
        {'k': 'a-b_c-d_efghijklmnopqrst'},
      ),
      utf8.encode('abcdefghijklmnop'),
    );
    expect(
      lmsCipherKey(const LmsCipherSpec(keyVar: 'k'), {'k': 'x' * 24}),
      hasLength(24),
    );
  });
}
