# Architecture Specification: Local-First Network Sync Engine (Deep Dive)

**Author:** Senior Software Architect
**Version:** 1.1 (Technical Deep Dive)

---

## 1. Persistence Layer: The SQLite Schema (Drift)

To support synchronization, we move beyond flat storage to a relational model with metadata tracking.

### 1.1 Tables Definition
*   **`collections`**:
    *   `id`: `Text` (UUID v4) - Primary Key.
    *   `name`: `Text`.
    *   `version`: `Int` (Unix Timestamp of last change) - Used for global state comparison.
*   **`requests`**:
    *   `id`: `Text` (UUID v4) - Primary Key.
    *   `collection_id`: `Text` - Foreign Key (references collections.id) ON DELETE CASCADE.
    *   `method`: `Int` (Enum Index).
    *   `url`: `Text`.
    *   `headers`: `Text` (JSON String).
    *   `body`: `Blob`.
    *   `local_version`: `Int` - Incremented on every local change.
    *   `global_version`: `Int` - Updated only when synced with a peer.
    *   `is_deleted`: `Bool` - Soft delete flag for tombstone propagation.

### 1.2 Performance Requirements
*   **Indexing:** B-Tree indexes on `collection_id` and `is_deleted`.
*   **WAL Mode:** Write-Ahead Logging must be enabled in SQLite to allow concurrent UI reads and background sync writes.

---

## 2. Peer Discovery Protocol (mDNS)

We use **mDNS (Multicast DNS)** via the `nsd` package to eliminate centralized configuration.

### 2.1 Service Announcement
*   **Service Name:** `RestIO Sync`
*   **Type:** `_restio._tcp`
*   **Port:** Dynamically assigned by OS (usually 55xx range).
*   **TXT Records:**
    *   `nodeId`: Unique hardware-bound ID.
    *   `deviceName`: Human-readable name (e.g., "Antonio's MacBook").
    *   `protoVer`: `1.0` (For future backward compatibility).

### 2.2 Handshake Logic
1.  **Discovery:** Browser finds a node of type `_restio._tcp`.
2.  **Connection:** TCP connection established via WebSocket.
3.  **Authentication:** Client sends a `HANDSHAKE_REQ` with a pre-shared PIN or public key.
4.  **Verification:** If authorized, both nodes exchange their current `max(version)` for each collection.

---

## 3. Communication Protocol (The Sync Protocol)

Communication is over WebSockets using the `shelf_web_socket` package. Messages are encoded in **MessagePack** or **Protobuf** for performance, with a JSON fallback.

### 3.1 Message Types
*   **`GET_COLLECTION_SUMMARY`**: Request list of collection IDs and their current versions.
*   **`PUSH_DELTAS`**: Send a list of changed requests since version `X`.
*   **`PULL_DELTAS`**: Request missing changes from a peer.
*   **`ACK`**: Confirm successful write of a sync batch.

### 3.2 Delta Structure
```json
{
  "header": { "type": "PUSH_DELTAS", "node_id": "..." },
  "payload": [
    {
      "entity": "request",
      "op": "upsert",
      "data": { "id": "...", "url": "...", "version": 102 },
      "timestamp": 1678912345678
    }
  ]
}
```

---

## 4. Conflict Resolution: LWW-CRDT

To ensure convergence across nodes:

1.  **Clock Synchronization:** Since local system clocks can drift, we use **Hybrid Logical Clocks (HLC)**. Each delta includes an HLC timestamp.
2.  **Last Write Wins (LWW):** If two nodes modify the same request, the one with the higher HLC timestamp wins.
3.  **Tombstones:** When a request is deleted, it is marked `is_deleted = true` instead of removed. This "Tombstone" is synced to other peers so they also delete it. Pure removal would cause the entity to "resurrect" on the next sync.

---

## 5. Security: AES-GCM-256

*   **Transport Layer:** Encrypted via TLS if possible, otherwise application-level encryption.
*   **End-to-End Encryption (E2EE):**
    *   Sensitive fields (Headers with `Authorization` or `Password`) are encrypted before being placed in the delta.
    *   The encryption key is derived from a **Shared Collection Secret** using PBKDF2.

---

## 6. Resilience Metrics
*   **Auto-Retry:** Exponential backoff (1s, 2s, 4s, 8s) for failed WebSocket connections.
*   **Transactional Integrity:** All sync updates must be wrapped in a single SQLite Transaction. If one delta fails, the entire batch is rolled back.
