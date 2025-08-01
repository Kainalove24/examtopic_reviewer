@echo off
echo 🚀 ExamTopic Reviewer - APK Build Script
echo.

REM Check if Flutter is available
flutter --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Flutter is not installed or not in PATH
    pause
    exit /b 1
)

echo ✅ Flutter found
echo.

REM Clean previous builds
echo 🧹 Cleaning previous builds...
flutter clean

REM Get dependencies
echo 📦 Getting dependencies...
flutter pub get

REM Build APK
echo 🔨 Building APK...
flutter build apk --debug

REM Check if build was successful by looking for APK
if exist "android\app\build\outputs\flutter-apk\app-debug.apk" (
    echo.
    echo ✅ APK built successfully!
    echo 📁 Location: android\app\build\outputs\flutter-apk\app-debug.apk
    
    REM Get file size
    for %%A in ("android\app\build\outputs\flutter-apk\app-debug.apk") do (
        echo 📊 Size: %%~zA bytes
    )
    
    echo.
    echo 🔧 Fixing APK location for Flutter...
    
    REM Create build directory if it doesn't exist
    if not exist "build\app\outputs\flutter-apk" (
        mkdir "build\app\outputs\flutter-apk" 2>nul
    )
    
    REM Copy APK to expected location
    copy "android\app\build\outputs\flutter-apk\app-debug.apk" "build\app\outputs\flutter-apk\app-debug.apk" >nul
    echo ✅ APK copied to Flutter's expected location
    
    echo.
    echo 📱 Installation Instructions:
    echo.
    echo 1. Connect your Android device via USB
    echo 2. Enable USB debugging on your device
    echo 3. Run: flutter devices (to verify device is connected)
    echo 4. Run: flutter install --debug (to install the APK)
    echo.
    echo 💡 Alternative: You can manually install the APK from:
    echo    android\app\build\outputs\flutter-apk\app-debug.apk
    echo.
    
) else (
    echo.
    echo ❌ APK build failed!
    echo.
    echo 💡 Troubleshooting tips:
    echo 1. Check for any error messages above
    echo 2. Run 'flutter doctor' to check for issues
    echo 3. Make sure all dependencies are properly installed
    echo 4. Try running 'flutter build apk --debug --verbose' for more details
    echo.
)

pause 