#!/usr/bin/env python3
"""
Scraper API Server
A Flask API server that provides endpoints for the admin portal to interact with the scraper
"""

import os
import json
import time
import threading
from datetime import datetime
from flask import Flask, request, jsonify
from flask_cors import CORS
import logging

# Import the scraper (commented out to avoid dependency issues)
# from scrapers.advanced_examtopics_scraper import AdvancedExamTopicsScraper

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# In-memory storage for jobs (in production, use a proper database)
jobs = {}
job_counter = 0

# Available categories and exams (you can expand this)
CATEGORIES = {
    'microsoft': 'Microsoft Certifications',
    'amazon': 'Amazon AWS Certifications',
    'aws': 'AWS Certifications',
    'azure': 'Microsoft Azure',
    'gcp': 'Google Cloud Platform',
    'cisco': 'Cisco Certifications',
    'comptia': 'CompTIA Certifications',
}

EXAMS = {
    'microsoft': [
        'AZ-900: Microsoft Azure Fundamentals',
        'AZ-104: Microsoft Azure Administrator',
        'AZ-204: Developing Solutions for Microsoft Azure',
        'AZ-305: Designing Microsoft Azure Infrastructure Solutions',
        'AZ-400: Microsoft Azure DevOps Solutions',
        'AZ-500: Microsoft Azure Security Technologies',
        'AZ-600: Configuring and Operating a Hybrid Cloud with Microsoft Azure Stack Hub',
        'AZ-700: Designing and Implementing Microsoft Azure Networking Solutions',
        'AZ-720: Troubleshooting Microsoft Azure Connectivity',
        'AZ-800: Administering Windows Server Hybrid Core Infrastructure',
        'AZ-801: Configuring Windows Server Hybrid Advanced Services',
        'AZ-900: Microsoft Azure Fundamentals',
        'AI-100: Designing and Implementing an Azure AI Solution',
        'AI-102: Designing and Implementing a Microsoft Azure AI Solution',
        'AI-900: Microsoft Azure AI Fundamentals',
        'DA-100: Analyzing Data with Microsoft Power BI',
        'DP-100: Designing and Implementing a Data Science Solution on Azure',
        'DP-200: Implementing an Azure Data Solution',
        'DP-201: Designing an Azure Data Solution',
        'DP-203: Data Engineering on Microsoft Azure',
        'DP-300: Administering Relational Databases on Microsoft Azure',
        'DP-420: Designing and Implementing Cloud-Native Applications Using Microsoft Azure Cosmos DB',
        'DP-500: Designing and Implementing Real-Time Analytics Solutions Using Microsoft Azure Synapse Analytics',
        'DP-600: Designing and Implementing Data Solutions Using Microsoft Azure Data Services',
        'DP-900: Microsoft Azure Data Fundamentals',
        'MB-210: Microsoft Dynamics 365 Sales',
        'MB-220: Microsoft Dynamics 365 Marketing',
        'MB-230: Microsoft Dynamics 365 Customer Service',
        'MB-240: Microsoft Dynamics 365 Field Service',
        'MB-300: Microsoft Dynamics 365: Core Finance and Operations',
        'MB-310: Microsoft Dynamics 365 Finance',
        'MB-320: Microsoft Dynamics 365 Supply Chain Management',
        'MB-330: Microsoft Dynamics 365 Customer Engagement',
        'MB-500: Microsoft Dynamics 365: Finance and Operations Apps Developer',
        'MB-600: Microsoft Dynamics 365 + Power Platform Solution Architect',
        'MB-700: Microsoft Dynamics 365: Finance and Operations Apps Solution Architect',
        'MB-800: Microsoft Dynamics 365 Business Central Functional Consultant',
        'MB-900: Microsoft Dynamics 365 Fundamentals',
        'MD-100: Windows 10',
        'MD-101: Managing Modern Desktops',
        'MS-100: Microsoft 365 Identity and Services',
        'MS-101: Microsoft 365 Mobility and Security',
        'MS-102: Microsoft 365 Administrator',
        'MS-200: Planning and Configuring a Messaging Platform',
        'MS-201: Implementing a Hybrid and Secure Messaging Platform',
        'MS-202: Microsoft 365 Messaging Administrator Certification Transition',
        'MS-203: Microsoft 365 Messaging',
        'MS-220: Troubleshooting Microsoft Exchange Online',
        'MS-300: Deploying Microsoft 365 Teamwork',
        'MS-301: Deploying SharePoint Server Hybrid',
        'MS-302: Microsoft 365 Teamwork Administrator Certification Transition',
        'MS-500: Microsoft 365 Security Administration',
        'MS-600: Building Applications and Solutions with Microsoft 365 Core Services',
        'MS-700: Managing Microsoft Teams',
        'MS-720: Microsoft Teams Voice Engineer',
        'MS-721: Collaboration Communications Systems Engineer',
        'MS-740: Troubleshooting Microsoft Teams',
        'MS-900: Microsoft 365 Fundamentals',
        'PL-100: Microsoft Power Platform App Maker',
        'PL-200: Microsoft Power Platform Functional Consultant',
        'PL-300: Microsoft Power BI Data Analyst',
        'PL-400: Microsoft Power Platform Developer',
        'PL-500: Microsoft Power Automate RPA Developer',
        'PL-600: Microsoft Power Platform Solution Architect',
        'PL-900: Microsoft Power Platform Fundamentals',
        'SC-100: Microsoft Cybersecurity Architect',
        'SC-200: Microsoft Security Operations Analyst',
        'SC-300: Microsoft Identity and Access Administrator',
        'SC-400: Microsoft Information Protection Administrator',
        'SC-401: Administering Information Security in Microsoft 365',
        'SC-900: Microsoft Security, Compliance, and Identity Fundamentals',
    ],
    'amazon': [
        'AWS Certified Solutions Architect Associate (SAA-C03)',
        'AWS Certified Solutions Architect Professional (SAP-C02)',
        'AWS Certified Developer Associate (DVA-C02)',
        'AWS Certified SysOps Administrator Associate (SOA-C02)',
        'AWS Certified Cloud Practitioner (CLF-C02)',
        'AWS Certified DevOps Engineer Professional (DOP-C02)',
        'AWS Certified Security Specialty (SCS-C02)',
        'AWS Certified Advanced Networking Specialty (ANS-C01)',
        'AWS Certified Database Specialty (DBS-C01)',
        'AWS Certified Data Analytics Specialty (DAS-C01)',
        'AWS Certified Machine Learning Specialty (MLS-C01)',
        'AWS Certified Alexa Skill Builder Specialty (AXS-C01)',
        'AWS Certified SAP on AWS Specialty (SAP-C01)',
        'AWS Certified Well-Architected Specialty (WAS-C01)',
        'AWS Certified GameLift Specialty (GLS-C01)',
        'AWS Certified FinOps Practitioner',
        'AWS Certified Cloud Financial Management',
    ],
    'aws': [
        'AWS Certified Solutions Architect Associate (SAA-C03)',
        'AWS Certified Developer Associate (DVA-C02)',
        'AWS Certified SysOps Administrator Associate (SOA-C02)',
        'AWS Certified Cloud Practitioner (CLF-C02)',
    ],
    'azure': [
        'AZ-900: Microsoft Azure Fundamentals',
        'AZ-104: Microsoft Azure Administrator',
        'AZ-204: Developing Solutions for Microsoft Azure',
        'AZ-305: Designing Microsoft Azure Infrastructure Solutions',
    ],
    'gcp': [
        'Google Cloud Professional Cloud Architect',
        'Google Cloud Professional Data Engineer',
        'Google Cloud Professional Cloud Developer',
        'Google Cloud Associate Cloud Engineer',
    ],
    'cisco': [
        'CCNA: Cisco Certified Network Associate',
        'CCNP: Cisco Certified Network Professional',
        'CCIE: Cisco Certified Internetwork Expert',
    ],
    'comptia': [
        'CompTIA A+',
        'CompTIA Network+',
        'CompTIA Security+',
        'CompTIA Cloud+',
    ],
}

@app.route('/api/health')
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'server': 'scraper-api-server',
        'active_jobs': len([j for j in jobs.values() if j['status'] == 'running'])
    })

@app.route('/api/categories')
def get_categories():
    """Get available categories"""
    return jsonify({
        'categories': CATEGORIES
    })

@app.route('/api/exams/<category>')
def get_exams_for_category(category):
    """Get exams for a specific category"""
    if category in EXAMS:
        return jsonify({
            'exams': EXAMS[category]
        })
    return jsonify({'exams': []})

@app.route('/api/scrape', methods=['POST'])
def start_scraping():
    """Start a scraping job"""
    global job_counter
    
    try:
        data = request.get_json()
        category = data.get('category')
        exam_code = data.get('exam_code')
        
        if not category or not exam_code:
            return jsonify({'error': 'Missing category or exam_code'}), 400
        
        # Generate job ID
        job_counter += 1
        job_id = f"job_{job_counter}_{int(time.time())}"
        
        # Create job entry
        jobs[job_id] = {
            'job_id': job_id,
            'category': category,
            'exam_code': exam_code,
            'status': 'running',
            'progress': 0,
            'start_time': datetime.now().isoformat(),
            'end_time': None,
            'result': None,
            'error': None
        }
        
        # Start scraping in background thread
        thread = threading.Thread(
            target=run_scraping_job,
            args=(job_id, category, exam_code)
        )
        thread.daemon = True
        thread.start()
        
        return jsonify({
            'job_id': job_id,
            'status': 'started',
            'message': f'Started scraping {exam_code}'
        })
        
    except Exception as e:
        logger.error(f"Error starting scraping job: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/scrape-csv', methods=['POST'])
def start_scraping_with_csv():
    """Start a scraping job with CSV data"""
    global job_counter
    
    try:
        data = request.get_json()
        csv_links = data.get('csv_links', [])
        category = data.get('category')
        exam_code = data.get('exam_code')
        
        if not csv_links or not category or not exam_code:
            return jsonify({'error': 'Missing csv_links, category, or exam_code'}), 400
        
        # Generate job ID
        job_counter += 1
        job_id = f"csv_job_{job_counter}_{int(time.time())}"
        
        # Create job entry
        jobs[job_id] = {
            'job_id': job_id,
            'category': category,
            'exam_code': exam_code,
            'csv_links': csv_links,
            'status': 'running',
            'progress': 0,
            'start_time': datetime.now().isoformat(),
            'end_time': None,
            'result': None,
            'error': None
        }
        
        # Start scraping in background thread
        thread = threading.Thread(
            target=run_csv_scraping_job,
            args=(job_id, category, exam_code, csv_links)
        )
        thread.daemon = True
        thread.start()
        
        return jsonify({
            'job_id': job_id,
            'status': 'started',
            'message': f'Started scraping {len(csv_links)} links for {exam_code}'
        })
        
    except Exception as e:
        logger.error(f"Error starting CSV scraping job: {e}")
        return jsonify({'error': str(e)}), 500

def run_scraping_job(job_id, category, exam_code):
    """Run the scraping job in background"""
    try:
        job = jobs[job_id]
        
        # Simulate scraping process
        logger.info(f"Starting scraping job {job_id} for {exam_code}")
        
        # Update progress
        for i in range(1, 11):
            time.sleep(2)  # Simulate work
            job['progress'] = i * 10
            logger.info(f"Job {job_id} progress: {job['progress']}%")
        
        # Generate mock CSV content
        csv_content = generate_mock_csv_content(exam_code)
        
        # Update job status
        job['status'] = 'completed'
        job['progress'] = 100
        job['end_time'] = datetime.now().isoformat()
        job['result'] = {
            'csv_content': csv_content,
            'questions_count': 50,  # Mock count
            'format': 'CSV'
        }
        
        logger.info(f"Job {job_id} completed successfully")
        
    except Exception as e:
        logger.error(f"Error in scraping job {job_id}: {e}")
        job = jobs.get(job_id)
        if job:
            job['status'] = 'failed'
            job['error'] = str(e)
            job['end_time'] = datetime.now().isoformat()

def run_csv_scraping_job(job_id, category, exam_code, csv_links):
    """Run the CSV scraping job in background"""
    try:
        job = jobs[job_id]
        total_links = len(csv_links)
        
        logger.info(f"Starting CSV scraping job {job_id} for {exam_code} with {total_links} links")
        
        # Simulate scraping process for each link
        scraped_data = []
        for i, link_data in enumerate(csv_links):
            time.sleep(0.5)  # Simulate work per link
            
            # Generate mock question data based on the link
            question_data = {
                'id': i + 1,
                'type': 'multiple_choice',
                'question_text': f"Sample question {i + 1} for {exam_code}",
                'options': [
                    f"Option A for question {i + 1}",
                    f"Option B for question {i + 1}",
                    f"Option C for question {i + 1}",
                    f"Option D for question {i + 1}"
                ],
                'correct_answer': f"Option A for question {i + 1}",
                'explanation': f"This is the explanation for question {i + 1}",
                'images': [],
                'tags': [category, exam_code],
                'topic': link_data.get('topic', ''),
                'question_number': link_data.get('question', ''),
                'url': link_data.get('link', '')
            }
            scraped_data.append(question_data)
            
            # Update progress
            job['progress'] = int(((i + 1) / total_links) * 100)
            logger.info(f"Job {job_id} progress: {job['progress']}% ({i + 1}/{total_links})")
            
        # Store results
        job['result'] = {
            'data': scraped_data,
            'total_questions': len(scraped_data),
            'category': category,
            'exam_code': exam_code
        }
        job['status'] = 'completed'
        job['progress'] = 100
        job['end_time'] = datetime.now().isoformat()
        
        logger.info(f"CSV Job {job_id} completed successfully with {len(scraped_data)} questions")
        
    except Exception as e:
        logger.error(f"Error in CSV scraping job {job_id}: {e}")
        job = jobs.get(job_id)
        if job:
            job['status'] = 'failed'
            job['error'] = str(e)
            job['end_time'] = datetime.now().isoformat()

def generate_mock_csv_content(exam_code):
    """Generate mock CSV content for testing"""
    csv_lines = [
        "id,type,text,question_images,answer_images,options,answers,explanation",
        "1,mcq,What is AWS S3?,https://example.com/image1.png,,A. Simple Storage Service;B. Simple Server Service;C. Storage Server System;D. Server Storage Service,A,Amazon S3 (Simple Storage Service) is an object storage service that offers industry-leading scalability, data availability, security, and performance.",
        "2,mcq,Which AWS service is used for compute?,https://example.com/image2.png,,A. S3;B. EC2;C. RDS;D. Lambda,B,Amazon EC2 (Elastic Compute Cloud) provides scalable computing capacity in the AWS Cloud.",
        "3,mcq,What is the primary benefit of auto-scaling?,https://example.com/image3.png,,A. Cost reduction;B. Automatic scaling;C. High availability;D. All of the above,D,Auto-scaling provides cost reduction, automatic scaling, and high availability.",
        "4,mcq,Which AWS service is serverless?,https://example.com/image4.png,,A. EC2;B. Lambda;C. RDS;D. S3,B,AWS Lambda is a serverless compute service that runs code in response to events.",
        "5,mcq,What is the purpose of AWS CloudFormation?,https://example.com/image5.png,,A. Infrastructure as Code;B. Code deployment;C. Monitoring;D. Security,A,AWS CloudFormation allows you to model and set up your AWS resources using Infrastructure as Code."
    ]
    return "\n".join(csv_lines)

@app.route('/api/job/<job_id>')
def get_job_status(job_id):
    """Get status of a specific job"""
    if job_id not in jobs:
        return jsonify({'error': 'Job not found'}), 404
    
    job = jobs[job_id]
    return jsonify(job)

@app.route('/api/jobs')
def list_jobs():
    """List all jobs"""
    return jsonify({
        'jobs': list(jobs.values())
    })

@app.route('/api/download/<job_id>')
def download_results(job_id):
    """Download results for completed job"""
    if job_id not in jobs:
        return jsonify({'error': 'Job not found'}), 404
    
    job = jobs[job_id]
    if job['status'] != 'completed':
        return jsonify({'error': 'Job not completed'}), 400
    
    # Check if it's a CSV job or regular job
    if 'csv_links' in job:
        # CSV scraping job - return JSON data
        return jsonify(job['result'])
    else:
        # Regular job - return CSV content
        csv_content = job['result']['csv_content']
        return csv_content, 200, {'Content-Type': 'text/csv'}

@app.route('/api/cleanup/<job_id>', methods=['DELETE'])
def cleanup_job(job_id):
    """Clean up a job"""
    if job_id in jobs:
        del jobs[job_id]
        return jsonify({'message': 'Job cleaned up successfully'})
    return jsonify({'error': 'Job not found'}), 404

@app.route('/')
def home():
    """Home endpoint"""
    return jsonify({
        'message': 'Scraper API Server is running! 🚀',
        'endpoints': {
            'health': 'GET /api/health',
            'categories': 'GET /api/categories',
            'exams': 'GET /api/exams/<category>',
            'scrape': 'POST /api/scrape',
            'job_status': 'GET /api/job/<job_id>',
            'jobs': 'GET /api/jobs',
            'download': 'GET /api/download/<job_id>',
            'cleanup': 'DELETE /api/cleanup/<job_id>'
        },
        'timestamp': datetime.now().isoformat()
    })

if __name__ == '__main__':
    print("🚀 Scraper API Server Starting...")
    print("🌐 Server will be available at: http://localhost:5000")
    print("📋 API Endpoints:")
    print("  GET  / - Home page")
    print("  GET  /api/health - Health check")
    print("  GET  /api/categories - Get categories")
    print("  GET  /api/exams/<category> - Get exams for category")
    print("  POST /api/scrape - Start scraping job")
    print("  GET  /api/job/<job_id> - Get job status")
    print("  GET  /api/jobs - List all jobs")
    print("  GET  /api/download/<job_id> - Download CSV")
    print("  DELETE /api/cleanup/<job_id> - Cleanup job")
    print("\nPress Ctrl+C to stop the server")
    
    app.run(host='0.0.0.0', port=5000, debug=True) 