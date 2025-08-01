@echo off
echo 🚀 Building and Installing ExamTopic Reviewer APK...
echo.

REM Check if Flutter is available
flutter --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Flutter is not installed or not in PATH
    pause
    exit /b 1
)

REM Clean previous builds
echo 🧹 Cleaning previous builds...
flutter clean

REM Get dependencies
echo 📦 Getting dependencies...
flutter pub get

REM Check for connected devices
echo 📱 Checking for connected devices...
flutter devices

REM Build and install APK
echo 🔨 Building and installing APK...
flutter install --release

if errorlevel 1 (
    echo ❌ Build failed! Trying debug build...
    flutter install --debug
    if errorlevel 1 (
        echo ❌ Debug build also failed!
        echo.
        echo 💡 Troubleshooting tips:
        echo 1. Make sure your Android device is connected and USB debugging is enabled
        echo 2. Run 'flutter doctor' to check for issues
        echo 3. Try 'flutter run' to see detailed error messages
        pause
        exit /b 1
    )
)

echo.
echo ✅ APK built and installed successfully!
echo 🎉 Your app should now be running on your device
echo.
pause 