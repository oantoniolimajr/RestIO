import 'request_model.dart';
import 'package:uuid/uuid.dart';

class CollectionModel {
  final String id;
  String name;
  final List<SavedRequestModel> requests;

  CollectionModel({
    required this.id,
    required this.name,
    required this.requests,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'requests': requests.map((e) => e.toJson()).toList(),
  };

  factory CollectionModel.fromJson(Map<String, dynamic> json) => CollectionModel(
    id: json['id'] ?? const Uuid().v4(),
    name: json['name'] ?? '',
    requests: (json['requests'] as List?)
            ?.map((e) => SavedRequestModel.fromJson(e))
            .toList() ?? [],
  );
}

class SavedRequestModel {
  final String id;
  String name;
  final RequestModel request;

  SavedRequestModel({
    required this.id,
    required this.name,
    required this.request,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'request': request.toJson(),
  };

  factory SavedRequestModel.fromJson(Map<String, dynamic> json) => SavedRequestModel(
    id: json['id'] ?? const Uuid().v4(),
    name: json['name'] ?? '',
    request: RequestModel.fromJson(json['request']),
  );
}
