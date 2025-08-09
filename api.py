import os
import requests
import hashlib
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
from urllib.parse import urlparse, quote
import mimetypes
from datetime import datetime
import logging
# Import Cloudinary SDK (now properly installed)
try:
    import cloudinary
    import cloudinary.uploader
    import cloudinary.config
    import cloudinary.api
    import cloudinary.exceptions
    CLOUDINARY_AVAILABLE = True
    print("🔍 DEBUG: Cloudinary imports successful")
except ImportError as e:
    CLOUDINARY_AVAILABLE = False
    cloudinary = None
    print(f"🔍 DEBUG: Cloudinary import failed: {e}")
except Exception as e:
    CLOUDINARY_AVAILABLE = False
    cloudinary = None
    print(f"🔍 DEBUG: Unexpected error importing Cloudinary: {e}")

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Configuration
IMAGES_DIR = 'processed_images'
ALLOWED_EXTENSIONS = {'.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp'}
MAX_FILE_SIZE = 10 * 1024 * 1024  # 10MB limit

# Configure Cloudinary SDK
CLOUDINARY_ENABLED = False
if CLOUDINARY_AVAILABLE:
    try:
        cloudinary.config(
            cloud_name=os.environ.get('CLOUDINARY_CLOUD_NAME'),
            api_key=os.environ.get('CLOUDINARY_API_KEY'),
            api_secret=os.environ.get('CLOUDINARY_API_SECRET')
        )
        CLOUDINARY_ENABLED = all([
            os.environ.get('CLOUDINARY_CLOUD_NAME'),
            os.environ.get('CLOUDINARY_API_KEY'),
            os.environ.get('CLOUDINARY_API_SECRET')
        ])
        if CLOUDINARY_ENABLED:
            logger.info("✅ Cloudinary configuration loaded successfully")
            print("🔍 DEBUG: All environment variables found and configured")
        else:
            logger.warning("⚠️ Cloudinary environment variables not found, using local storage")
            print(f"🔍 DEBUG: Missing env vars - CLOUD_NAME: {bool(os.environ.get('CLOUDINARY_CLOUD_NAME'))}, API_KEY: {bool(os.environ.get('CLOUDINARY_API_KEY'))}, API_SECRET: {bool(os.environ.get('CLOUDINARY_API_SECRET'))}")
    except Exception as e:
        logger.error(f"❌ Failed to configure Cloudinary: {e}")
        CLOUDINARY_ENABLED = False
else:
    logger.warning("⚠️ Cloudinary library not available, using local storage only")

# Create images directory if it doesn't exist (fallback)
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

def upload_to_cloudinary(image_data, public_id):
    """Upload image to Cloudinary with fallback to local storage"""
    if not CLOUDINARY_ENABLED:
        logger.debug("Cloudinary not enabled, skipping upload")
        return None
    
    try:
        logger.info(f"🌩️ Uploading image to Cloudinary: {public_id}")
        
        # Upload to Cloudinary
        result = cloudinary.uploader.upload(
            image_data,
            public_id=public_id,
            folder="examtopic_images",  # Organize images in a folder
            resource_type="image",
            overwrite=True,  # Replace if exists
            transformation=[
                {'quality': 'auto:good'},  # Optimize quality
                {'fetch_format': 'auto'}   # Auto format (WebP when supported)
            ]
        )
        
        cloudinary_url = result.get('secure_url')
        if cloudinary_url:
            logger.info(f"✅ Successfully uploaded to Cloudinary: {cloudinary_url}")
            return cloudinary_url
        else:
            logger.error("❌ Cloudinary upload failed: No URL returned")
            return None
            
    except Exception as e:
        logger.error(f"❌ Cloudinary upload failed: {e}")
        return None

def save_image_with_cloudinary_fallback(url, image_data):
    """Save image to Cloudinary with local fallback"""
    filename = generate_filename(url)
    public_id = filename.split('.')[0]  # Remove extension for Cloudinary
    
    # Try Cloudinary first
    cloudinary_url = upload_to_cloudinary(image_data, public_id)
    if cloudinary_url:
        return cloudinary_url
    
    # Fallback to local storage
    logger.info(f"📁 Falling back to local storage for: {filename}")
    filepath = os.path.join(IMAGES_DIR, filename)
    
    try:
        with open(filepath, 'wb') as f:
            f.write(image_data)
        return f"/api/images/{filename}"
    except Exception as e:
        logger.error(f"❌ Failed to save locally: {e}")
        raise

@app.route('/')
def home():
    """Home endpoint"""
    return jsonify({
        'message': 'Image Processing Server with Cloudinary Integration! 🚀☁️',
        'features': {
            'cloudinary_storage': CLOUDINARY_ENABLED,
            'local_fallback': True,
            'auto_optimization': CLOUDINARY_ENABLED,
            'persistent_storage': CLOUDINARY_ENABLED
        },
        'endpoints': {
            'process_images': 'POST /api/process-images - Process image URLs',
            'upload_image': 'POST /api/upload-image - Direct file upload',
            'serve_image': 'GET /api/images/<filename> - Serve local images',
            'health_check': 'GET /api/health - Health status',
            'stats': 'GET /api/stats - Server statistics'
        },
        'storage': {
            'primary': 'Cloudinary' if CLOUDINARY_ENABLED else 'Local',
            'fallback': 'Local filesystem'
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
                # Skip if URL is already from our own server or Cloudinary (prevents circular reference)
                if any(domain in url for domain in ['image-processing-server', 'onrender.com', 'cloudinary.com']):
                    logger.warning(f"Skipping already processed URL to prevent circular reference: {url}")
                    processed_images.append(url)  # Return the URL as-is
                    continue
                
                # Generate filename for local fallback check
                filename = generate_filename(url)
                filepath = os.path.join(IMAGES_DIR, filename)
                public_id = filename.split('.')[0]  # For Cloudinary
                
                # Check if we already have this image in Cloudinary or locally
                if CLOUDINARY_ENABLED:
                    try:
                        # Check if image exists in Cloudinary
                        existing_resource = cloudinary.api.resource(f"examtopic_images/{public_id}")
                        if existing_resource and existing_resource.get('secure_url'):
                            logger.info(f"Image already exists in Cloudinary: {public_id}")
                            processed_images.append(existing_resource['secure_url'])
                            continue
                    except cloudinary.exceptions.NotFound:
                        # Image doesn't exist in Cloudinary, continue with processing
                        pass
                    except Exception as e:
                        logger.debug(f"Could not check Cloudinary for existing image: {e}")
                
                # Check local fallback if Cloudinary check failed
                if os.path.exists(filepath):
                    logger.info(f"Image already exists locally: {filename}")
                    processed_images.append(f"/api/images/{filename}")
                    continue
                
                # Download image
                logger.info(f"📥 Downloading image: {url}")
                image_data = download_image(url)
                
                # Save image (Cloudinary with local fallback)
                saved_url = save_image_with_cloudinary_fallback(url, image_data)
                
                logger.info(f"✅ Successfully processed: {saved_url}")
                processed_images.append(saved_url)
                
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
    local_images_count = len(os.listdir(IMAGES_DIR)) if os.path.exists(IMAGES_DIR) else 0
    
    # Check Cloudinary status
    cloudinary_status = "disabled"
    if CLOUDINARY_ENABLED:
        try:
            # Test Cloudinary connection
            cloudinary.api.ping()
            cloudinary_status = "connected"
        except Exception as e:
            cloudinary_status = f"error: {str(e)}"
    
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'imagesCount': local_images_count,
        'cloudinary': {
            'enabled': CLOUDINARY_ENABLED,
            'status': cloudinary_status
        },
        'server': 'image-processing-server-with-cloudinary'
    })

@app.route('/api/stats')
def get_stats():
    """Get server statistics"""
    try:
        # Local storage stats
        image_files = os.listdir(IMAGES_DIR) if os.path.exists(IMAGES_DIR) else []
        total_size = sum(os.path.getsize(os.path.join(IMAGES_DIR, f)) for f in image_files)
        
        stats = {
            'localStorage': {
                'totalImages': len(image_files),
                'totalSizeBytes': total_size,
                'totalSizeMB': round(total_size / (1024 * 1024), 2)
            },
            'cloudinary': {
                'enabled': CLOUDINARY_ENABLED,
                'status': 'disabled'
            },
            'serverTime': datetime.now().isoformat()
        }
        
        # Cloudinary stats if enabled
        if CLOUDINARY_ENABLED:
            try:
                # Get basic Cloudinary info
                usage = cloudinary.api.usage()
                stats['cloudinary'].update({
                    'status': 'connected',
                    'totalImages': usage.get('resources', 0),
                    'bandwidthUsed': usage.get('bandwidth', 0),
                    'storageUsed': usage.get('storage', 0)
                })
            except Exception as e:
                stats['cloudinary']['status'] = f'error: {str(e)}'
        
        return jsonify(stats)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/upload-image', methods=['POST'])
def upload_image():
    """Direct file upload endpoint"""
    try:
        if 'file' not in request.files:
            return jsonify({'error': 'No file provided'}), 400
        
        file = request.files['file']
        if file.filename == '':
            return jsonify({'error': 'No file selected'}), 400
        
        # Check file extension
        ext = os.path.splitext(file.filename)[1].lower()
        if ext not in ALLOWED_EXTENSIONS:
            return jsonify({'error': f'Invalid file type. Allowed: {list(ALLOWED_EXTENSIONS)}'}), 400
        
        # Read file data
        file_data = file.read()
        if len(file_data) > MAX_FILE_SIZE:
            return jsonify({'error': f'File too large. Max size: {MAX_FILE_SIZE} bytes'}), 400
        
        # Generate unique filename
        file_hash = hashlib.md5(file_data).hexdigest()[:8]
        public_id = f"upload_{file_hash}"
        
        # Save with Cloudinary (with local fallback)
        if CLOUDINARY_ENABLED:
            cloudinary_url = upload_to_cloudinary(file_data, public_id)
            if cloudinary_url:
                return jsonify({
                    'success': True,
                    'url': cloudinary_url,
                    'storage': 'cloudinary'
                })
        
        # Local fallback
        filename = f"{public_id}{ext}"
        filepath = os.path.join(IMAGES_DIR, filename)
        
        with open(filepath, 'wb') as f:
            f.write(file_data)
        
        return jsonify({
            'success': True,
            'url': f"/api/images/{filename}",
            'storage': 'local'
        })
        
    except Exception as e:
        logger.error(f"Upload error: {e}")
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