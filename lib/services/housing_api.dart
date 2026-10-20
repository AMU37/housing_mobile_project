import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/housing_models.dart';

/// استثناء يحمل رسالة خطأ عربية قابلة للعرض للمستخدم.
class ApiException implements Exception {
  ApiException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

/// عميل REST خفيف يتصل بخادم إدارة السكن المشترك.
///
/// يعتمد على حزمة `http` ليعمل على الويب (Android/iOS/Web) معاً.
class HousingApi {
  HousingApi({String? baseUrl, this.token})
      : baseUrl = _normalize(baseUrl ?? AppConfig.defaultBaseUrl);

  final String baseUrl;
  String? token;

  static String _normalize(String url) {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  /// اختبار الوصول للخادم.
  Future<bool> checkHealth() async {
    try {
      await _request('GET', '/health');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final data = await _request('POST', '/auth/login', body: {
      'username': username,
      'password': password,
    });
    return (data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> fetchBootstrapRaw() async {
    final data = await _request('GET', '/bootstrap');
    return (data as Map).cast<String, dynamic>();
  }

  Future<List<ContractorRequest>> fetchContractorRequests() async {
    final data = await _request('GET', '/contractor-requests');
    final list = ((data as Map)['data'] as List?) ?? const [];
    return list.map((e) => ContractorRequest.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  Future<ContractorRequest> submitContractorRequest({
    required String contractorId,
    required String type,
    required String workerName,
    String employeeCode = '',
    String jobTitle = '',
    String reason = '',
    String workerCardNumber = '',
    DateTime? workerBirthDate,
    String workerBirthPlace = '',
  }) async {
    final data = await _request('POST', '/contractor-requests', body: {
      'contractorId': contractorId,
      'requestType': type,
      'workerName': workerName,
      'employeeCode': employeeCode,
      'jobTitle': jobTitle,
      'reason': reason,
      'workerCardNumber': workerCardNumber,
      'workerBirthDate': workerBirthDate?.toIso8601String(),
      'workerBirthPlace': workerBirthPlace,
    });
    return ContractorRequest.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<ContractorRequest> approveHousing(String requestId, {String notes = ''}) =>
      _request('POST', '/contractor-requests/$requestId/approve-housing', body: {'notes': notes})
          .then((d) => ContractorRequest.fromJson((d as Map).cast<String, dynamic>()));

  Future<ContractorRequest> approveSecurity(String requestId, {String notes = ''}) =>
      _request('POST', '/contractor-requests/$requestId/approve-security', body: {'notes': notes})
          .then((d) => ContractorRequest.fromJson((d as Map).cast<String, dynamic>()));

  Future<ContractorRequest> rejectRequest(String requestId, {String notes = ''}) =>
      _request('POST', '/contractor-requests/$requestId/reject', body: {'notes': notes})
          .then((d) => ContractorRequest.fromJson((d as Map).cast<String, dynamic>()));

  Future<dynamic> _request(String method, String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl${path.startsWith('/') ? path : '/$path'}');
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json; charset=utf-8',
      if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
    };
    final encoded = body != null ? jsonEncode(body) : null;
    try {
      late http.Response response;
      switch (method) {
        case 'POST':
          response = await http.post(uri, headers: headers, body: encoded).timeout(AppConfig.apiTimeout);
          break;
        case 'PATCH':
          response = await http.patch(uri, headers: headers, body: encoded).timeout(AppConfig.apiTimeout);
          break;
        default:
          response = await http.get(uri, headers: headers).timeout(AppConfig.apiTimeout);
      }
      final responseText =
          utf8.decode(response.bodyBytes, allowMalformed: true);
      final decoded = responseText.trim().isEmpty ? null : _tryDecode(responseText);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = decoded is Map && decoded['error'] != null
            ? decoded['error'].toString()
            : 'تعذّر تنفيذ العملية (رمز ${response.statusCode})';
        throw ApiException(message, response.statusCode);
      }
      return decoded;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('الخادم يستغرق وقتاً في الاستيقاظ (الخطة المجانية). أعد المحاولة بعد لحظات');
    } on FormatException {
      throw ApiException('رد غير مفهوم من الخادم');
    } catch (e) {
      throw ApiException('تعذّر الاتصال بالخادم — تحقق من الشبكة وعنوان الخادم');
    }
  }

  dynamic _tryDecode(String text) {
    try {
      return jsonDecode(text);
    } catch (_) {
      return null;
    }
  }
}
