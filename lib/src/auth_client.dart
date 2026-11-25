/// A transport supplied by the application, preserving its session and error handling.
typedef NeoAuthPost =
    Future<Map<String, dynamic>> Function(
      String baseUrl,
      String path,
      Map<String, dynamic> body, {
      bool allowUnauthorized,
    });

/// Shared NeoLabs authentication endpoints. The host owns the HTTP transport.
class NeoAuthClient {
  const NeoAuthClient(this.post);
  final NeoAuthPost post;

  Future<Map<String, dynamic>> login(
    String baseUrl,
    String username,
    String password,
  ) => post(baseUrl, '/api/auth/login', {
    'username': username,
    'password': password,
  });
  Future<Map<String, dynamic>> register(
    String baseUrl,
    String username,
    String email,
    String password, {
    String? signupKey,
  }) => post(baseUrl, '/api/auth/register', {
    'username': username,
    'email': email,
    'password': password,
    if (signupKey != null) 'signupKey': signupKey,
  });
  Future<Map<String, dynamic>> forgotPassword(String baseUrl, String account) =>
      post(baseUrl, '/api/auth/password/forgot', {
        'account': account,
      }, allowUnauthorized: true);
  Future<Map<String, dynamic>> createQrChallenge(
    String baseUrl,
    Map<String, dynamic> metadata,
  ) => post(baseUrl, '/api/auth/qr-login/challenge', {
    'requestMetadata': metadata,
  }, allowUnauthorized: true);
  Future<Map<String, dynamic>> qrChallengeAction(
    String baseUrl,
    String challengeId,
    String token,
    QrChallengeAction action, {
    String? knownStatus,
  }) => post(
    baseUrl,
    '/api/auth/qr-login/challenge/${Uri.encodeComponent(challengeId)}/${action.name}',
    {'token': token, if (knownStatus != null) 'knownStatus': knownStatus},
    allowUnauthorized: true,
  );
  Future<Map<String, dynamic>> resolveQr(
    String baseUrl,
    String challengeId,
    String secret,
    Map<String, dynamic> scannerMetadata,
  ) => post(baseUrl, '/api/account/qr-login/resolve', {
    'challengeId': challengeId,
    'secret': secret,
    'scannerMetadata': scannerMetadata,
  });

  Future<Map<String, dynamic>> declineQr(
    String baseUrl,
    String challengeId,
    String secret,
  ) => post(baseUrl, '/api/account/qr-login/decline', {
    'challengeId': challengeId,
    'secret': secret,
  });

  Future<Map<String, dynamic>> approveQr(
    String baseUrl,
    String challengeId,
    String secret,
    Map<String, dynamic> approvalMetadata,
  ) => post(baseUrl, '/api/account/qr-login/approve', {
    'challengeId': challengeId,
    'secret': secret,
    'approvalMetadata': approvalMetadata,
  });

  Future<Map<String, dynamic>> startPairing(String baseUrl) =>
      post(baseUrl, '/api/account/pairing', <String, dynamic>{});

  Future<Map<String, dynamic>> redeemPairing(
    String baseUrl,
    String code,
    String deviceName,
  ) => post(baseUrl, '/api/auth/pair', {
    'code': code,
    'name': deviceName,
  }, allowUnauthorized: true);
}

enum QrChallengeAction { status, cancel, claim }
