# Render Deployment Guide 🚀

## Overview
This guide will help you deploy your Flask API to Render, a modern cloud platform that offers free hosting for web services.

## Prerequisites ✅
- GitHub repository with your code
- Render account (free)
- Cloudinary account for image storage

## Step-by-Step Deployment

### 1. Prepare Your Repository 📁
Your repository should have the following structure:
```
examtopic_reviewer/
├── api/
│   ├── __init__.py
│   ├── health.py
│   ├── process-images.py
│   └── requirements.txt
├── gunicorn.conf.py
└── render.yaml
```

### 2. Create Render Account 🔐
1. Go to [render.com](https://render.com)
2. Sign up with your GitHub account
3. Verify your email address

### 3. Deploy Your Service 🚀

#### Option A: Using render.yaml (Recommended)
1. Push your code to GitHub
2. In Render dashboard, click "New +"
3. Select "Blueprint" 
4. Connect your GitHub repository
5. Render will automatically detect the `render.yaml` file
6. Click "Apply" to deploy

#### Option B: Manual Setup
1. In Render dashboard, click "New +"
2. Select "Web Service"
3. Connect your GitHub repository
4. Configure the service:
   - **Name**: `examtopic-reviewer-api`
   - **Environment**: `Python`
   - **Build Command**: `pip install -r api/requirements.txt`
   - **Start Command**: `gunicorn api.health:app --config gunicorn.conf.py`
   - **Plan**: Free

### 4. Configure Environment Variables 🔧
In your Render service dashboard, go to "Environment" tab and add:

| Variable | Description | Value |
|----------|-------------|-------|
| `CLOUDINARY_CLOUD_NAME` | Your Cloudinary cloud name | Your cloud name |
| `CLOUDINARY_API_KEY` | Your Cloudinary API key | Your API key |
| `CLOUDINARY_API_SECRET` | Your Cloudinary API secret | Your API secret |

### 5. Deploy and Test 🧪
1. Click "Deploy" 
2. Wait for build to complete (usually 2-5 minutes)
3. Test your API endpoints:
   - Health check: `https://your-app-name.onrender.com/api/health`
   - Image processing: `https://your-app-name.onrender.com/api/process-images`

## Configuration Files 📋

### render.yaml
```yaml
services:
  - type: web
    name: examtopic-reviewer-api
    env: python
    plan: free
    buildCommand: pip install -r api/requirements.txt
    startCommand: gunicorn api.health:app --config gunicorn.conf.py
    envVars:
      - key: PYTHON_VERSION
        value: 3.9.16
      - key: CLOUDINARY_CLOUD_NAME
        sync: false
      - key: CLOUDINARY_API_KEY
        sync: false
      - key: CLOUDINARY_API_SECRET
        sync: false
```

### gunicorn.conf.py
```python
import os

bind = f"0.0.0.0:{os.environ.get('PORT', 5000)}"
workers = 2
worker_class = "sync"
worker_connections = 1000
timeout = 30
keepalive = 2
max_requests = 1000
max_requests_jitter = 50
preload_app = True
```

## Troubleshooting 🔧

### Common Issues:

1. **Build Fails**
   - Check that all dependencies are in `api/requirements.txt`
   - Ensure Python version is compatible

2. **Service Won't Start**
   - Verify the start command is correct
   - Check logs in Render dashboard

3. **Environment Variables Not Set**
   - Go to Environment tab in Render dashboard
   - Add missing variables

4. **API Endpoints Not Working**
   - Test with `/api/health` first
   - Check if Cloudinary credentials are correct

### Useful Commands:
```bash
# Check your app logs
# Go to Render dashboard → Your service → Logs

# Test locally before deploying
pip install -r api/requirements.txt
gunicorn api.health:app --config gunicorn.conf.py
```

## Free Tier Limitations ⚠️
- **Sleep after inactivity**: Your service will sleep after 15 minutes of inactivity
- **Cold start**: First request after sleep may take 30-60 seconds
- **Bandwidth**: 750 hours/month free
- **Build time**: 500 minutes/month free

## Next Steps 🎯
1. Deploy your API to Render
2. Update your Flutter app to use the new Render URL
3. Test all functionality
4. Monitor performance in Render dashboard

## Support 💬
- Render Documentation: [docs.render.com](https://docs.render.com)
- Render Community: [community.render.com](https://community.render.com)
- Flask Documentation: [flask.palletsprojects.com](https://flask.palletsprojects.com)

Happy deploying! 🎉 