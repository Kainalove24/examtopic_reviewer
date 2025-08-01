@echo off
echo 🚀 Render Deployment Script
echo =========================

echo.
echo 📋 Checking prerequisites...

REM Check if git is available
git --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Git is not installed or not in PATH
    echo Please install Git from: https://git-scm.com/
    pause
    exit /b 1
)

echo ✅ Git is available

REM Check if we're in a git repository
git status >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Not in a git repository
    echo Please navigate to your project directory
    pause
    exit /b 1
)

echo ✅ In git repository

echo.
echo 🔄 Checking for changes...
git status --porcelain
if %errorlevel% equ 0 (
    echo.
    echo 📤 Pushing changes to GitHub...
    git add .
    git commit -m "Update for Render deployment"
    git push
    echo ✅ Changes pushed to GitHub
)

echo.
echo 🎯 Next Steps:
echo 1. Go to https://render.com
echo 2. Sign up/Login with GitHub
echo 3. Click "New +" → "Blueprint"
echo 4. Select your repository: examtopic_reviewer
echo 5. Click "Apply" to deploy
echo.
echo 📖 For detailed instructions, see: RENDER_DEPLOYMENT.md
echo.
echo 🚀 Your API will be available at: https://your-app-name.onrender.com
echo.
pause 