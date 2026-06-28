# RestIO

**RestIO** is a high-performance, cross-platform REST client built with Flutter, designed to provide a lightweight and productive experience for developers to test and debug APIs.

Inspired by industry-standard tools like Postman and Insomnia, RestIO focuses on speed, precise data visualization, and a developer-centric interface.

## 🚀 Overview

RestIO allows you to compose complex HTTP requests and analyze responses with a rich suite of tools. It features a custom-built JSON engine for large payload inspection and deep integration with system-level shortcuts for a seamless workflow.

### Key Features

-   **Comprehensive Request Builder:** Support for all standard HTTP methods (GET, POST, PUT, DELETE, etc.) with intuitive management of Query Parameters, Headers, and Authentication (Basic, Bearer, JWT).
-   **Bidirectional URL Sync:** Real-time synchronization between the URL bar and the Query Parameters table.
-   **Advanced JSON Visualization:**
    -   Syntax Highlighting inspired by VS Code.
    -   Interactive Node Folding (Expand/Collapse) for Objects and Arrays.
    -   Physical Line Numbering.
    -   Integrated Search with real-time highlighting and navigation (Next/Previous).
    -   Word-Wrap toggle and horizontal scrolling support.
-   **Full Context Export:** Export requests as `cURL` commands or generate full diagnostic logs containing both the request context and the detailed response metrics.
-   **Performance Metrics:** Detailed tracking of Status Codes (with descriptions), request/response sizes, and execution latency (ms).
-   **Developer Experience:**
    -   Keyboard Shortcuts (e.g., `Ctrl/Cmd + Enter` to Send).
    -   Adaptive Dark/Light modes.
    -   Compact, high-density UI designed for Desktop efficiency.

---

## 🛠 Tech Stack & Architecture

As an architected solution, RestIO prioritizes maintainability and state consistency.

-   **Framework:** [Flutter](https://flutter.dev/) - Utilizing a single codebase for Desktop (macOS, Windows, Linux), Web, and Mobile.
-   **State Management:** [Provider](https://pub.dev/packages/provider) - Implementing a reactive BLoC-like pattern using `ChangeNotifier` for clean separation of business logic and UI.
-   **Networking:** [Dio](https://pub.dev/packages/dio) - A powerful HTTP client for Dart, supporting interceptors, global configuration, and robust error handling.
-   **Design System:** Custom **Bootstrap-inspired** theme (`BootstrapTheme`) leveraging `Google Fonts (Inter)` for high legibility and standardized component sizing (44px density).

### Project Structure

```text
lib/
├── bloc/           # Business logic and state providers
├── models/         # Immutable data structures and entity definitions
├── widgets/        # Reusable UI components (JsonViewer, Panels, etc.)
├── main.dart       # Application entry point and global shortcut handling
└── bootstrap_theme.dart # Centralized theme and styling engine
```

---

## 🛠 Maintenance & Evolution

For developers looking to contribute or maintain RestIO:

1.  **JSON Viewer:** The `JsonViewer` is a custom recursive widget implementation. When adding new data types, ensure the `_generateJsonLines` logic in `lib/widgets/json_viewer.dart` is updated to maintain syntax highlighting consistency.
2.  **Theming:** All colors and spacing are centralized in `BootstrapTheme`. Avoid hardcoding hex values in widgets to preserve theme-switching integrity.
3.  **Extending Auth:** New authentication methods should be added to the `RequestModel` and handled in `RestProvider.sendRequest()` and `RestProvider.generateCurl()`.

## 📦 Getting Started

1.  **Prerequisites:** Ensure you have the Flutter SDK installed.
2.  **Install Dependencies:**
    ```bash
    flutter pub get
    ```
3.  **Run the Application:**
    ```bash
    flutter run
    ```

---

## 📄 License

This project is open-source and available under the MIT License.
