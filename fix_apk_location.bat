@echo off
echo 🔧 Fixing APK location issue...

REM Check if APK exists in the correct location
if exist "android\app\build\outputs\flutter-apk\app-debug.apk" (
    echo ✅ Found APK in correct location
    echo 📁 APK size: 
    dir "android\app\build\outputs\flutter-apk\app-debug.apk" | find "app-debug.apk"
    
    REM Create build directory if it doesn't exist
    if not exist "build\app\outputs\flutter-apk" (
        mkdir "build\app\outputs\flutter-apk" 2>nul
    )
    
    REM Copy APK to expected location
    copy "android\app\build\outputs\flutter-apk\app-debug.apk" "build\app\outputs\flutter-apk\app-debug.apk" >nul
    echo ✅ APK copied to expected location
    
    echo.
    echo 🎉 APK is now available at:
    echo    build\app\outputs\flutter-apk\app-debug.apk
    echo.
    echo 📱 You can now install it manually or use:
    echo    flutter install --debug
) else (
    echo ❌ APK not found in expected location
    echo 🔍 Checking other possible locations...
    
    if exist "android\app\build\outputs\apk\debug\app-debug.apk" (
        echo ✅ Found APK in apk\debug location
        copy "android\app\build\outputs\apk\debug\app-debug.apk" "build\app\outputs\flutter-apk\app-debug.apk" >nul
        echo ✅ APK copied to expected location
    ) else (
        echo ❌ APK not found anywhere
        echo 💡 Try running: flutter build apk --debug
    )
)

pause 