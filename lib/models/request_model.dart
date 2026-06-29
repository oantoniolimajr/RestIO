import 'package:flutter/material.dart';

enum HttpMethod { GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS }

enum BodyType { none, formData, xWwwFormUrlEncoded, raw }

enum RawType { text, javascript, json, html, xml }

class KeyValue {
  String key;
  String value;
  String description;
  bool enabled;

  KeyValue({this.key = '', this.value = '', this.description = '', this.enabled = true});

  Map<String, dynamic> toJson() => {
    'key': key,
    'value': value,
    'description': description,
    'enabled': enabled,
  };

  factory KeyValue.fromJson(Map<String, dynamic> json) => KeyValue(
    key: json['key'] ?? '',
    value: json['value'] ?? '',
    description: json['description'] ?? '',
    enabled: json['enabled'] ?? true,
  );
}

class RequestModel {
  HttpMethod method;
  String url;
  List<KeyValue> queryParams;
  List<KeyValue> headers;
  String authType; // No Auth, Basic Auth, Bearer Token, JWT Token
  Map<String, String> authData;
  BodyType bodyType;
  RawType rawType;
  String bodyContent;

  RequestModel({
    this.method = HttpMethod.GET,
    this.url = '',
    List<KeyValue>? queryParams,
    List<KeyValue>? headers,
    this.authType = 'No Auth',
    Map<String, String>? authData,
    this.bodyType = BodyType.none,
    this.rawType = RawType.json,
    this.bodyContent = '',
  }) : queryParams = queryParams ?? [KeyValue()],
       headers = headers ?? [KeyValue()],
       authData = authData ?? {};

  Map<String, dynamic> toJson() => {
    'method': method.index,
    'url': url,
    'queryParams': queryParams.map((e) => e.toJson()).toList(),
    'headers': headers.map((e) => e.toJson()).toList(),
    'authType': authType,
    'authData': authData,
    'bodyType': bodyType.index,
    'rawType': rawType.index,
    'bodyContent': bodyContent,
  };

  factory RequestModel.fromJson(Map<String, dynamic> json) => RequestModel(
    method: HttpMethod.values[json['method'] ?? 0],
    url: json['url'] ?? '',
    queryParams: (json['queryParams'] as List?)?.map((e) => KeyValue.fromJson(e)).toList(),
    headers: (json['headers'] as List?)?.map((e) => KeyValue.fromJson(e)).toList(),
    authType: json['authType'] ?? 'No Auth',
    authData: Map<String, String>.from(json['authData'] ?? {}),
    bodyType: BodyType.values[json['bodyType'] ?? 0],
    rawType: RawType.values[json['rawType'] ?? 0],
    bodyContent: json['bodyContent'] ?? '',
  );

  RequestModel copy() {
    return RequestModel.fromJson(toJson());
  }
}

extension HttpMethodColor on HttpMethod {
  Color get color {
    switch (this) {
      case HttpMethod.GET:
        return Colors.green;
      case HttpMethod.POST:
        return Colors.amber[700]!;
      case HttpMethod.PUT:
        return Colors.blue;
      case HttpMethod.PATCH:
        return Colors.purple;
      case HttpMethod.DELETE:
        return Colors.red;
      case HttpMethod.HEAD:
        return Colors.green;
      case HttpMethod.OPTIONS:
        return const Color(0xFFFF00FF);
    }
  }
}
