import 'request_model.dart';
import 'response_model.dart';
import 'package:uuid/uuid.dart';

class CollectionModel {
  final String id;
  String name;
  final List<FolderModel> folders;
  final List<SavedRequestModel> requests;

  CollectionModel({
    required this.id,
    required this.name,
    required this.folders,
    required this.requests,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'folders': folders.map((e) => e.toJson()).toList(),
    'requests': requests.map((e) => e.toJson()).toList(),
  };

  factory CollectionModel.fromJson(Map<String, dynamic> json) => CollectionModel(
    id: json['id'] ?? const Uuid().v4(),
    name: json['name'] ?? '',
    folders: (json['folders'] as List?)
            ?.map((e) => FolderModel.fromJson(e))
            .toList() ?? [],
    requests: (json['requests'] as List?)
            ?.map((e) => SavedRequestModel.fromJson(e))
            .toList() ?? [],
  );

  CollectionModel copy() {
    return CollectionModel.fromJson(toJson());
  }
}

class FolderModel {
  final String id;
  String name;
  final List<FolderModel> folders;
  final List<SavedRequestModel> requests;

  FolderModel({
    required this.id,
    required this.name,
    required this.folders,
    required this.requests,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'folders': folders.map((e) => e.toJson()).toList(),
    'requests': requests.map((e) => e.toJson()).toList(),
  };

  factory FolderModel.fromJson(Map<String, dynamic> json) => FolderModel(
    id: json['id'] ?? const Uuid().v4(),
    name: json['name'] ?? '',
    folders: (json['folders'] as List?)
            ?.map((e) => FolderModel.fromJson(e))
            .toList() ?? [],
    requests: (json['requests'] as List?)
            ?.map((e) => SavedRequestModel.fromJson(e))
            .toList() ?? [],
  );
}

class SavedRequestModel {
  final String id;
  String name;
  RequestModel request;
  ResponseModel? response;

  SavedRequestModel({
    required this.id,
    required this.name,
    required this.request,
    this.response,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'request': request.toJson(),
    'response': response?.toJson(),
  };

  factory SavedRequestModel.fromJson(Map<String, dynamic> json) => SavedRequestModel(
    id: json['id'] ?? const Uuid().v4(),
    name: json['name'] ?? '',
    request: RequestModel.fromJson(json['request']),
    response: json['response'] != null ? ResponseModel.fromJson(json['response']) : null,
  );
}
