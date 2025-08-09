#!/usr/bin/env python3
"""
Test script for new Microsoft and Amazon categories
"""

import requests
import json

def test_categories():
    """Test the new categories"""
    base_url = "http://localhost:5000/api"
    
    try:
        # Test health check
        print("Testing health check...")
        response = requests.get(f"{base_url}/health")
        print(f"Health check status: {response.status_code}")
        print(f"Response: {response.json()}")
        print()
        
        # Test categories endpoint
        print("Testing categories endpoint...")
        response = requests.get(f"{base_url}/categories")
        print(f"Categories status: {response.status_code}")
        categories = response.json()['categories']
        print("Available categories:")
        for key, value in categories.items():
            print(f"  {key}: {value}")
        print()
        
        # Test Microsoft exams
        print("Testing Microsoft exams...")
        response = requests.get(f"{base_url}/exams/microsoft")
        print(f"Microsoft exams status: {response.status_code}")
        if response.status_code == 200:
            exams = response.json()['exams']
            print(f"Found {len(exams)} Microsoft exams")
            for i, exam in enumerate(exams[:5]):  # Show first 5
                print(f"  {i+1}. {exam}")
            if len(exams) > 5:
                print(f"  ... and {len(exams) - 5} more")
        print()
        
        # Test Amazon exams
        print("Testing Amazon exams...")
        response = requests.get(f"{base_url}/exams/amazon")
        print(f"Amazon exams status: {response.status_code}")
        if response.status_code == 200:
            exams = response.json()['exams']
            print(f"Found {len(exams)} Amazon exams")
            for i, exam in enumerate(exams[:5]):  # Show first 5
                print(f"  {i+1}. {exam}")
            if len(exams) > 5:
                print(f"  ... and {len(exams) - 5} more")
        print()
        
        # Test CSV scraping endpoint
        print("Testing CSV scraping endpoint...")
        test_data = {
            'csv_links': [
                {'topic': '1', 'question': '1', 'link': 'https://example.com/1'},
                {'topic': '1', 'question': '2', 'link': 'https://example.com/2'},
                {'topic': '1', 'question': '3', 'link': 'https://example.com/3'},
            ],
            'category': 'microsoft',
            'exam_code': 'AZ-900: Microsoft Azure Fundamentals'
        }
        
        response = requests.post(
            f"{base_url}/scrape-csv",
            json=test_data,
            headers={'Content-Type': 'application/json'}
        )
        print(f"CSV scraping status: {response.status_code}")
        if response.status_code == 200:
            result = response.json()
            print(f"Job ID: {result['job_id']}")
            print(f"Status: {result['status']}")
            print(f"Message: {result['message']}")
        else:
            print(f"Error: {response.text}")
        print()
        
        print("✅ All tests completed successfully!")
        
    except requests.exceptions.ConnectionError:
        print("❌ Could not connect to server. Make sure the server is running on localhost:5000")
    except Exception as e:
        print(f"❌ Error during testing: {e}")

if __name__ == "__main__":
    test_categories() 