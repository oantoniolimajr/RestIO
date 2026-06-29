import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/request_model.dart';
import '../models/response_model.dart';
import '../models/history_model.dart';

class RestProvider extends ChangeNotifier {
  final Dio _dio = Dio();
  RequestModel request = RequestModel();
  ResponseModel? response;
  bool isLoading = false;
  List<HistoryItem> history = [];

  RestProvider() {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList('request_history') ?? [];
    history = historyJson
        .map((item) => HistoryItem.fromJson(jsonDecode(item)))
        .toList();
    notifyListeners();
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = history
        .map((item) => jsonEncode(item.toJson()))
        .toList();
    await prefs.setStringList('request_history', historyJson);
  }

  void addToHistory(RequestModel req, int? statusCode) {
    final item = HistoryItem(
      request: req.copy(),
      timestamp: DateTime.now(),
      statusCode: statusCode,
    );
    history.insert(0, item);
    if (history.length > 50) {
      history = history.sublist(0, 50);
    }
    _saveHistory();
    notifyListeners();
  }

  void loadFromHistory(HistoryItem item) {
    request = item.request.copy();
    response = null; // Clear response when loading new request
    notifyListeners();
  }

  void clearHistory() {
    history.clear();
    _saveHistory();
    notifyListeners();
  }

  void updateMethod(HttpMethod method) {
    request.method = method;
    notifyListeners();
  }

  void updateUrl(String url) {
    if (url.trim().startsWith('curl ')) {
      _importCurl(url);
    } else {
      request.url = url;
      _syncUrlToParams();
    }
    notifyListeners();
  }

  void _importCurl(String curl) {
    // 1. Pre-process: handle line continuations and normalize spaces
    final cleanCurl = curl.replaceAll('\\\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

    // 2. Extract Method
    final methodMatch = RegExp(r"(?:-X|--request)\s+([A-Z]+)").firstMatch(cleanCurl);
    if (methodMatch != null) {
      final methodName = methodMatch.group(1);
      request.method = HttpMethod.values.firstWhere(
        (e) => e.name == methodName, 
        orElse: () => HttpMethod.GET
      );
    } else if (cleanCurl.contains('--data') || cleanCurl.contains('-d ')) {
      request.method = HttpMethod.POST;
    } else {
      request.method = HttpMethod.GET;
    }

    // 3. Extract URL
    final urlMatch = RegExp(r"'(https?://[^']+)'").firstMatch(cleanCurl) ?? 
                    RegExp(r'"(https?://[^"]+)"').firstMatch(cleanCurl) ??
                    RegExp(r"\s(https?://[^\s']+)").firstMatch(cleanCurl);
    if (urlMatch != null) {
      request.url = urlMatch.group(1) ?? '';
    }

    // 4. Extract Headers
    final List<KeyValue> newHeaders = [];
    // Using triple single quotes to allow double quotes inside without escaping issues
    final headerRegex = RegExp(r'''(?:-H|--header)\s+(['"])(.*?)\1''');
    final headerMatches = headerRegex.allMatches(cleanCurl);

    for (final m in headerMatches) {
      final headerContent = m.group(2) ?? '';
      if (headerContent.contains(':')) {
        final colonIdx = headerContent.indexOf(':');
        final key = headerContent.substring(0, colonIdx).trim();
        final value = headerContent.substring(colonIdx + 1).trim();
        
        if (key.toLowerCase() == 'authorization') {
          _handleAuthHeader(value);
        } else {
          newHeaders.add(KeyValue(key: key, value: value, enabled: true));
        }
      }
    }
    request.headers = newHeaders.isEmpty ? [KeyValue()] : newHeaders;

    // 5. Extract Body
    final bodyRegex = RegExp(r'''(?:-d|--data(?:-raw|-binary)?)\s+(['"])(.*?)\1''');
    final bodyMatch = bodyRegex.firstMatch(cleanCurl);
    
    if (bodyMatch != null) {
      request.bodyType = BodyType.raw;
      request.bodyContent = bodyMatch.group(2) ?? '';
      if (request.bodyContent.trim().startsWith('{') || request.bodyContent.trim().startsWith('[')) {
        request.rawType = RawType.json;
        try {
          final decoded = jsonDecode(request.bodyContent);
          request.bodyContent = const JsonEncoder.withIndent('    ').convert(decoded);
        } catch (_) {}
      }
    } else {
      request.bodyType = BodyType.none;
      request.bodyContent = '';
    }

    // 6. Extract Basic Auth Flag (-u)
    final userRegex = RegExp(r'''(?:-u|--user)\s+(['"]?)(.*?)\1(?:\s|$)''');
    final userMatch = userRegex.firstMatch(cleanCurl);
    if (userMatch != null) {
      final credentials = userMatch.group(2) ?? '';
      if (credentials.contains(':')) {
        request.authType = 'Basic Auth';
        request.authData['username'] = credentials.split(':')[0];
        request.authData['password'] = credentials.split(':')[1];
      }
    }

    // Sync Params table from the newly extracted URL
    _syncUrlToParams();
  }

  void _handleAuthHeader(String value) {
    if (value.toLowerCase().startsWith('bearer ')) {
      request.authType = 'Bearer Token';
      request.authData['token'] = value.substring(7).trim();
    } else if (value.toLowerCase().startsWith('basic ')) {
      request.authType = 'Basic Auth';
      try {
        final decoded = utf8.decode(base64.decode(value.substring(6).trim()));
        if (decoded.contains(':')) {
          request.authData['username'] = decoded.split(':')[0];
          request.authData['password'] = decoded.split(':')[1];
        }
      } catch (_) {}
    }
  }

  void updateQueryParams() {
    _syncParamsToUrl();
    notifyListeners();
  }

  void _syncUrlToParams() {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return;

    if (!uri.hasQuery) {
      if (request.queryParams.length > 1 || (request.queryParams.isNotEmpty && request.queryParams[0].key.isNotEmpty)) {
        request.queryParams = [KeyValue()];
      }
      return;
    }

    final newParams = <KeyValue>[];
    uri.queryParametersAll.forEach((key, values) {
      for (var value in values) {
        newParams.add(KeyValue(key: key, value: value, enabled: true));
      }
    });

    request.queryParams = newParams.isEmpty ? [KeyValue()] : newParams;
  }

  void _syncParamsToUrl() {
    final baseUrl = request.url.contains('?') 
        ? request.url.split('?')[0] 
        : request.url;
    
    final enabledParams = request.queryParams.where((kv) => kv.enabled && kv.key.isNotEmpty).toList();
    
    if (enabledParams.isEmpty) {
      request.url = baseUrl;
    } else {
      final query = enabledParams.map((kv) {
        return '${Uri.encodeComponent(kv.key)}=${Uri.encodeComponent(kv.value)}';
      }).join('&');
      request.url = '$baseUrl?$query';
    }
  }

  void refresh() => notifyListeners();

  String generateCurl() {
    final method = request.method.name;
    var url = request.url;
    
    final enabledQueryParams = request.queryParams.where((kv) => kv.enabled && kv.key.isNotEmpty).toList();
    if (enabledQueryParams.isNotEmpty) {
      final queryString = enabledQueryParams.map((kv) => '${Uri.encodeComponent(kv.key)}=${Uri.encodeComponent(kv.value)}').join('&');
      url += (url.contains('?') ? '&' : '?') + queryString;
    }

    final List<String> curlParts = ["curl -X $method '$url'"];

    Map<String, String> headers = {};
    for (var kv in request.headers) {
      if (kv.enabled && kv.key.isNotEmpty) {
        headers[kv.key] = kv.value;
      }
    }

    if (request.authType == 'Bearer Token' && request.authData.containsKey('token')) {
      headers['Authorization'] = 'Bearer ${request.authData['token']}';
    } else if (request.authType == 'Basic Auth') {
      final user = request.authData['username'] ?? '';
      final pass = request.authData['password'] ?? '';
      final bytes = utf8.encode('$user:$pass');
      final base64Str = base64.encode(bytes);
      headers['Authorization'] = 'Basic $base64Str';
    } else if (request.authType == 'JWT Token' && request.authData.containsKey('token')) {
      headers['Authorization'] = 'Bearer ${request.authData['token']}';
    }

    if (request.bodyType == BodyType.raw && request.rawType == RawType.json) {
      headers['Content-Type'] = 'application/json';
    }

    headers.forEach((key, value) {
      curlParts.add("-H '$key: $value'");
    });

    if (request.bodyType == BodyType.raw && request.bodyContent.isNotEmpty) {
      final escapedBody = request.bodyContent.replaceAll("'", "'\\''");
      curlParts.add("-d '$escapedBody'");
    }

    return curlParts.join(' \\\n  ');
  }

  String generateFullLog() {
    final curl = generateCurl();
    if (response == null) return "--- REQUEST (cURL) ---\n$curl\n\n--- NO RESPONSE YET ---";

    final sb = StringBuffer();
    sb.writeln("--- REQUEST (cURL) ---");
    sb.writeln(curl);
    sb.writeln();
    sb.writeln("--- RESPONSE ---");
    sb.writeln("Status: ${response!.statusCode} ${response!.statusMessage ?? ""}");
    sb.writeln("Time: ${response!.time.inMilliseconds}ms");
    
    if (response!.headers.isNotEmpty) {
      sb.writeln("\nHeaders:");
      response!.headers.forEach((key, values) {
        sb.writeln("  $key: ${values.join(', ')}");
      });
    }

    if (response!.cookies.isNotEmpty) {
      sb.writeln("\nCookies:");
      for (var cookie in response!.cookies) {
        sb.writeln("  $cookie");
      }
    }

    sb.writeln("\nBody:");
    try {
      final body = response!.data;
      if (body is Map || body is List) {
        sb.writeln(const JsonEncoder.withIndent('    ').convert(body));
      } else {
        final decoded = jsonDecode(body.toString());
        sb.writeln(const JsonEncoder.withIndent('    ').convert(decoded));
      }
    } catch (e) {
      sb.writeln(response!.data.toString());
    }

    return sb.toString();
  }

  Future<void> sendRequest() async {
    isLoading = true;
    notifyListeners();

    final startTime = DateTime.now();
    try {
      Map<String, dynamic> queryParameters = {};
      for (var kv in request.queryParams) {
        if (kv.enabled && kv.key.isNotEmpty) {
          queryParameters[kv.key] = kv.value;
        }
      }

      Map<String, dynamic> headers = {};
      for (var kv in request.headers) {
        if (kv.enabled && kv.key.isNotEmpty) {
          headers[kv.key] = kv.value;
        }
      }

      if (request.authType == 'Bearer Token' && request.authData.containsKey('token')) {
        headers['Authorization'] = 'Bearer ${request.authData['token']}';
      } else if (request.authType == 'Basic Auth') {
        if (request.authData.containsKey('username') && request.authData.containsKey('password')) {
            final user = request.authData['username'] ?? '';
            final pass = request.authData['password'] ?? '';
            final bytes = utf8.encode('$user:$pass');
            headers['Authorization'] = 'Basic ${base64.encode(bytes)}';
        }
      }

      dynamic body;
      if (request.bodyType == BodyType.formData) {
        body = FormData.fromMap({}); 
      } else if (request.bodyType == BodyType.xWwwFormUrlEncoded) {
        body = {}; 
      } else if (request.bodyType == BodyType.raw) {
        body = request.bodyContent;
        if (request.rawType == RawType.json) {
          headers['Content-Type'] = 'application/json';
        }
      }

      final res = await _dio.request(
        request.url,
        data: body,
        options: Options(
          method: request.method.name,
          headers: headers,
          validateStatus: (status) => true,
        ),
        queryParameters: queryParameters,
      );

      final endTime = DateTime.now();
      
      int reqSize = request.url.length;
      headers.forEach((k, v) => reqSize += k.length + v.toString().length);
      if (body != null) {
        reqSize += body.toString().length;
      }

      response = ResponseModel(
        statusCode: res.statusCode,
        statusMessage: res.statusMessage,
        data: res.data,
        headers: res.headers.map,
        cookies: res.headers['set-cookie'] ?? [],
        time: endTime.difference(startTime),
        size: res.data.toString().length,
        requestSize: reqSize,
      );
      addToHistory(request, res.statusCode);
    } catch (e) {
      response = ResponseModel(
        statusCode: 0,
        statusMessage: e.toString(),
        data: e.toString(),
      );
      addToHistory(request, 0);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
