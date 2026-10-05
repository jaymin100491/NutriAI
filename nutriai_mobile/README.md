# NutriAI Mobile App

AI-Powered Personalized Dietitian Application - Flutter Mobile App

## 🚧 Status

**Current Stage:** Structure and Core Files Created  
**Backend API:** ✅ Running at http://localhost:8000  
**Flutter App:** ⏳ Requires Flutter SDK to build

## Prerequisites

Before you can build and run this Flutter app, you need:

### 1. Install Flutter SDK

**macOS:**
```bash
# Using Homebrew
brew install --cask flutter

# Or download from official website
# https://docs.flutter.dev/get-started/install/macos
```

**Windows:**
- Download Flutter SDK from: https://docs.flutter.dev/get-started/install/windows
- Extract to `C:\src\flutter`
- Add to PATH

**Linux:**
```bash
# Download Flutter
sudo snap install flutter --classic

# Or manual installation
# https://docs.flutter.dev/get-started/install/linux
```

### 2. Verify Installation

```bash
flutter doctor
```

This will check if you have all necessary dependencies:
- Flutter SDK
- Dart SDK
- Android Studio / Xcode
- Android SDK / iOS SDK
- VS Code / Android Studio

### 3. Install Dependencies

```bash
cd nutriai_mobile
flutter pub get
```

## 🏗️ Project Structure

```
nutriai_mobile/
├── lib/
│   ├── main.dart                    # ✅ App entry point
│   ├── core/
│   │   ├── constants/
│   │   │   └── api_constants.dart   # ✅ API URLs
│   │   ├── network/
│   │   │   └── dio_client.dart      # ✅ HTTP client
│   │   └── theme/
│   │       └── app_theme.dart       # ✅ App theme
│   ├── data/
│   │   ├── models/
│   │   │   └── user_model.dart      # ✅ User model
│   │   ├── repositories/            # ⏳ To be implemented
│   │   └── datasources/             # ⏳ To be implemented
│   └── presentation/
│       ├── screens/                 # ⏳ To be implemented
│       ├── widgets/                 # ⏳ To be implemented
│       └── providers/               # ⏳ To be implemented
├── assets/                          # Images, icons, fonts
├── pubspec.yaml                     # ✅ Dependencies
└── README.md                        # This file
```

## 🚀 Quick Start

### Step 1: Start the Backend API

Make sure the backend API is running:

```bash
# In a separate terminal
cd ../nutriai-backend
./run.sh
```

Verify at: http://localhost:8000/health

### Step 2: Update API URL (Important!)

If testing on a physical device, update the API URL in:
`lib/core/constants/api_constants.dart`

```dart
// For emulator/simulator (default)
static const String baseUrl = 'http://localhost:8000';

// For physical device on same network
// Replace with your computer's IP address
static const String baseUrl = 'http://192.168.1.100:8000';
```

Find your IP:
- **macOS/Linux:** `ifconfig | grep inet`
- **Windows:** `ipconfig`

### Step 3: Run the App

**iOS Simulator:**
```bash
flutter run -d "iPhone 15 Pro"
```

**Android Emulator:**
```bash
flutter run -d emulator-5554
```

**Chrome (Web):**
```bash
flutter run -d chrome
```

**Physical Device:**
```bash
# Enable USB debugging, connect device
flutter devices
flutter run -d <device-id>
```

## 📱 Features to Implement

### ✅ Completed
- [x] Project structure
- [x] Dependencies configuration
- [x] API client with automatic token refresh
- [x] App theme
- [x] Data models (User)

### ⏳ In Progress
- [ ] Authentication screens (Login, Register)
- [ ] Dashboard screen
- [ ] Lab results screen
- [ ] Diet plan screen with calendar
- [ ] Recipe browser
- [ ] Daily tracking form
- [ ] Progress charts
- [ ] Profile management

## 🎨 Design System

### Colors
- **Primary:** Green (#2E7D32) - Health & wellness
- **Secondary:** Light Green (#4CAF50)
- **Accent:** Orange (#FF9800) - Highlights
- **Background:** Light Gray (#F5F5F5)

### Typography
- **Primary Font:** System default (Roboto on Android, SF Pro on iOS)
- **Sizes:** 12px (caption), 14px (body), 16px (subtitle), 20px (title), 24px (heading)

## 📦 Dependencies

### Core
- `flutter_riverpod` - State management
- `dio` - HTTP client
- `retrofit` - REST API client generator
- `flutter_secure_storage` - Secure token storage

### UI
- `flutter_screenutil` - Responsive design
- `cached_network_image` - Image caching
- `fl_chart` - Charts for progress tracking
- `shimmer` - Loading placeholders

### Utilities
- `intl` - Internationalization
- `logger` - Logging
- `shared_preferences` - Local storage

## 🔑 Authentication Flow

1. **Login Screen** → Enter email & password
2. **API Call** → POST /api/v1/auth/login
3. **Store Tokens** → Save access_token & refresh_token in secure storage
4. **Navigate** → Go to Dashboard
5. **Auto-refresh** → Dio interceptor handles token refresh

## 📊 API Integration

The app connects to the backend API at `localhost:8000`:

```dart
// Example API call
final dio = DioClient().dio;
final response = await dio.get('/api/v1/users/profile');
```

All API calls automatically include:
- Bearer token authentication
- Token refresh on 401
- Request/response logging
- Error handling

## 🧪 Testing

```bash
# Run unit tests
flutter test

# Run integration tests
flutter test integration_test

# Run with coverage
flutter test --coverage
```

## 📱 Platform-Specific Setup

### iOS
1. Open `ios/Runner.xcworkspace` in Xcode
2. Set Team in Signing & Capabilities
3. Run `flutter run`

### Android
1. Open `android/` folder in Android Studio
2. Sync Gradle files
3. Run `flutter run`

## 🐛 Troubleshooting

### "Unable to connect to API"
- Ensure backend is running at http://localhost:8000
- For physical devices, use your computer's IP address
- Check firewall settings

### "Package not found"
```bash
flutter clean
flutter pub get
```

### "iOS build failed"
```bash
cd ios
pod install
cd ..
flutter run
```

## 📖 Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Riverpod State Management](https://riverpod.dev/)
- [Dio HTTP Client](https://pub.dev/packages/dio)
- [Flutter Cookbook](https://docs.flutter.dev/cookbook)

## 🚀 Next Steps

1. **Install Flutter SDK** if not already done
2. **Run `flutter pub get`** to install dependencies
3. **Build authentication screens** (Login/Register)
4. **Implement dashboard** with user stats
5. **Add diet plan viewer** with calendar
6. **Create recipe browser** with search
7. **Build tracking forms** for daily metrics
8. **Add progress charts** using fl_chart

## 📝 Notes

- Backend API must be running for the app to function
- Use demo credentials: `john.doe@example.com` / any password
- All data is currently mock data (resets on API restart)
- Ready for real database integration when PostgreSQL is set up

---

**Ready to build?** Run `flutter pub get` and then `flutter run`!
