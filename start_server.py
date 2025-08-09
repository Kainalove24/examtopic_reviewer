#!/usr/bin/env python3
"""
Start the scraper API server
"""

from scraper_api_server import app

if __name__ == "__main__":
    print("Starting Scraper API Server...")
    print("Server will be available at: http://localhost:5000")
    print("Press Ctrl+C to stop the server")
    print()
    app.run(host='0.0.0.0', port=5000, debug=True) 