# climbing_app

Climbing conditions app for European crags (German/Belgian focus). Shows conditions based on weather, aspect, and rock type.

## Running the app

### Option 1: Chrome (recommended if Linux desktop fails)

```bash
flutter run -d chrome
```

### Option 2: Linux desktop

If you see **"CMake is required for Linux development"** (or missing clang/ninja/pkg-config), install the Linux toolchain:

```bash
sudo apt install clang cmake ninja-build pkg-config
```

Then run:

```bash
flutter run -d linux
```

### Option 3: Android

Install Android Studio and the Android SDK, then connect a device or start an emulator:

```bash
flutter run -d android
```

### Weather API key

For live weather data, run with your OpenWeatherMap API key:

```bash
flutter run -d chrome --dart-define=OPENWEATHER_API_KEY=your_key_here
```

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
