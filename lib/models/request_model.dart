enum HttpMethod { GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS }

enum BodyType { none, formData, xWwwFormUrlEncoded, raw }

enum RawType { text, javascript, json, html, xml }

class KeyValue {
  String key;
  String value;
  String description;
  bool enabled;

  KeyValue({this.key = '', this.value = '', this.description = '', this.enabled = true});
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
}
