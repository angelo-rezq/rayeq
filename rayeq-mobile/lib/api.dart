import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiFailure implements Exception {
  final String code, message;
  final int status;
  final int? retryAfterSeconds;
  const ApiFailure(
    this.code,
    this.message, {
    this.status = 0,
    this.retryAfterSeconds,
  });
  @override
  String toString() => message;
}

class RayeqApi {
  static const configuredBase = String.fromEnvironment('API_BASE_URL');
  static const designPreview = bool.fromEnvironment(
    'DESIGN_PREVIEW',
    defaultValue: false,
  );
  final http.Client _http;
  final FlutterSecureStorage _storage;
  final String baseUrl;
  String? _token;
  RayeqApi({
    http.Client? client,
    FlutterSecureStorage? storage,
    this.baseUrl = configuredBase,
  }) : _http = client ?? http.Client(),
       _storage = storage ?? const FlutterSecureStorage();
  bool get configured => baseUrl.isNotEmpty;
  bool get signedIn => _token != null;
  Future<void> restore() async {
    _token = await _storage.read(key: 'rayeq_session');
  }

  Future<void> saveSession(Map<String, dynamic> session) async {
    final token = session['token'];
    if (token is! String || token.isEmpty) {
      throw const ApiFailure(
        'INVALID_SESSION',
        'تعذر حفظ جلسة الدخول. جرّب تاني.',
      );
    }
    await _storage.write(key: 'rayeq_session', value: token);
    _token = token;
  }

  Future<void> forgetSession() async {
    _token = null;
    await _storage.delete(key: 'rayeq_session');
  }

  Uri _url(String path, [Map<String, String>? query]) {
    if (!configured) {
      throw const ApiFailure(
        'NOT_CONFIGURED',
        'الخدمة قيد التجهيز، جرّب مرة تانية بعد شوية.',
      );
    }
    final base = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/');
    if (base.scheme != 'https' &&
        base.host != 'localhost' &&
        base.host != '10.0.2.2') {
      throw const ApiFailure(
        'INSECURE_ENDPOINT',
        'تعذر الاتصال الآمن بالخدمة.',
      );
    }
    return base
        .resolve(path.startsWith('/') ? path.substring(1) : path)
        .replace(queryParameters: query);
  }

  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    String? idempotencyKey,
  }) async {
    final req = http.Request(method, _url(path, query));
    req.headers['Accept'] = 'application/json';
    req.headers['Content-Type'] = 'application/json; charset=utf-8';
    if (_token != null) req.headers['Authorization'] = 'Bearer $_token';
    if (idempotencyKey != null) req.headers['Idempotency-Key'] = idempotencyKey;
    if (body != null) req.body = jsonEncode(body);
    http.Response response;
    try {
      response = await http.Response.fromStream(
        await _http.send(req).timeout(const Duration(seconds: 30)),
      ).timeout(const Duration(seconds: 30));
    } catch (_) {
      throw const ApiFailure(
        'NETWORK_ERROR',
        'الاتصال اتأخر. اتأكد من الإنترنت وجرّب تاني.',
      );
    }
    if (response.statusCode == 204) return null;
    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw const ApiFailure(
        'INVALID_RESPONSE',
        'الخدمة مش متاحة دلوقتي. جرّب بعد شوية.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401) await forgetSession();
      final err = decoded is Map ? decoded['error'] : null;
      final code = err is Map && err['code'] is String
          ? err['code'] as String
          : 'REQUEST_FAILED';
      // Never expose arbitrary provider errors or server stack traces in the UI.
      final messages = <String, String>{
        'EMAIL_NOT_VERIFIED': 'فعّل بريدك الإلكتروني الأول.',
        'INVALID_CREDENTIALS': 'الإيميل أو كلمة المرور مش صحيحة.',
        'WORKER_APPROVAL_PENDING': 'حساب العامل في انتظار موافقة الإدارة.',
        'PRICE_CHANGED': 'السعر اتحدث. راجع السعر الجديد قبل تأكيد الطلب.',
        'INVALID_TRANSITION': 'حالة الزيارة اتغيرت. حدّث الصفحة وجرّب تاني.',
        'VALIDATION_ERROR': 'راجع البيانات المطلوبة وجرّب تاني.',
        'RATE_LIMITED': 'طلبات كتير في وقت قصير. استنى شوية وجرّب تاني.',
        'FORBIDDEN': 'الحساب ده معندوش صلاحية للخطوة دي.',
        'AUTH_REQUIRED': 'سجّل دخولك عشان تكمل.',
        'INVALID_CODE': 'الكود مش صحيح أو انتهت صلاحيته.',
        'EMAIL_DELIVERY_UNAVAILABLE':
            'إرسال الإيميل مش متاح حاليًا، جرّب لاحقًا.',
      };
      throw ApiFailure(
        code,
        messages[code] ??
            (response.statusCode == 429
                ? 'استنى شوية قبل المحاولة التالية.'
                : 'الطلب مكملش. جرّب مرة تانية أو تواصل مع الإدارة.'),
        status: response.statusCode,
        retryAfterSeconds: int.tryParse(response.headers['retry-after'] ?? ''),
      );
    }
    return decoded is Map && decoded.containsKey('data')
        ? decoded['data']
        : decoded;
  }

  Future<Map<String, dynamic>> getMap(
    String path, {
    Map<String, String>? query,
  }) async => Map<String, dynamic>.from(
    await request('GET', path, query: query) as Map,
  );
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    String? idempotencyKey,
  }) async => Map<String, dynamic>.from(
    (await request('POST', path, body: body, idempotencyKey: idempotencyKey) ??
            {})
        as Map,
  );
  Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body,
  ) async => Map<String, dynamic>.from(
    await request('PATCH', path, body: body) as Map,
  );
  Future<void> logout() async {
    try {
      await request('POST', 'auth/logout');
    } finally {
      await forgetSession();
    }
  }

  void close() => _http.close();
  static String idempotencyKey() {
    final rng = Random.secure();
    final b = List<int>.generate(16, (_) => rng.nextInt(256));
    b[6] = (b[6] & 15) | 64;
    b[8] = (b[8] & 63) | 128;
    final s = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
  }
}
