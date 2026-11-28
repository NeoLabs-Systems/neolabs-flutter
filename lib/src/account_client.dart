import 'dart:typed_data';

/// A file the server answered with, such as an account export.
class NeoDownload {
  const NeoDownload({
    required this.bytes,
    required this.filename,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String filename;
  final String mimeType;

  /// The file name a Content-Disposition header gives, or [fallback].
  static String filenameFrom(String? contentDisposition, String fallback) {
    final match = RegExp(
      r'filename="?([^";]+)"?',
    ).firstMatch(contentDisposition ?? '');
    final name = match?.group(1)?.trim() ?? '';
    final safe = name.split(RegExp(r'[\\/]')).last;
    return safe.isEmpty || safe == '.' || safe == '..' ? fallback : safe;
  }
}

/// The app's HTTP transport for account routes. It keeps the app's session
/// handling and throws the app's own exceptions for refusals.
abstract interface class NeoAccountTransport {
  Future<Map<String, dynamic>> json(
    String method,
    String path, {
    Map<String, dynamic>? body,
  });

  Future<NeoDownload> download(
    String method,
    String path, {
    Map<String, dynamic>? body,
  });
}

/// One account route: an HTTP method and a path.
class NeoAccountRoute {
  const NeoAccountRoute(this.method, this.path);
  final String method, path;

  bool get hasBody => method != 'GET' && method != 'HEAD';
}

/// Where an app serves its account routes. Defaults are the NeoAgent and
/// NeoCloud paths; apps pass their own.
class NeoAccountRoutes {
  const NeoAccountRoutes({
    this.export = const NeoAccountRoute('POST', '/api/account/export'),
    this.delete = const NeoAccountRoute('POST', '/api/account/delete'),
    this.email = const NeoAccountRoute('PUT', '/api/account/email'),
    this.sessions = const NeoAccountRoute('GET', '/api/account/sessions'),
    this.revokeSession = const NeoAccountRoute(
      'DELETE',
      '/api/account/sessions/{id}',
    ),
    this.signOutEverywhere = const NeoAccountRoute(
      'POST',
      '/api/account/sessions/revoke-all',
    ),
  });

  final NeoAccountRoute export,
      delete,
      email,
      sessions,
      revokeSession,
      signOutEverywhere;
}

/// The body field names of the account routes.
class NeoAccountFields {
  const NeoAccountFields({
    this.password = 'currentPassword',
    this.code = 'code',
    this.confirmation = 'confirmUsername',
    this.email = 'email',
  });

  final String password, code, confirmation, email;
}

/// What a person typed to confirm a sensitive action.
class NeoIdentity {
  const NeoIdentity({
    this.password = '',
    this.code = '',
    this.confirmation = '',
  });
  final String password, code, confirmation;
}

/// One signed-in device of the account.
class NeoAccountSession {
  const NeoAccountSession({
    required this.id,
    required this.current,
    this.ipAddress,
    this.userAgent,
    this.createdAt,
    this.lastSeenAt,
    this.expiresAt,
    this.extra = const <String, dynamic>{},
  });

  factory NeoAccountSession.fromJson(Map<String, dynamic> json) {
    String? text(String key) {
      final v = json[key];
      return v == null || '$v'.isEmpty ? null : '$v';
    }

    DateTime? time(String key) {
      final v = text(key);
      return v == null ? null : DateTime.tryParse(v);
    }

    const known = <String>{
      'id',
      'current',
      'ipAddress',
      'userAgent',
      'createdAt',
      'lastSeenAt',
      'expiresAt',
    };
    return NeoAccountSession(
      id: '${json['id']}',
      current: json['current'] == true,
      ipAddress: text('ipAddress'),
      userAgent: text('userAgent'),
      createdAt: time('createdAt'),
      lastSeenAt: time('lastSeenAt'),
      expiresAt: time('expiresAt'),
      extra: <String, dynamic>{
        for (final e in json.entries)
          if (!known.contains(e.key)) e.key: e.value,
      },
    );
  }

  final String id;
  final bool current;
  final String? ipAddress, userAgent;
  final DateTime? createdAt, lastSeenAt, expiresAt;

  /// App fields, such as "location".
  final Map<String, dynamic> extra;
}

/// Shared account endpoints over the app's transport: data export, account
/// deletion, email change and sessions.
class NeoAccountApi {
  const NeoAccountApi(
    this.transport, {
    this.routes = const NeoAccountRoutes(),
    this.fields = const NeoAccountFields(),
  });

  final NeoAccountTransport transport;
  final NeoAccountRoutes routes;
  final NeoAccountFields fields;

  Map<String, dynamic> _identity(NeoIdentity identity) => <String, dynamic>{
    if (identity.password.isNotEmpty) fields.password: identity.password,
    if (identity.code.trim().isNotEmpty) fields.code: identity.code.trim(),
    if (identity.confirmation.isNotEmpty)
      fields.confirmation: identity.confirmation.trim(),
  };

  /// Downloads the account's export.
  Future<NeoDownload> exportData([NeoIdentity identity = const NeoIdentity()]) {
    final r = routes.export;
    return transport.download(
      r.method,
      r.path,
      body: r.hasBody ? _identity(identity) : null,
    );
  }

  /// Deletes the signed-in account.
  Future<Map<String, dynamic>> deleteAccount(NeoIdentity identity) =>
      transport.json(
        routes.delete.method,
        routes.delete.path,
        body: _identity(identity),
      );

  /// Changes the account's address; the answer may report a pending address.
  Future<Map<String, dynamic>> changeEmail(
    String email,
    NeoIdentity identity,
  ) => transport.json(
    routes.email.method,
    routes.email.path,
    body: <String, dynamic>{fields.email: email.trim(), ..._identity(identity)},
  );

  /// The account's sessions.
  Future<List<NeoAccountSession>> sessions() async => _sessions(
    await transport.json(routes.sessions.method, routes.sessions.path),
  );

  /// Ends another session. Returns the remaining sessions when the server
  /// reports them.
  Future<List<NeoAccountSession>?> revokeSession(String id) async {
    final r = routes.revokeSession;
    final body = await transport.json(
      r.method,
      r.path.replaceAll('{id}', Uri.encodeComponent(id)),
    );
    return body['sessions'] is List ? _sessions(body) : null;
  }

  /// Ends the account's other sessions (or all, where the route does).
  Future<List<NeoAccountSession>?> signOutEverywhere() async {
    final r = routes.signOutEverywhere;
    final body = await transport.json(r.method, r.path);
    return body['sessions'] is List ? _sessions(body) : null;
  }

  static List<NeoAccountSession> _sessions(
    Map<String, dynamic> body,
  ) => <NeoAccountSession>[
    for (final s in (body['sessions'] as List? ?? const <dynamic>[]))
      if (s is Map) NeoAccountSession.fromJson(Map<String, dynamic>.from(s)),
  ];
}
