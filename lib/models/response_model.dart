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
}
