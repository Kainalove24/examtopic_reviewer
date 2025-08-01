# 🚀 Render + Cloudinary Deployment Guide

## Overview
This guide helps you deploy the Flask API to Render with Cloudinary integration for image processing.

## Quick Start 🚀

### **Option 1: GitHub + Render Dashboard (Recommended)**

1. **Push to GitHub:**
```bash
git add .
git commit -m "Add Render + Cloudinary image server"
git push
```

2. **Deploy to Render:**
- Go to [render.com](https://render.com)
- Sign up/Login with GitHub
- Click "New +" → "Blueprint"
- Select your repository: `examtopic_reviewer`
- Click "Apply" to deploy

3. **Set Environment Variables in Render Dashboard:**
- Go to your service dashboard
- Click "Environment" tab
- Add these variables:
  - `CLOUDINARY_CLOUD_NAME` = your cloud name
  - `CLOUDINARY_API_KEY` = your API key
  - `CLOUDINARY_API_SECRET` = your API secret

## Configuration Files 📋

### render.yaml
```yaml
services:
  - type: web
    name: examtopic_reviewer_api
    runtime: python
    plan: free
    buildCommand: pip install -r requirements.txt
    startCommand: gunicorn api.health:app --config gunicorn.conf.py
    envVars:
      - key: CLOUDINARY_API_SECRET
        sync: false
      - key: CLOUDINARY_API_KEY
        sync: false
      - key: CLOUDINARY_CLOUD_NAME
        sync: false
    region: singapore
    healthCheckPath: /api/health
    autoDeployTrigger: commit
version: "1"
```

### api/requirements.txt
```
Flask==2.3.3
Flask-CORS==4.0.0
requests==2.31.0
cloudinary==1.33.0
gunicorn==21.2.0
```

## API Endpoints 🌐

Once deployed, your API will be available at:
`https://examtopic_reviewer_api.onrender.com`

### Available Endpoints:
- `GET /api/health` - Health check
- `POST /api/process-images` - Process images via URL
- `POST /api/upload-image` - Direct file upload
- `GET /api/stats` - Statistics

## Testing Your API 🧪

### Health Check:
```bash
curl https://examtopic_reviewer_api.onrender.com/api/health
```

### Process Images:
```bash
curl -X POST https://examtopic_reviewer_api.onrender.com/api/process-images \
  -H "Content-Type: application/json" \
  -d '{"image_url": "https://example.com/image.jpg"}'
```

## Flutter Integration 📱

Update your Flutter app to use the Render URL:

```dart
class ApiService {
  static const String renderBaseUrl = 'https://examtopic_reviewer_api.onrender.com';
  
  static String get baseUrl {
    // Use Render URL for production
    return renderBaseUrl;
  }
}
```

## Troubleshooting 🔧

### Common Issues:
1. **Build Fails** - Check requirements.txt and Python version
2. **Service Won't Start** - Verify start command and environment variables
3. **API Not Responding** - Check health endpoint first

### Useful Commands:
```bash
# Test locally before deploying
pip install -r api/requirements.txt
gunicorn api.health:app --config gunicorn.conf.py
```

## Next Steps 🎯

1. ✅ Deploy API to Render
2. ✅ Set environment variables
3. ✅ Test API endpoints
4. ✅ Update Flutter app to use Render URL

## Support 💬
- Render Documentation: [docs.render.com](https://docs.render.com)
- Render Community: [community.render.com](https://community.render.com)

Happy deploying! 🎉 