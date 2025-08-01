import os
import requests
import hashlib
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
from urllib.parse import urlparse, quote
import mimetypes
from datetime import datetime
import logging

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Configuration
IMAGES_DIR = 'processed_images'
ALLOWED_EXTENSIONS = {'.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp'}
MAX_FILE_SIZE = 10 * 1024 * 1024  # 10MB limit

# Create images directory if it doesn't exist
os.makedirs(IMAGES_DIR, exist_ok=True)

def get_file_extension(url):
    """Extract file extension from URL"""
    parsed = urlparse(url)
    path = parsed.path
    ext = os.path.splitext(path)[1].lower()
    if ext in ALLOWED_EXTENSIONS:
        return ext
    return '.png'  # Default to PNG

def generate_filename(url):
    """Generate a unique filename for the image"""
    # Create a hash of the URL to avoid conflicts
    url_hash = hashlib.md5(url.encode()).hexdigest()[:8]
    ext = get_file_extension(url)
    return f"{url_hash}{ext}"

def download_image(url):
    """Download image from URL"""
    try:
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
            'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.9',
            'Accept-Encoding': 'gzip, deflate, br',
            'Connection': 'keep-alive',
        }
        
        response = requests.get(url, headers=headers, timeout=30)
        response.raise_for_status()
        
        # Check file size
        if len(response.content) > MAX_FILE_SIZE:
            raise ValueError(f"File too large: {len(response.content)} bytes")
        
        return response.content
    except Exception as e:
        logger.error(f"Failed to download image from {url}: {e}")
        raise

@app.route('/')
def home():
    """Home endpoint"""
    return jsonify({
        'message': 'Image Processing Server is running! 🚀',
        'endpoints': {
            'process_images': 'POST /api/process-images',
            'serve_image': 'GET /api/images/<filename>',
            'health_check': 'GET /api/health',
            'stats': 'GET /api/stats'
        },
        'timestamp': datetime.now().isoformat()
    })

@app.route('/api/process-images', methods=['POST'])
def process_images():
    """Process multiple image URLs and return local URLs"""
    try:
        data = request.get_json()
        if not data or 'imageUrls' not in data:
            return jsonify({'error': 'Missing imageUrls in request'}), 400
        
        image_urls = data['imageUrls']
        if not isinstance(image_urls, list):
            return jsonify({'error': 'imageUrls must be a list'}), 400
        
        processed_images = []
        errors = []
        
        for url in image_urls:
            try:
                # Generate filename
                filename = generate_filename(url)
                filepath = os.path.join(IMAGES_DIR, filename)
                
                # Check if file already exists
                if os.path.exists(filepath):
                    logger.info(f"Image already exists: {filename}")
                    processed_images.append(f"/api/images/{filename}")
                    continue
                
                # Download image
                logger.info(f"Downloading image: {url}")
                image_data = download_image(url)
                
                # Save image
                with open(filepath, 'wb') as f:
                    f.write(image_data)
                
                logger.info(f"Successfully processed: {filename}")
                processed_images.append(f"/api/images/{filename}")
                
            except Exception as e:
                error_msg = f"Failed to process {url}: {str(e)}"
                logger.error(error_msg)
                errors.append(error_msg)
        
        return jsonify({
            'success': True,
            'processedImages': processed_images,
            'errors': errors,
            'totalProcessed': len(processed_images),
            'totalErrors': len(errors)
        })
        
    except Exception as e:
        logger.error(f"Error processing images: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/images/<filename>')
def serve_image(filename):
    """Serve processed images"""
    try:
        return send_from_directory(IMAGES_DIR, filename)
    except Exception as e:
        logger.error(f"Error serving image {filename}: {e}")
        return jsonify({'error': 'Image not found'}), 404

@app.route('/api/health')
def health_check():
    """Health check endpoint for Render"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'imagesCount': len(os.listdir(IMAGES_DIR)) if os.path.exists(IMAGES_DIR) else 0,
        'server': 'image-processing-server'
    })

@app.route('/api/stats')
def get_stats():
    """Get server statistics"""
    try:
        image_files = os.listdir(IMAGES_DIR) if os.path.exists(IMAGES_DIR) else []
        total_size = sum(os.path.getsize(os.path.join(IMAGES_DIR, f)) for f in image_files)
        
        return jsonify({
            'totalImages': len(image_files),
            'totalSizeBytes': total_size,
            'totalSizeMB': round(total_size / (1024 * 1024), 2),
            'serverTime': datetime.now().isoformat()
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    print("🚀 Image Processing Server Starting...")
    print(f"📁 Images directory: {os.path.abspath(IMAGES_DIR)}")
    print("🌐 Server will be available at: http://localhost:5000")
    print("📋 API Endpoints:")
    print("  GET  / - Home page")
    print("  POST /api/process-images - Process image URLs")
    print("  GET  /api/images/<filename> - Serve processed images")
    print("  GET  /api/health - Health check")
    print("  GET  /api/stats - Server statistics")
    print("\nPress Ctrl+C to stop the server")
    
    app.run(host='0.0.0.0', port=5000, debug=True) 