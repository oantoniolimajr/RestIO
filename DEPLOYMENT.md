# Deployment Guide - RestIO

This guide details the steps required to package **RestIO** for distribution on macOS (.dmg) and Windows (.exe).

---

## 🍎 macOS (.dmg)

To generate a professional disk image (.dmg) for macOS, we use the `appdmg` utility.

### 1. Prerequisites
- **Node.js** installed on your machine.
- Install `appdmg` globally:
  ```bash
  npm install -g appdmg
  ```

### 2. Build the Application
Compile the project in release mode:
```bash
flutter build macos --release
```
The output will be generated at: `build/macos/Build/Products/Release/RestIO.app`.

### 3. Packaging
Create a configuration file named `dmg_config.json` (already configured in the project) and run:
```bash
appdmg dmg_config.json RestIO.dmg
```

> **Note:** For official distribution, you must sign the app using an Apple Developer Certificate and perform Notarization via `xcrun altool`.

---

## 🪟 Windows (.exe)

To generate an installer for Windows, we recommend using **Inno Setup** for a standard wizard experience.

### 1. Prerequisites
- **Inno Setup** installed (Download from [jrsoftware.org](https://jrsoftware.org/isdl.php)).

### 2. Build the Application
Compile the project in release mode:
```bash
flutter build windows --release
```
The output files (including `RestIO.exe` and necessary `.dll` files) will be at: `build/windows/runner/Release/`.

### 3. Packaging with Inno Setup
1. Open **Inno Setup Compiler**.
2. Create a new script using the **Wizard**.
3. Set the **Application Main Executable** to the `RestIO.exe` found in the build folder.
4. Add all other files and folders from the `build/windows/runner/Release/` directory to the "Other application files" section.
5. Follow the wizard to generate the `.iss` script and compile it.
6. The final output will be a single `mysetup.exe` (installer).

---

## 🚀 Automated Distribution (Recommended)

For a unified workflow across all platforms, you can use the [**flutter_distributor**](https://pub.dev/packages/flutter_distributor) package.

1. Add to your `pubspec.yaml`:
   ```yaml
   dev_dependencies:
     flutter_distributor: ^0.4.0
   ```
2. Configure your `distribute_options.yaml`.
3. Run the distribution command:
   ```bash
   flutter_distributor package --platform macos --targets dmg
   flutter_distributor package --platform windows --targets exe
   ```

---

## 📄 Final Check
- Ensure all assets (icons, fonts) are bundled correctly.
- Test the generated installer on a clean machine before public release.
