# 🚀 Image Processing Server - Render Deployment Guide

This guide will help you deploy your image processing server to Render so it stays always online! ✨

## 📋 What We're Setting Up

- **Always-on image processing server** on Render
- **Automatic health checks** to keep the server running
- **Image caching** to avoid re-downloading the same images
- **RESTful API** for your Flutter app to use

## 🛠️ Prerequisites

1. **Render Account**: Sign up at [render.com](https://render.com)
2. **Render CLI** (optional but recommended):
   ```bash
   # Install Render CLI
   npm install -g @render/cli
   ```

## 🚀 Quick Deployment

### Option 1: Using Render CLI (Recommended)

1. **Login to Render**:
   ```bash
   render login
   ```

2. **Deploy using our script**:
   ```bash
   # Windows
   .\deploy-render-image-server.bat
   
   # PowerShell
   .\deploy-render-image-server.ps1
   ```

### Option 2: Manual Deployment

1. **Connect your GitHub repo** to Render
2. **Create a new Web Service** in Render dashboard
3. **Configure the service**:
   - **Name**: `image-processing-server`
   - **Environment**: `Python`
   - **Build Command**: `pip install --upgrade pip && pip install -r requirements-simple.txt`
   - **Start Command**: `gunicorn api:app --config gunicorn.conf.py`
   - **Health Check Path**: `/api/health`

## 📁 File Structure

```
examtopic_reviewer/
├── api.py                          # Main Flask application
├── render.yaml                     # Render configuration
├── requirements-simple.txt         # Python dependencies
├── gunicorn.conf.py               # Gunicorn server config
├── deploy-render-image-server.bat # Windows deployment script
└── deploy-render-image-server.ps1 # PowerShell deployment script
```

## 🌐 API Endpoints

Once deployed, your server will be available at:
`https://image-processing-server.onrender.com`

### Available Endpoints:

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/` | Home page with API info |
| `POST` | `/api/process-images` | Process image URLs |
| `GET` | `/api/images/<filename>` | Serve processed images |
| `GET` | `/api/health` | Health check |
| `GET` | `/api/stats` | Server statistics |

## 🔧 Configuration Details

### render.yaml
```yaml
services:
  - type: web
    name: image-processing-server
    env: python
    plan: free
    buildCommand: pip install --upgrade pip && pip install -r requirements-simple.txt
    startCommand: gunicorn api:app --config gunicorn.conf.py
    envVars:
      - key: PYTHON_VERSION
        value: 3.9.18
    healthCheckPath: /api/health
    autoDeploy: true
```

### Key Features:
- ✅ **Always Online**: Render keeps the server running 24/7
- ✅ **Auto Deploy**: Automatically deploys when you push to GitHub
- ✅ **Health Checks**: Render monitors the server health
- ✅ **Free Tier**: Available on Render's free plan

## 🔄 Updating Your Flutter App

Update your Flutter app to use the new Render URL:

```dart
// In your image_service.dart
class ImageService {
  static const String baseUrl = 'https://image-processing-server.onrender.com';
  
  static Future<List<String>> processImages(List<String> imageUrls) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/process-images'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'imageUrls': imageUrls}),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<String>.from(data['processedImages']);
    }
    
    throw Exception('Failed to process images');
  }
}
```

## 📊 Monitoring

### Health Check
Visit: `https://image-processing-server.onrender.com/api/health`

### Server Stats
Visit: `https://image-processing-server.onrender.com/api/stats`

## 🔍 Troubleshooting

### Common Issues:

1. **Server not starting**:
   - Check Render logs in the dashboard
   - Verify `api.py` exists and has the correct Flask app

2. **Health check failing**:
   - Ensure `/api/health` endpoint returns 200 status
   - Check if the server is responding

3. **Images not loading**:
   - Verify the `/api/images/<filename>` endpoint works
   - Check if images are being saved to `processed_images/` directory

### Render Dashboard:
- Go to [dashboard.render.com](https://dashboard.render.com)
- Find your `image-processing-server` service
- Check logs and deployment status

## 🎯 Benefits of This Setup

1. **Always Available**: Server runs 24/7 on Render
2. **Automatic Scaling**: Render handles traffic spikes
3. **Cost Effective**: Free tier available
4. **Easy Monitoring**: Built-in health checks and logs
5. **Simple Updates**: Just push to GitHub to deploy

## 🚀 Next Steps

1. **Deploy the server** using one of the methods above
2. **Update your Flutter app** to use the new Render URL
3. **Test the endpoints** to ensure everything works
4. **Monitor the server** using Render dashboard

Your image processing server will now be always online and ready to serve your Flutter app! 🎉 