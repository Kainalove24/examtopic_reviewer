@echo off
echo ========================================
echo    Quick Deploy Script
echo ========================================
echo.

echo [1/3] Building web app...
flutter build web
if %errorlevel% neq 0 (
    echo ERROR: Failed to build web app
    pause
    exit /b 1
)
echo ✓ Web build completed
echo.

echo [2/3] Deploying to Firebase...
firebase deploy --only hosting
if %errorlevel% neq 0 (
    echo ERROR: Failed to deploy to Firebase
    pause
    exit /b 1
)
echo ✓ Deployment completed
echo.

echo [3/3] Quick deployment successful!
echo.
echo Your app is now live at:
echo https://examtopic-reviewer.web.app
echo.
echo ========================================
echo Quick deployment completed!
echo ========================================
echo.
pause 