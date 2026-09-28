import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  ApiClient({String? baseUrl}) : _overrideBaseUrl = baseUrl;

  // Single production API source of truth
  static const String defaultBaseUrl = 'https://sabzisetu.vercel.app/api';

  final String? _overrideBaseUrl;
  String? _token;

  Future<String> getBaseUrl() async {
    final overrideUrl = _overrideBaseUrl;
    if (overrideUrl != null && overrideUrl.isNotEmpty) {
      return overrideUrl;
    }
    return defaultBaseUrl;
  }

  String get baseUrl => _overrideBaseUrl ?? defaultBaseUrl;

  Future<void> _loadToken() async {
    if (_token != null) return;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
  }

  Future<void> _saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<void> logout() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  Future<bool> hasToken() async {
    await _loadToken();
    return _token != null;
  }

  Future<dynamic> login(String username, String password) async {
    final res = await _request('/auth/login', method: 'POST', body: {
      'username': username,
      'password': password,
    }, skipAuth: true);
    if (res != null && res['token'] != null) {
      await _saveToken(res['token']);
    }
    return res;
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    await _request('/auth/change-password', method: 'POST', body: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  Future<dynamic> _request(String path, {String method = 'GET', Map<String, dynamic>? body, bool skipAuth = false}) async {
    if (!skipAuth) await _loadToken();

    final currentBaseUrl = await getBaseUrl();
    final uri = Uri.parse('$currentBaseUrl$path');
    final headers = {
      'Content-Type': 'application/json',
      if (_token != null && !skipAuth) 'Authorization': 'Bearer $_token',
    };

    late http.Response res;
    int attempt = 0;
    const int maxAttempts = 3;

    while (attempt < maxAttempts) {
      attempt++;
      try {
        switch (method) {
          case 'POST':
            res = await http.post(uri, headers: headers, body: jsonEncode(body));
            break;
          case 'PATCH':
            res = await http.patch(uri, headers: headers, body: jsonEncode(body));
            break;
          case 'PUT':
            res = await http.put(uri, headers: headers, body: jsonEncode(body));
            break;
          case 'DELETE':
            res = await http.delete(uri, headers: headers);
            break;
          default:
            res = await http.get(uri, headers: headers);
        }
        break;
      } catch (e) {
        if (attempt >= maxAttempts) {
          throw Exception('Server connection failed: ${e.toString()}');
        }
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }

    if (res.statusCode == 401 || res.statusCode == 403) {
      if (!skipAuth) {
        await logout();
        throw Exception('Unauthorized');
      }
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      String errorMsg = res.body;
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded['error'] != null) {
          errorMsg = decoded['error'].toString();
        }
      } catch (_) {}
      throw Exception(errorMsg);
    }

    if (res.statusCode == 204 || res.body.trim().isEmpty) return null;
    return jsonDecode(res.body);
  }

  Future<List<Map<String, dynamic>>> list(String resource) async {
    try {
      final res = await _request('/$resource');
      return res is List ? List<Map<String, dynamic>>.from(res) : [];
    } catch (e) {
      if (resource == 'stock/movements') {
        try {
          final res = await _request('/stock-movements');
          return res is List ? List<Map<String, dynamic>>.from(res) : [];
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> create(
      String resource, Map<String, dynamic> body) async {
    final res = await _request('/$resource', method: 'POST', body: body);
    return res is Map ? Map<String, dynamic>.from(res) : {};
  }

  Future<Map<String, dynamic>> update(
      String resource, String id, Map<String, dynamic> body) async {
    final res = await _request('/$resource/$id', method: 'PATCH', body: body);
    return res is Map ? Map<String, dynamic>.from(res) : {};
  }

  Future<void> remove(String resource, String id) async =>
      _request('/$resource/$id', method: 'DELETE');

  Future<Map<String, dynamic>> settings() async {
    final res = await _request('/settings');
    return res is Map ? Map<String, dynamic>.from(res) : {};
  }

  Future<Map<String, dynamic>> saveSettings(Map<String, dynamic> body) async {
    final res = await _request('/settings', method: 'PUT', body: body);
    return res is Map ? Map<String, dynamic>.from(res) : {};
  }

  Future<Map<String, dynamic>> summary() async {
    final res = await _request('/reports/summary');
    return res is Map ? Map<String, dynamic>.from(res) : {};
  }

  Future<List<Map<String, dynamic>>> trend() async {
    final res = await _request('/reports/trend');
    return res is List ? List<Map<String, dynamic>>.from(res) : [];
  }

  Future<Map<String, dynamic>> masters() async {
    final res = await _request('/masters');
    return res is Map ? Map<String, dynamic>.from(res) : {};
  }

  Future<Map<String, dynamic>> health() async {
    final res = await _request('/health');
    return res is Map ? Map<String, dynamic>.from(res) : {};
  }

  Future<Map<String, dynamic>> exportBackup() async {
    final res = await _request('/backup/export');
    return res is Map ? Map<String, dynamic>.from(res) : {};
  }

  Future<Map<String, dynamic>> importBackup(Map<String, dynamic> payload) async {
    final res = await _request('/backup/import', method: 'POST', body: payload);
    return res is Map ? Map<String, dynamic>.from(res) : {};
  }

  Future<Map<String, dynamic>> checkDelete(String resource, String id) async {
    final res = await _request('/$resource/check-delete/$id');
    return res is Map ? Map<String, dynamic>.from(res) : {};
  }

  Future<Map<String, dynamic>> logWhatsAppReminderOpened(String customer, String phone, num amount) async {
    final res = await _request('/whatsapp-bills/log-reminder-opened', method: 'POST', body: {
      'customer': customer,
      'phone': phone,
      'amount': amount,
    });
    return res is Map ? Map<String, dynamic>.from(res) : {};
  }

  Future<Map<String, dynamic>> updateWhatsAppSendAll(bool enabled) async {
    final res = await _request('/settings/whatsapp-send-all', method: 'PATCH', body: {
      'enabled': enabled,
    });
    return res is Map ? Map<String, dynamic>.from(res) : {};
  }

  Future<Map<String, dynamic>> updateItemMaster(String id, Map<String, dynamic> body) async {
    final res = await _request('/masters/items/$id', method: 'PATCH', body: body);
    return res is Map ? Map<String, dynamic>.from(res) : {};
  }

  Future<void> removeSpecification(String id) async =>
      _request('/masters/specifications/$id', method: 'DELETE');

  Future<Map<String, dynamic>> addItemSpecification(String itemId, String name) async {
    final res = await _request('/masters/items/$itemId/specifications', method: 'POST', body: {
      'name': name,
    });
    return res is Map ? Map<String, dynamic>.from(res) : {};
  }

  Future<Map<String, dynamic>> markAllNotificationsRead() async {
    final res = await _request('/notifications/mark-all-read', method: 'POST');
    return res is Map ? Map<String, dynamic>.from(res) : {};
  }
}
