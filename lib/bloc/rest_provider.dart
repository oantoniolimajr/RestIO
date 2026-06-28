import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../models/request_model.dart';
import '../models/response_model.dart';

class RestProvider extends ChangeNotifier {
  final Dio _dio = Dio();
  RequestModel request = RequestModel();
  ResponseModel? response;
  bool isLoading = false;

  void updateMethod(HttpMethod method) {
    request.method = method;
    notifyListeners();
  }

  void updateUrl(String url) {
    request.url = url;
    _syncUrlToParams();
    notifyListeners();
  }

  void updateQueryParams() {
    _syncParamsToUrl();
    notifyListeners();
  }

  void _syncUrlToParams() {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return;

    if (!uri.hasQuery) {
      // Only reset if there was something before to avoid unnecessary notifications
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
    
    // Add query params to URL if not already there
    final enabledQueryParams = request.queryParams.where((kv) => kv.enabled && kv.key.isNotEmpty).toList();
    if (enabledQueryParams.isNotEmpty) {
      final queryString = enabledQueryParams.map((kv) => '${Uri.encodeComponent(kv.key)}=${Uri.encodeComponent(kv.value)}').join('&');
      url += (url.contains('?') ? '&' : '?') + queryString;
    }

    final List<String> curlParts = ["curl -X $method '$url'"];

    // Headers
    Map<String, String> headers = {};
    for (var kv in request.headers) {
      if (kv.enabled && kv.key.isNotEmpty) {
        headers[kv.key] = kv.value;
      }
    }

    // Auth
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

    // Body
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
    sb.writeln("Time: ${response!.time?.inMilliseconds ?? 0}ms");
    
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
      // Prepare query params
      Map<String, dynamic> queryParameters = {};
      for (var kv in request.queryParams) {
        if (kv.enabled && kv.key.isNotEmpty) {
          queryParameters[kv.key] = kv.value;
        }
      }

      // Prepare headers
      Map<String, dynamic> headers = {};
      for (var kv in request.headers) {
        if (kv.enabled && kv.key.isNotEmpty) {
          headers[kv.key] = kv.value;
        }
      }

      // Handle Auth
      if (request.authType == 'Bearer Token' && request.authData.containsKey('token')) {
        headers['Authorization'] = 'Bearer ${request.authData['token']}';
      } else if (request.authType == 'Basic Auth') {
        // Basic auth logic
      }

      // Handle Body
      dynamic body;
      if (request.bodyType == BodyType.formData) {
        body = FormData.fromMap({}); // Simple implementation
      } else if (request.bodyType == BodyType.xWwwFormUrlEncoded) {
        body = {}; // Simple implementation
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
      
      // Calculate request size (URL + Headers + Body)
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
    } catch (e) {
      response = ResponseModel(
        statusCode: 0,
        statusMessage: e.toString(),
        data: e.toString(),
      );
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
