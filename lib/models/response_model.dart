class ResponseModel {
  final int? statusCode;
  final String? statusMessage;
  final dynamic data;
  final Map<String, List<String>> headers;
  final List<String> cookies;
  final Duration time;
  final int size; // in bytes
  final int requestSize; // in bytes

  ResponseModel({
    this.statusCode,
    this.statusMessage,
    this.data,
    this.headers = const {},
    this.cookies = const [],
    this.time = Duration.zero,
    this.size = 0,
    this.requestSize = 0,
  });

  Map<String, dynamic> toJson() => {
    'statusCode': statusCode,
    'statusMessage': statusMessage,
    'data': data,
    'headers': headers,
    'cookies': cookies,
    'time': time.inMilliseconds,
    'size': size,
    'requestSize': requestSize,
  };

  factory ResponseModel.fromJson(Map<String, dynamic> json) => ResponseModel(
    statusCode: json['statusCode'],
    statusMessage: json['statusMessage'],
    data: json['data'],
    headers: (json['headers'] as Map?)?.map((k, v) => MapEntry(k.toString(), List<String>.from(v))) ?? {},
    cookies: List<String>.from(json['cookies'] ?? []),
    time: Duration(milliseconds: json['time'] ?? 0),
    size: json['size'] ?? 0,
    requestSize: json['requestSize'] ?? 0,
  );
}
