@echo off
echo 🚀 Deploying Image Processing Server to Render...
echo.

REM Check if render CLI is installed
render --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Render CLI not found. Please install it first:
    echo    https://render.com/docs/install-cli
    pause
    exit /b 1
)

echo 📦 Building and deploying to Render...
render deploy

if %errorlevel% equ 0 (
    echo ✅ Deployment successful!
    echo 🌐 Your image processing server should be available at:
    echo    https://image-processing-server.onrender.com
    echo.
    echo 📋 API Endpoints:
    echo    GET  / - Home page
    echo    POST /api/process-images - Process image URLs
    echo    GET  /api/images/<filename> - Serve processed images
    echo    GET  /api/health - Health check
    echo    GET  /api/stats - Server statistics
) else (
    echo ❌ Deployment failed. Please check the logs above.
)

pause 