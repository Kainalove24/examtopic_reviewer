# Image Processing Server 🖼️

This server solves CORS issues by downloading external images and serving them from your local domain.

## Features ✨

- **CORS-Free Images**: Download external images and serve them locally
- **Automatic Caching**: Images are cached to avoid re-downloading
- **Multiple Formats**: Supports PNG, JPG, JPEG, GIF, WebP, BMP
- **File Size Limits**: 10MB maximum file size
- **Health Monitoring**: Built-in health check and statistics endpoints
- **Error Handling**: Comprehensive error reporting

## Quick Start 🚀

### 1. Start the Server
```bash
# Windows
.\start_image_server.bat

# Or manually
python image_processing_server.py
```

### 2. Test the Server
```bash
# Health check
curl http://localhost:5000/api/health

# Process images
curl -X POST http://localhost:5000/api/process-images \
  -H "Content-Type: application/json" \
  -d '{"imageUrls": ["https://example.com/image.png"]}'
```

## API Endpoints 📋

### POST /api/process-images
Process multiple image URLs and return local URLs.

**Request:**
```json
{
  "imageUrls": [
    "https://img.examtopics.com/aws-certified-machine-learning-engineer-associate-mla-c01/image1.png",
    "https://img.examtopics.com/aws-certified-machine-learning-engineer-associate-mla-c01/image2.png"
  ]
}
```

**Response:**
```json
{
  "success": true,
  "processedImages": [
    "/api/images/0d86eee4.png",
    "/api/images/1a2b3c4d.png"
  ],
  "errors": [],
  "totalProcessed": 2,
  "totalErrors": 0
}
```

### GET /api/images/{filename}
Serve a processed image.

### GET /api/health
Health check endpoint.

### GET /api/stats
Server statistics (image count, total size, etc.).

## Integration with Flutter App 🔄

The Flutter app automatically uses this server when importing CSV files with image URLs:

1. **CSV Import**: When importing a CSV with image URLs
2. **Server Processing**: Images are sent to `http://localhost:5000/api/process-images`
3. **Local URLs**: Server returns local URLs like `http://localhost:5000/api/images/filename.png`
4. **CORS-Free**: Images load without CORS issues

## File Structure 📁

```
examtopic_reviewer/
├── image_processing_server.py    # Main server file
├── requirements.txt              # Python dependencies
├── start_image_server.bat       # Windows startup script
├── processed_images/            # Downloaded images (auto-created)
└── IMAGE_SERVER_README.md       # This file
```

## Configuration ⚙️

### Environment Variables
- `IMAGES_DIR`: Directory to store processed images (default: `processed_images`)
- `MAX_FILE_SIZE`: Maximum file size in bytes (default: 10MB)
- `ALLOWED_EXTENSIONS`: Supported image formats

### Server Settings
- **Host**: `0.0.0.0` (accessible from any IP)
- **Port**: `5000`
- **Debug Mode**: Enabled for development

## Troubleshooting 🔧

### Server Won't Start
1. Check Python installation: `python --version`
2. Install dependencies: `pip install -r requirements.txt`
3. Check port availability: `netstat -an | findstr :5000`

### Images Not Processing
1. Check server logs for errors
2. Verify image URLs are accessible
3. Check file size limits
4. Ensure proper HTTP headers

### CORS Issues
1. Verify server is running on `http://localhost:5000`
2. Check browser console for errors
3. Ensure Flutter app is using the correct server URL

## Development 🛠️

### Adding New Features
1. Modify `image_processing_server.py`
2. Add new endpoints as needed
3. Update Flutter integration if required

### Testing
```bash
# Test health endpoint
curl http://localhost:5000/api/health

# Test image processing
curl -X POST http://localhost:5000/api/process-images \
  -H "Content-Type: application/json" \
  -d '{"imageUrls": ["https://example.com/test.png"]}'

# Test image serving
curl http://localhost:5000/api/images/filename.png
```

## Production Deployment 🚀

For production use:

1. **Change Host**: Set `host='127.0.0.1'` for local-only access
2. **Disable Debug**: Set `debug=False`
3. **Use WSGI**: Deploy with Gunicorn or uWSGI
4. **Add Authentication**: Implement API key authentication
5. **Add Rate Limiting**: Prevent abuse
6. **Use HTTPS**: Secure the connection

## Security Considerations 🔒

- **File Validation**: Only allow image files
- **Size Limits**: Prevent large file uploads
- **URL Validation**: Validate external URLs
- **Access Control**: Consider adding authentication
- **Rate Limiting**: Prevent abuse

## Performance Tips ⚡

- **Caching**: Images are automatically cached
- **Compression**: Consider adding image compression
- **CDN**: Use a CDN for better performance
- **Monitoring**: Monitor server statistics

## Support 💬

If you encounter issues:

1. Check the server logs
2. Verify the server is running
3. Test the API endpoints manually
4. Check browser console for errors
5. Ensure proper network connectivity 