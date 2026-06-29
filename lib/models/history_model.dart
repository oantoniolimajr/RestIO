import 'request_model.dart';

class HistoryItem {
  final RequestModel request;
  final DateTime timestamp;
  final int? statusCode;

  HistoryItem({
    required this.request,
    required this.timestamp,
    this.statusCode,
  });

  Map<String, dynamic> toJson() => {
    'request': request.toJson(),
    'timestamp': timestamp.toIso8601String(),
    'statusCode': statusCode,
  };

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
    request: RequestModel.fromJson(json['request']),
    timestamp: DateTime.parse(json['timestamp']),
    statusCode: json['statusCode'],
  );
}
