# Implementation Guide: Local-First Sync Engine (Phase-by-Phase)

This document provides technical instructions for implementing the architecture described in `SYNC_ARCHITECTURE.md`.

---

## 📦 Phase 1: Drift Database Implementation

### 1.1 Add Dependencies
Add `drift`, `sqlite3_flutter_libs` to `pubspec.yaml`.

### 1.2 Schema Definition
Create `lib/database/database.dart`:
```dart
@DataClassName('RequestEntry')
class Requests extends Table {
  TextColumn get id => text()();
  TextColumn get collectionId => text().references(Collections, #id)();
  IntColumn get method => int()();
  TextColumn get url => text()();
  TextColumn get headers => text()(); // Store as JSON
  BlobColumn get body => blob().nullable()();
  IntColumn get version => integer().withDefault(const Constant(0))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  
  @override
  Set<Column> get primaryKey => {id};
}
```

### 1.3 Auto-Increment Versioning
Use a database trigger or a `beforeInsert/Update` hook in the DAO to automatically increment the `version` column using a millisecond timestamp.

---

## 📡 Phase 2: mDNS & Handshake

### 2.1 Starting Service (Advertiser)
Using the `nsd` package:
```dart
final service = Service(name: 'RestIO-Peer-${nodeId}', type: '_restio._tcp', port: 5511);
await nsd.register(service);
```

### 2.2 Peer Handshake
When a socket connects, the first exchange must be the **Identity Packet**:
```dart
class HandshakePacket {
  final String nodeId;
  final String deviceName;
  final int lastKnownSyncVersion; // The last version I successfully received from you
}
```

---

## ⚙️ Phase 3: Shelf Server & WebSocket

### 3.1 Embedding the Server
Run a `Shelf` server in a separate `Isolate` to prevent UI jank during large data transfers.

### 3.2 Sync Endpoint
```dart
var handler = webSocketHandler((webSocket) {
  webSocket.stream.listen((message) {
    final delta = parseMessage(message);
    syncManager.processIncoming(delta);
  });
});
await shelf_io.serve(handler, '0.0.0.0', 5511);
```

---

## 🔄 Phase 4: Delta Engine & Soft Deletes

### 4.1 Processing Logic
1.  Receive `List<Delta>`.
2.  Start Transaction.
3.  For each Delta:
    *   Find local record by `id`.
    *   If `delta.version > local.version`: Update local row.
    *   Else: Ignore (Conflict - current node has newer data).
4.  Commit Transaction.

### 4.2 Handling Deletions
Ensure your queries always include `where(isDeleted.equals(false))`. Create a periodic cleanup task (e.g., every 30 days) to purge tombstones from the database.

---

## 🎨 Phase 5: Advanced UI Synchronization

### 5.1 The Sync Indicator
*   **Green:** Connected to at least 1 peer, all versions match.
*   **Yellow:** Pending changes in the Outbox.
*   **Red:** Connection error or unauthorized peer.

### 5.2 Collaborative Cursor (Optional Bonus)
Send a lightweight message over the WebSocket when a peer is currently editing a request to show a "John is editing..." badge.

---

## 🛡️ Phase 6: Security Hardware Integration
Use `flutter_secure_storage` to store the **Shared Collection Secrets**. Never store these in plain SQLite or SharedPreferences.
