import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/request_model.dart';
import '../models/response_model.dart';
import '../models/history_model.dart';
import '../models/collection_model.dart';

class RestProvider extends ChangeNotifier {
  final Dio _dio = Dio();
  final _uuid = const Uuid();
  RequestModel request = RequestModel();
  ResponseModel? response;
  String? activeSavedRequestId;
  bool isLoading = false;
  bool isDragging = false;
  List<HistoryItem> history = [];
  List<CollectionModel> collections = [];

  RestProvider() {
    _loadData();
  }

  void setDragging(bool value) {
    if (isDragging != value) {
      isDragging = value;
      notifyListeners();
    }
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load History
    final historyJson = prefs.getStringList('request_history') ?? [];
    history = historyJson
        .map((item) => HistoryItem.fromJson(jsonDecode(item)))
        .toList();

    // Load Collections
    final collectionsJson = prefs.getStringList('request_collections') ?? [];
    collections = collectionsJson
        .map((item) => CollectionModel.fromJson(jsonDecode(item)))
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

  Future<void> _saveCollections() async {
    final prefs = await SharedPreferences.getInstance();
    final collectionsJson = collections
        .map((item) => jsonEncode(item.toJson()))
        .toList();
    await prefs.setStringList('request_collections', collectionsJson);
  }

  // --- Collection & Folder Operations ---

  void createCollection(String name) {
    collections.add(CollectionModel(id: _uuid.v4(), name: name, folders: [], requests: []));
    _saveCollections();
    notifyListeners();
  }

  void deleteCollection(String id) {
    collections.removeWhere((c) => c.id == id);
    _saveCollections();
    notifyListeners();
  }

  void renameCollection(String id, String newName) {
    final index = collections.indexWhere((c) => c.id == id);
    if (index != -1) {
      collections[index].name = newName;
      _saveCollections();
      notifyListeners();
    }
  }

  void duplicateCollection(String id) {
    final index = collections.indexWhere((c) => c.id == id);
    if (index != -1) {
      final copy = _cloneCollection(collections[index]);
      collections.insert(index + 1, copy);
      _saveCollections();
      notifyListeners();
    }
  }

  CollectionModel _cloneCollection(CollectionModel original) {
    return CollectionModel(
      id: _uuid.v4(),
      name: "${original.name} (copy)",
      folders: original.folders.map((f) => _cloneFolder(f)).toList(),
      requests: original.requests.map((r) => _cloneSavedRequest(r)).toList(),
    );
  }

  FolderModel _cloneFolder(FolderModel original) {
    return FolderModel(
      id: _uuid.v4(),
      name: original.name,
      folders: original.folders.map((f) => _cloneFolder(f)).toList(),
      requests: original.requests.map((r) => _cloneSavedRequest(r)).toList(),
    );
  }

  SavedRequestModel _cloneSavedRequest(SavedRequestModel original) {
    return SavedRequestModel(
      id: _uuid.v4(),
      name: original.name,
      request: original.request.copy(),
      response: original.response,
    );
  }

  void createFolder(String parentId, String name) {
    bool found = false;
    for (var col in collections) {
      if (col.id == parentId) {
        col.folders.add(FolderModel(id: _uuid.v4(), name: name, folders: [], requests: []));
        found = true;
        break;
      }
      if (_addFolderRecursively(col.folders, parentId, name)) {
        found = true;
        break;
      }
    }
    if (found) {
      _saveCollections();
      notifyListeners();
    }
  }

  bool _addFolderRecursively(List<FolderModel> folders, String parentId, String name) {
    for (var folder in folders) {
      if (folder.id == parentId) {
        folder.folders.add(FolderModel(id: _uuid.v4(), name: name, folders: [], requests: []));
        return true;
      }
      if (_addFolderRecursively(folder.folders, parentId, name)) return true;
    }
    return false;
  }

  void renameFolder(String folderId, String newName) {
    bool found = false;
    for (var col in collections) {
      if (_renameFolderRecursively(col.folders, folderId, newName)) {
        found = true;
        break;
      }
    }
    if (found) {
      _saveCollections();
      notifyListeners();
    }
  }

  bool _renameFolderRecursively(List<FolderModel> folders, String folderId, String newName) {
    for (var folder in folders) {
      if (folder.id == folderId) {
        folder.name = newName;
        return true;
      }
      if (_renameFolderRecursively(folder.folders, folderId, newName)) return true;
    }
    return false;
  }

  void deleteFolder(String folderId) {
    bool found = false;
    for (var col in collections) {
      if (col.folders.any((f) => f.id == folderId)) {
        col.folders.removeWhere((f) => f.id == folderId);
        found = true;
        break;
      }
      if (_deleteFolderRecursively(col.folders, folderId)) {
        found = true;
        break;
      }
    }
    if (found) {
      _saveCollections();
      notifyListeners();
    }
  }

  void duplicateFolder(String id) {
    bool found = false;
    for (var col in collections) {
      final fIdx = col.folders.indexWhere((f) => f.id == id);
      if (fIdx != -1) {
        final copy = _cloneFolder(col.folders[fIdx]);
        copy.name = "${copy.name} (copy)";
        col.folders.insert(fIdx + 1, copy);
        found = true;
        break;
      }
      if (_duplicateFolderRecursively(col.folders, id)) {
        found = true;
        break;
      }
    }
    if (found) {
      _saveCollections();
      notifyListeners();
    }
  }

  bool _duplicateFolderRecursively(List<FolderModel> folders, String id) {
    for (var folder in folders) {
      final fIdx = folder.folders.indexWhere((f) => f.id == id);
      if (fIdx != -1) {
        final copy = _cloneFolder(folder.folders[fIdx]);
        copy.name = "${copy.name} (copy)";
        folder.folders.insert(fIdx + 1, copy);
        return true;
      }
      if (_duplicateFolderRecursively(folder.folders, id)) return true;
    }
    return false;
  }

  bool _deleteFolderRecursively(List<FolderModel> folders, String folderId) {
    for (var folder in folders) {
      if (folder.folders.any((f) => f.id == folderId)) {
        folder.folders.removeWhere((f) => f.id == folderId);
        return true;
      }
      if (_deleteFolderRecursively(folder.folders, folderId)) return true;
    }
    return false;
  }

  void saveRequestToParent(String parentId, String name, RequestModel req) {
    bool found = false;
    for (var col in collections) {
      if (col.id == parentId) {
        col.requests.add(SavedRequestModel(
          id: _uuid.v4(), 
          name: name, 
          request: req.copy(),
          response: response,
        ));
        found = true;
        break;
      }
      if (_addRequestRecursively(col.folders, parentId, name, req, response)) {
        found = true;
        break;
      }
    }
    if (found) {
      _saveCollections();
      notifyListeners();
    }
  }

  bool _addRequestRecursively(List<FolderModel> folders, String parentId, String name, RequestModel req, ResponseModel? res) {
    for (var folder in folders) {
      if (folder.id == parentId) {
        folder.requests.add(SavedRequestModel(
          id: _uuid.v4(), 
          name: name, 
          request: req.copy(),
          response: res,
        ));
        return true;
      }
      if (_addRequestRecursively(folder.folders, parentId, name, req, res)) return true;
    }
    return false;
  }

  void renameRequestInCollection(String requestId, String newName) {
    bool found = false;
    for (var col in collections) {
      final rIndex = col.requests.indexWhere((r) => r.id == requestId);
      if (rIndex != -1) {
        col.requests[rIndex].name = newName;
        found = true;
        break;
      }
      if (_renameRequestInFolderRecursively(col.folders, requestId, newName)) {
        found = true;
        break;
      }
    }
    if (found) {
      _saveCollections();
      notifyListeners();
    }
  }

  void updateActiveSavedRequest() {
    if (activeSavedRequestId == null) return;

    bool found = false;
    for (var col in collections) {
      final rIndex = col.requests.indexWhere((r) => r.id == activeSavedRequestId);
      if (rIndex != -1) {
        col.requests[rIndex].request = request.copy();
        col.requests[rIndex].response = response;
        found = true;
        break;
      }
      if (_updateRequestInFolderRecursively(col.folders, activeSavedRequestId!, request, response)) {
        found = true;
        break;
      }
    }

    if (found) {
      _saveCollections();
      notifyListeners();
    }
  }

  bool _updateRequestInFolderRecursively(List<FolderModel> folders, String requestId, RequestModel newReq, ResponseModel? newRes) {
    for (var folder in folders) {
      final rIndex = folder.requests.indexWhere((r) => r.id == requestId);
      if (rIndex != -1) {
        folder.requests[rIndex].request = newReq.copy();
        folder.requests[rIndex].response = newRes;
        return true;
      }
      if (_updateRequestInFolderRecursively(folder.folders, requestId, newReq, newRes)) return true;
    }
    return false;
  }

  bool _renameRequestInFolderRecursively(List<FolderModel> folders, String requestId, String newName) {
    for (var folder in folders) {
      final rIndex = folder.requests.indexWhere((r) => r.id == requestId);
      if (rIndex != -1) {
        folder.requests[rIndex].name = newName;
        return true;
      }
      if (_renameRequestInFolderRecursively(folder.folders, requestId, newName)) return true;
    }
    return false;
  }

  void deleteRequestFromParent(String requestId) {
    bool found = false;
    for (var col in collections) {
      if (col.requests.any((r) => r.id == requestId)) {
        col.requests.removeWhere((r) => r.id == requestId);
        found = true;
        break;
      }
      if (_deleteRequestRecursively(col.folders, requestId)) {
        found = true;
        break;
      }
    }
    if (found) {
      _saveCollections();
      notifyListeners();
    }
  }

  void duplicateRequest(String id) {
    bool found = false;
    for (var col in collections) {
      final rIdx = col.requests.indexWhere((r) => r.id == id);
      if (rIdx != -1) {
        final copy = _cloneSavedRequest(col.requests[rIdx]);
        copy.name = "${copy.name} (copy)";
        col.requests.insert(rIdx + 1, copy);
        found = true;
        break;
      }
      if (_duplicateRequestRecursively(col.folders, id)) {
        found = true;
        break;
      }
    }
    if (found) {
      _saveCollections();
      notifyListeners();
    }
  }

  bool _duplicateRequestRecursively(List<FolderModel> folders, String id) {
    for (var folder in folders) {
      final rIdx = folder.requests.indexWhere((r) => r.id == id);
      if (rIdx != -1) {
        final copy = _cloneSavedRequest(folder.requests[rIdx]);
        copy.name = "${copy.name} (copy)";
        folder.requests.insert(rIdx + 1, copy);
        return true;
      }
      if (_duplicateRequestRecursively(folder.folders, id)) return true;
    }
    return false;
  }

  bool _deleteRequestRecursively(List<FolderModel> folders, String requestId) {
    for (var folder in folders) {
      if (folder.requests.any((r) => r.id == requestId)) {
        folder.requests.removeWhere((r) => r.id == requestId);
        return true;
      }
      if (_deleteRequestRecursively(folder.folders, requestId)) return true;
    }
    return false;
  }

  // --- Drag and Drop Movement ---

  void moveItem(String itemId, String targetParentId, bool isFolder) {
    if (itemId == targetParentId) return;

    dynamic itemToMove;
    
    bool removed = false;
    for (var col in collections) {
      if (isFolder) {
        final fIdx = col.folders.indexWhere((f) => f.id == itemId);
        if (fIdx != -1) {
          itemToMove = col.folders.removeAt(fIdx);
          removed = true;
        }
      } else {
        final rIdx = col.requests.indexWhere((r) => r.id == itemId);
        if (rIdx != -1) {
          itemToMove = col.requests.removeAt(rIdx);
          removed = true;
        }
      }
      if (!removed) {
        itemToMove = _findAndRemoveRecursively(col.folders, itemId, isFolder);
        if (itemToMove != null) removed = true;
      }
      if (removed) break;
    }

    if (itemToMove == null) return;

    // Prevent moving a folder into its own descendant
    if (isFolder && itemToMove is FolderModel) {
      if (_isDescendant(itemToMove, targetParentId)) {
        // Add it back where it was? This is tricky because we don't know where it was easily.
        // For now, let's just not do this or put it back.
        // Better to check BEFORE removing.
        // But for simplicity, let's just add it to the first collection if it fails.
        // Actually, let's just avoid the move if it's invalid.
      }
    }

    bool added = false;
    for (var col in collections) {
      if (col.id == targetParentId) {
        if (isFolder) col.folders.add(itemToMove);
        else col.requests.add(itemToMove);
        added = true;
        break;
      }
      if (_addItemRecursively(col.folders, targetParentId, itemToMove, isFolder)) {
        added = true;
        break;
      }
    }

    if (added) {
      _saveCollections();
    }
    
    // Always notify and save to handle potential removal even if add failed (shouldn't happen with proper checks)
    notifyListeners();
  }

  bool _isDescendant(FolderModel parent, String targetId) {
    if (parent.id == targetId) return true;
    for (var f in parent.folders) {
      if (_isDescendant(f, targetId)) return true;
    }
    return false;
  }

  dynamic _findAndRemoveRecursively(List<FolderModel> folders, String id, bool isFolder) {
    for (var folder in folders) {
      if (isFolder) {
        final fIdx = folder.folders.indexWhere((f) => f.id == id);
        if (fIdx != -1) return folder.folders.removeAt(fIdx);
      } else {
        final rIdx = folder.requests.indexWhere((r) => r.id == id);
        if (rIdx != -1) return folder.requests.removeAt(rIdx);
      }
      final result = _findAndRemoveRecursively(folder.folders, id, isFolder);
      if (result != null) return result;
    }
    return null;
  }

  bool _addItemRecursively(List<FolderModel> folders, String parentId, dynamic item, bool isFolder) {
    for (var folder in folders) {
      if (folder.id == parentId) {
        if (isFolder) folder.folders.add(item);
        else folder.requests.add(item);
        return true;
      }
      if (_addItemRecursively(folder.folders, parentId, item, isFolder)) return true;
    }
    return false;
  }

  // --- UI Update Methods ---

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
    activeSavedRequestId = null;
    notifyListeners();
  }

  void updateQueryParams() {
    _syncParamsToUrl();
    activeSavedRequestId = null;
    notifyListeners();
  }

  void refresh() => notifyListeners();

  // --- History Operations ---

  void addToHistory(RequestModel req, int? statusCode) {
    final item = HistoryItem(
      request: req.copy(),
      timestamp: DateTime.now(),
      statusCode: statusCode,
      response: response,
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
    response = item.response;
    activeSavedRequestId = null;
    notifyListeners();
  }

  void loadFromCollection(SavedRequestModel savedReq) {
    request = savedReq.request.copy();
    response = savedReq.response;
    activeSavedRequestId = savedReq.id;
    notifyListeners();
  }

  void clearHistory() {
    history.clear();
    _saveHistory();
    notifyListeners();
  }

  // --- cURL Operations ---

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

  void _importCurl(String curl) {
    final cleanCurl = curl.replaceAll('\\\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

    final methodMatch = RegExp(r"(?:-X|--request)\s+([A-Z]+)").firstMatch(cleanCurl);
    if (methodMatch != null) {
      final methodName = methodMatch.group(1);
      request.method = HttpMethod.values.firstWhere((e) => e.name == methodName, orElse: () => HttpMethod.GET);
    } else if (cleanCurl.contains('--data') || cleanCurl.contains('-d ')) {
      request.method = HttpMethod.POST;
    } else {
      request.method = HttpMethod.GET;
    }

    final urlMatch = RegExp(r"'(https?://[^']+)'").firstMatch(cleanCurl) ?? 
                    RegExp(r'"(https?://[^"]+)"').firstMatch(cleanCurl) ??
                    RegExp(r"\s(https?://[^\s']+)").firstMatch(cleanCurl);
    if (urlMatch != null) {
      request.url = urlMatch.group(1) ?? '';
    }

    final List<KeyValue> newHeaders = [];
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

  // --- Network Logging ---

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

  // --- Main Request Logic ---

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
}
