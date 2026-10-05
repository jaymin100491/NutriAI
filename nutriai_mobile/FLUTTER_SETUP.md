# Flutter App - Setup & Run Instructions

## ✅ What's Complete

- [x] Login Screen (with static user 1@1.com / 111111)
- [x] Dashboard Screen
- [x] Authentication Flow
- [x] State Management (Riverpod)
- [x] API Integration
- [x] Custom Widgets (Button, TextField, BottomNav)
- [x] Theme Configuration

## 🚀 How to Run

### Step 1: Install Flutter SDK

**macOS:**
```bash
brew install --cask flutter
```

**Or download from:** https://docs.flutter.dev/get-started/install

### Step 2: Verify Installation

```bash
flutter doctor
```

Make sure all checkmarks are green:
- ✓ Flutter SDK
- ✓ Android Studio / Xcode
- ✓ VS Code (optional)

### Step 3: Install Dependencies

```bash
cd /Users/jayminpatel/Desktop/SourceCode/Innovation26/nutriai_mobile
flutter pub get
```

### Step 4: Start Backend API

In a separate terminal:
```bash
cd ../nutriai-backend
./run.sh
```

Verify at: http://localhost:8000/health

### Step 5: Update API URL (if needed)

If testing on a physical device, edit `lib/core/constants/api_constants.dart`:

```dart
// For iOS Simulator / Android Emulator (default)
static const String baseUrl = 'http://localhost:8000';

// For physical device on same WiFi
// Replace with your computer's IP address
static const String baseUrl = 'http://192.168.1.X:8000';
```

Find your IP:
- macOS: `ifconfig | grep inet`
- Windows: `ipconfig`

### Step 6: Run the App

**iOS Simulator:**
```bash
flutter run -d "iPhone 15 Pro"
```

**Android Emulator:**
```bash
flutter run
```

**Chrome (for quick testing):**
```bash
flutter run -d chrome
```

## 🔐 Login Credentials

### Quick Login (Pre-filled)
- **Email:** 1@1.com
- **Password:** 111111

### Other Demo Users
- **john.doe@example.com** / any password - Premium user
- **sarah.smith@example.com** / any password - Basic user  
- **mike.johnson@example.com** / any password - Professional user

## 📱 Features Available

✅ **Login Screen**
- Email/password form with validation
- Pre-filled demo credentials
- Loading states
- Error handling
- View other demo users

✅ **Dashboard Screen**
- Welcome message with user name
- Health summary card (LDL cholesterol, weight)
- Today's meals preview (3 meals)
- Quick action buttons (Log Weight, View Plan, Recipes)
- Progress overview (weight loss, adherence)
- Bottom navigation bar

## 🧪 Testing the App

### Test Login Flow
1. Start backend API
2. Run Flutter app
3. See splash screen (2 sec)
4. See login screen
5. Tap Login (credentials pre-filled)
6. Navigate to dashboard

### Test Dashboard
1. See user name in app bar
2. See health metrics
3. See today's meals
4. Tap quick actions (will show TODO)
5. See progress metrics

## 🐛 Troubleshooting

### "Unable to connect to API"
```bash
# For iOS Simulator - use localhost
http://localhost:8000

# For Android Emulator - use 10.0.2.2
http://10.0.2.2:8000

# For physical device - use your IP
http://192.168.1.X:8000
```

### "Packages not found"
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

### "Android build failed"
```bash
flutter clean
flutter pub get
flutter run
```

## 📂 Project Structure

```
lib/
├── main.dart                          # App entry
├── core/
│   ├── constants/api_constants.dart   # API URLs
│   ├── network/dio_client.dart        # HTTP client
│   └── theme/app_theme.dart           # Theme config
├── data/
│   ├── models/
│   │   ├── auth_models.dart           # Login/Token models
│   │   └── user_model.dart            # User model
│   └── repositories/
│       └── auth_repository.dart       # Auth API calls
└── presentation/
    ├── providers/
    │   └── auth_provider.dart         # Auth state
    ├── screens/
    │   ├── auth/
    │   │   └── login_screen.dart      # Login UI
    │   └── dashboard/
    │       └── dashboard_screen.dart  # Dashboard UI
    └── widgets/
        ├── custom_button.dart         # Reusable button
        ├── custom_text_field.dart     # Reusable input
        └── bottom_nav_bar.dart        # Bottom nav
```

## ⏭️ Next Steps

### Immediate (Already Done ✅)
- [x] Login screen
- [x] Dashboard screen
- [x] API integration
- [x] State management

### To Do (Next Week)
- [ ] Diet plan screen
- [ ] Recipe browser
- [ ] Tracking form
- [ ] Progress charts
- [ ] Profile screen
- [ ] Lab results screen

## 📝 Development Notes

### State Management
Using Riverpod with StateNotifier pattern:
- `authProvider` - Authentication state
- Future providers for API data

### API Integration
Using Dio with automatic token refresh:
- Tokens stored in secure storage
- Automatic retry on 401
- Request/response logging

### Navigation
Currently using basic Navigator:
- Splash → Login → Dashboard
- Future: Named routes with go_router

### Styling
Material Design 3 with custom theme:
- Primary: Green (#2E7D32)
- Cards with elevation
- Rounded corners (8px)

## 🎨 UI Screenshots

(Will be added after running the app)

---

**Ready to Run!** 🚀

```bash
flutter pub get
flutter run
```

Then login with: **1@1.com** / **111111**
