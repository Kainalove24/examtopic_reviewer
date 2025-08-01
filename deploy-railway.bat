@echo off
echo 🚂 Deploying to Railway...
echo.

echo 📦 Railway Configuration Files Created:
echo ✅ railway.json - Railway deployment config
echo ✅ Procfile - Startup command
echo ✅ nixpacks.toml - Build configuration
echo ✅ requirements.txt - Python dependencies
echo ✅ gunicorn.conf.py - Production server
echo.

echo 🌐 To deploy to Railway:
echo 1. Go to https://railway.app
echo 2. Sign up/Login with GitHub
echo 3. Click "Start a New Project"
echo 4. Select "Deploy from GitHub repo"
echo 5. Choose repository: examtopic_reviewer
echo 6. Railway will auto-detect configuration
echo 7. Add environment variables in dashboard:
echo    - CLOUDINARY_CLOUD_NAME: examtopicsreviewer
echo    - CLOUDINARY_API_KEY: 529466876568613
echo    - CLOUDINARY_API_SECRET: _RhzFXsV8171tOhEaliuwtfwEHo
echo 8. Deploy!
echo.

echo 📋 Your API endpoints will be:
echo - GET / - API info
echo - POST /api/process-images
echo - POST /api/upload-image  
echo - GET /api/health
echo - GET /api/stats
echo.

echo ✅ Railway deployment configuration complete!
echo 🚂 Railway advantages over Render:
echo - Better Python support
echo - Faster deployments
echo - $5 free credit monthly
echo - Nixpacks build system
pause 