# 🚂 Railway Deployment Guide

## Why Railway? 🎯

Railway is an excellent choice for Python applications because:
- ✅ **Native Python Support** - Excellent Python runtime
- ✅ **Free Tier Available** - $5 credit monthly
- ✅ **Automatic HTTPS** - Secure by default
- ✅ **Easy GitHub Integration** - Automatic deployments
- ✅ **Custom Domains** - Professional URLs
- ✅ **Environment Variables** - Secure configuration management
- ✅ **Better Build System** - Nixpacks for reliable builds
- ✅ **Faster Deployments** - Often faster than Render

## 📋 Prerequisites

1. **GitHub Repository** - Your code must be on GitHub
2. **Railway Account** - Sign up at [railway.app](https://railway.app)
3. **Cloudinary Account** - For image processing (already configured)

## 🚀 Quick Deployment Steps

### 1. Connect GitHub to Railway
1. Go to [railway.app](https://railway.app)
2. Sign up/Login with your GitHub account
3. Authorize Railway to access your repositories

### 2. Create New Project
1. Click "Start a New Project"
2. Select "Deploy from GitHub repo"
3. Choose your repository: `examtopic_reviewer`
4. Railway will automatically detect the configuration

### 3. Configure Environment Variables
In Railway dashboard, add these environment variables:
- `CLOUDINARY_CLOUD_NAME`: examtopicsreviewer
- `CLOUDINARY_API_KEY`: 529466876568613
- `CLOUDINARY_API_SECRET`: _RhzFXsV8171tOhEaliuwtfwEHo

### 4. Deploy!
Railway will automatically:
- ✅ Detect Python project
- ✅ Install dependencies from `requirements.txt`
- ✅ Use `Procfile` for startup command
- ✅ Deploy with HTTPS

## 📡 API Endpoints

Once deployed, your API will be available at:
- **Base URL**: `https://your-app-name.railway.app`

### Available Endpoints:
- `GET /` - API info
- `POST /api/process-images` - Process images via URL
- `POST /api/upload-image` - Direct file upload
- `GET /api/health` - Health check
- `GET /api/stats` - Statistics

## 🔧 Configuration Files

### railway.json
```json
{
  "$schema": "https://railway.app/railway.schema.json",
  "build": {
    "builder": "NIXPACKS"
  },
  "deploy": {
    "numReplicas": 1,
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 10
  }
}
```

### Procfile
```
web: gunicorn --config gunicorn.conf.py api.process-images:app
```

### nixpacks.toml
Railway-specific build configuration for optimal performance.

## 🧪 Testing Your Deployment

### Health Check
```bash
curl https://your-app-name.railway.app/api/health
```

### Root Endpoint
```bash
curl https://your-app-name.railway.app/
```

### Process Image
```bash
curl -X POST https://your-app-name.railway.app/api/process-images \
  -H "Content-Type: application/json" \
  -d '{"image_url": "https://example.com/image.jpg"}'
```

## 🔄 Automatic Deployments

- **Push to main branch** → Automatic deployment
- **Pull requests** → Preview deployments
- **Manual deployments** → Available in Railway dashboard

## 📊 Monitoring

- **Logs** - Real-time application logs
- **Metrics** - Response times and error rates
- **Health Checks** - Automatic monitoring
- **Custom Domains** - Easy domain management

## 💰 Pricing

- **Free Tier**: $5 credit monthly
- **Pay-as-you-go**: Only pay for what you use
- **No hidden fees**: Transparent pricing

## 🆘 Troubleshooting

### Common Issues:
1. **Build Failures** - Check `requirements.txt` for missing dependencies
2. **Runtime Errors** - Check logs in Railway dashboard
3. **Environment Variables** - Verify Cloudinary credentials

### Support:
- Railway Documentation: [docs.railway.app](https://docs.railway.app)
- Railway Discord: [discord.gg/railway](https://discord.gg/railway)

## 🎉 Success!

Your Python API is now running on Railway with:
- ✅ Reliable Python runtime
- ✅ Automatic scaling
- ✅ Professional HTTPS
- ✅ Easy monitoring
- ✅ Fast deployments
- ✅ Great developer experience

Happy coding! 🚂 