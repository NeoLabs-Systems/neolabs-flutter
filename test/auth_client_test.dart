import 'package:flutter_test/flutter_test.dart';
import 'package:neolabs_flutter/neolabs_flutter.dart';

void main() {
  test(
    'authentication uses the host transport and keeps request semantics',
    () async {
      final calls = <(String, String, Map<String, dynamic>, bool)>[];
      Future<Map<String, dynamic>> post(
        String base,
        String path,
        Map<String, dynamic> body, {
        bool allowUnauthorized = false,
      }) async {
        calls.add((base, path, body, allowUnauthorized));
        return {'ok': true};
      }

      final auth = NeoAuthClient(post);
      await auth.login('https://server', 'alice', 'secret');
      await auth.register(
        'https://server',
        'alice',
        'a@example.test',
        'secret',
        signupKey: 'key',
      );
      await auth.forgotPassword('https://server', 'alice');
      await auth.createQrChallenge('https://server', {'device': 'phone'});
      await auth.qrChallengeAction(
        'https://server',
        'a/b',
        'token',
        QrChallengeAction.status,
        knownStatus: 'pending',
      );
      await auth.qrChallengeAction(
        'https://server',
        'a/b',
        'token',
        QrChallengeAction.claim,
      );
      expect(calls[0].$1, 'https://server');
      expect(calls[0].$2, '/api/auth/login');
      expect(calls[0].$3, {'username': 'alice', 'password': 'secret'});
      expect(calls[0].$4, false);
      expect(calls[1].$3['signupKey'], 'key');
      expect(calls[2].$4, isTrue);
      expect(calls[3].$3, {
        'requestMetadata': {'device': 'phone'},
      });
      expect(calls[4].$2, '/api/auth/qr-login/challenge/a%2Fb/status');
      expect(calls[4].$3, {'token': 'token', 'knownStatus': 'pending'});
      expect(calls[5].$3, {'token': 'token'});
    },
  );
}
