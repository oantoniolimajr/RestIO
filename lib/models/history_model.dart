import 'request_model.dart';
import 'response_model.dart';

class HistoryItem {
  final RequestModel request;
  final DateTime timestamp;
  final int? statusCode;
  final ResponseModel? response;

  HistoryItem({
    required this.request,
    required this.timestamp,
    this.statusCode,
    this.response,
  });

  Map<String, dynamic> toJson() => {
    'request': request.toJson(),
    'timestamp': timestamp.toIso8601String(),
    'statusCode': statusCode,
    'response': response?.toJson(),
  };

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
    request: RequestModel.fromJson(json['request']),
    timestamp: DateTime.parse(json['timestamp']),
    statusCode: json['statusCode'],
    response: json['response'] != null ? ResponseModel.fromJson(json['response']) : null,
  );
}
