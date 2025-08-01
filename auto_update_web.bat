@echo off
echo ========================================
echo    Auto-Update Flutter Web App
echo ========================================
echo.

REM Change to project directory
cd /d %~dp0
echo [1/5] Changed to project directory: %CD%
echo.

REM Clean previous build
echo [2/5] Cleaning previous build...
flutter clean
IF %ERRORLEVEL% NEQ 0 (
    echo ERROR: Flutter clean failed!
    pause
    exit /b %ERRORLEVEL%
)
echo ✓ Clean completed
echo.

REM Get dependencies
echo [3/5] Getting dependencies...
flutter pub get
IF %ERRORLEVEL% NEQ 0 (
    echo ERROR: Failed to get dependencies!
    pause
    exit /b %ERRORLEVEL%
)
echo ✓ Dependencies updated
echo.

REM Build the Flutter web app
echo [4/5] Building web app...
flutter build web --release
IF %ERRORLEVEL% NEQ 0 (
    echo ERROR: Flutter build failed!
    pause
    exit /b %ERRORLEVEL%
)
echo ✓ Web build completed
echo.

REM Deploy to Firebase Hosting
echo [5/5] Deploying to Firebase...
firebase deploy --only hosting
IF %ERRORLEVEL% NEQ 0 (
    echo ERROR: Firebase deploy failed!
    pause
    exit /b %ERRORLEVEL%
)
echo ✓ Deployment completed
echo.

echo ========================================
echo    Deployment Successful!
echo ========================================
echo.
echo Your app is now live at:
echo https://examtopic-reviewer.web.app
echo.
echo ========================================
echo Auto-update completed successfully!
echo ========================================
echo.
pause
