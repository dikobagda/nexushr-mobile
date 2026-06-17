# NexusHR Mobile App (ESS)

The mobile client (Employee Self Service) for HRIS Pro / NexusHR, built with Flutter.

## Prerequisites

Before running the application, make sure you have the following installed and configured:

1. **Flutter SDK**: Ensure you have Flutter installed (`>= 3.10.9`). Verify using:
   ```bash
   flutter --version
   ```
2. **Platform Tooling**:
   - **Android**: Android Studio and Android SDK (with emulator or a physical device with USB debugging enabled).
   - **iOS (macOS only)**: Xcode, CocoaPods, and an iOS Simulator or connected iOS device.
3. **Backend Server**: Ensure the backend API server is running (usually at port `8080`).

## Configuration

To communicate with the backend server, the app needs to connect to the host IP address:

1. Find the local IP address of your development machine (e.g., `192.168.1.X`).
2. Open the API service file: [api_service.dart](file:///Users/dikobagda/Development/hris-pro/mobile/lib/services/api_service.dart).
3. Update the `hostIp` constant to your machine's local IP address:
   ```dart
   const String hostIp = 'YOUR_LOCAL_IP_ADDRESS';
   ```

## Getting Started

Follow these steps to run the application locally:

### 1. Install Dependencies
Get all the required Flutter packages:
```bash
flutter pub get
```

### 2. Verify Setup
Check that your development environment is fully set up and that a device is connected:
```bash
flutter doctor
flutter devices
```

### 3. Run the Application
Start the application on your default connected device/emulator:
```bash
flutter run
```
Or target a specific device:
```bash
flutter run -d <DEVICE_ID>
```

---

## Project Structure

- `lib/models/`: Data models for users, leaves, payroll, etc.
- `lib/screens/`: App screens (login, dashboard, attendance, leaves, payslips).
- `lib/services/`: API communication, auth, and system services.
- `lib/theme/`: Custom application styling and theme definition.
- `assets/`: Assets used in the application (animations/lottie files and images).
