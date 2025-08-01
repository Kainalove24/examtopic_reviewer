@echo off
setlocal enabledelayedexpansion

echo ========================================
echo    Flutter Web App Deploy Script
echo ========================================
echo.

echo [1/5] Cleaning previous build...
flutter clean
if !errorlevel! neq 0 (
    echo ERROR: Failed to clean build
    echo.
    pause
    exit /b 1
)
echo ✓ Clean completed
echo.

echo [2/5] Getting dependencies...
flutter pub get
if !errorlevel! neq 0 (
    echo ERROR: Failed to get dependencies
    echo.
    pause
    exit /b 1
)
echo ✓ Dependencies updated
echo.

echo [3/5] Building web app...
flutter build web
if !errorlevel! neq 0 (
    echo ERROR: Failed to build web app
    echo.
    pause
    exit /b 1
)
echo ✓ Web build completed
echo.

echo [4/5] Deploying to Firebase...
firebase deploy --only hosting
if !errorlevel! neq 0 (
    echo ERROR: Failed to deploy to Firebase
    echo.
    pause
    exit /b 1
)
echo ✓ Deployment completed
echo.

echo [5/5] Deployment successful!
echo.
echo Your app is now live at:
echo https://examtopic-reviewer.web.app
echo.
echo ========================================
echo Deployment completed successfully!
echo ========================================
echo.
pause 