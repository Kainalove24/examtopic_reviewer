#!/usr/bin/env python3
"""
ExamTopics Scraper
A Python script to scrape exam questions and data from ExamTopics.com links
"""

import csv
import json
import time
import requests
from bs4 import BeautifulSoup
from urllib.parse import urljoin, urlparse
import os
import sys
from typing import Dict, List, Optional, Any
import logging
from dataclasses import dataclass
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('scraper.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

@dataclass
class ExamQuestion:
    """Data class to store exam question information"""
    topic: str
    question_number: str
    url: str
    question_text: str = ""
    options: List[str] = None
    correct_answer: str = ""
    explanation: str = ""
    images: List[str] = None
    difficulty: str = ""
    tags: List[str] = None
    
    def __post_init__(self):
        if self.options is None:
            self.options = []
        if self.images is None:
            self.images = []
        if self.tags is None:
            self.tags = []

class ExamTopicsScraper:
    """Main scraper class for ExamTopics.com"""
    
    def __init__(self, delay: float = 1.0, max_retries: int = 3):
        self.delay = delay
        self.max_retries = max_retries
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.5',
            'Accept-Encoding': 'gzip, deflate',
            'Connection': 'keep-alive',
            'Upgrade-Insecure-Requests': '1',
        })
        
    def load_links_from_csv(self, csv_file: str) -> List[Dict[str, str]]:
        """Load links from CSV file"""
        links = []
        try:
            with open(csv_file, 'r', encoding='utf-8') as file:
                reader = csv.DictReader(file)
                for row in reader:
                    links.append({
                        'topic': row['Topic'],
                        'question': row['Question'],
                        'link': row['Link']
                    })
            logger.info(f"Loaded {len(links)} links from {csv_file}")
            return links
        except Exception as e:
            logger.error(f"Error loading CSV file: {e}")
            return []
    
    def get_page_content(self, url: str) -> Optional[BeautifulSoup]:
        """Get page content with retry logic"""
        for attempt in range(self.max_retries):
            try:
                logger.info(f"Fetching: {url} (attempt {attempt + 1})")
                response = self.session.get(url, timeout=30)
                response.raise_for_status()
                
                soup = BeautifulSoup(response.content, 'html.parser')
                time.sleep(self.delay)  # Be respectful to the server
                return soup
                
            except requests.RequestException as e:
                logger.warning(f"Attempt {attempt + 1} failed for {url}: {e}")
                if attempt < self.max_retries - 1:
                    time.sleep(self.delay * (attempt + 1))  # Exponential backoff
                else:
                    logger.error(f"Failed to fetch {url} after {self.max_retries} attempts")
                    return None
    
    def extract_question_text(self, soup: BeautifulSoup) -> str:
        """Extract question text from the page"""
        try:
            # Look for question text in various possible locations
            selectors = [
                '.question-text',
                '.question-content',
                '.discussion-content h1',
                '.discussion-content h2',
                '.discussion-content h3',
                '.discussion-content p',
                'h1',
                'h2',
                'h3'
            ]
            
            for selector in selectors:
                elements = soup.select(selector)
                for element in elements:
                    text = element.get_text(strip=True)
                    if text and len(text) > 20:  # Reasonable question length
                        return text
            
            # Fallback: get first paragraph with substantial content
            paragraphs = soup.find_all('p')
            for p in paragraphs:
                text = p.get_text(strip=True)
                if text and len(text) > 50:
                    return text
                    
            return "Question text not found"
            
        except Exception as e:
            logger.error(f"Error extracting question text: {e}")
            return "Error extracting question text"
    
    def extract_options(self, soup: BeautifulSoup) -> List[str]:
        """Extract answer options from the page"""
        options = []
        try:
            # Look for options in various formats
            option_selectors = [
                '.option',
                '.answer-option',
                '.choice',
                'li',
                'p'
            ]
            
            for selector in option_selectors:
                elements = soup.select(selector)
                for element in elements:
                    text = element.get_text(strip=True)
                    if text and text.startswith(('A.', 'B.', 'C.', 'D.', 'E.')):
                        options.append(text)
                        if len(options) >= 5:  # Usually max 5 options
                            break
                if options:
                    break
            
            return options
            
        except Exception as e:
            logger.error(f"Error extracting options: {e}")
            return []
    
    def extract_correct_answer(self, soup: BeautifulSoup) -> str:
        """Extract correct answer from the page"""
        try:
            # Look for correct answer indicators
            answer_selectors = [
                '.correct-answer',
                '.answer',
                '.solution',
                '.explanation'
            ]
            
            for selector in answer_selectors:
                elements = soup.select(selector)
                for element in elements:
                    text = element.get_text(strip=True)
                    if text and ('correct' in text.lower() or 'answer' in text.lower()):
                        return text
            
            return "Correct answer not found"
            
        except Exception as e:
            logger.error(f"Error extracting correct answer: {e}")
            return "Error extracting correct answer"
    
    def extract_explanation(self, soup: BeautifulSoup) -> str:
        """Extract explanation from the page"""
        try:
            # Look for explanation sections
            explanation_selectors = [
                '.explanation',
                '.solution',
                '.discussion',
                '.answer-explanation'
            ]
            
            for selector in explanation_selectors:
                elements = soup.select(selector)
                for element in elements:
                    text = element.get_text(strip=True)
                    if text and len(text) > 20:
                        return text
            
            return "Explanation not found"
            
        except Exception as e:
            logger.error(f"Error extracting explanation: {e}")
            return "Error extracting explanation"
    
    def extract_images(self, soup: BeautifulSoup, base_url: str) -> List[str]:
        """Extract image URLs from the page"""
        images = []
        try:
            img_elements = soup.find_all('img')
            for img in img_elements:
                src = img.get('src')
                if src:
                    # Convert relative URLs to absolute
                    if src.startswith('/'):
                        src = urljoin(base_url, src)
                    elif not src.startswith('http'):
                        src = urljoin(base_url, src)
                    images.append(src)
            
            return images
            
        except Exception as e:
            logger.error(f"Error extracting images: {e}")
            return []
    
    def scrape_question(self, link_data: Dict[str, str]) -> ExamQuestion:
        """Scrape a single question from the provided link"""
        url = link_data['link']
        topic = link_data['topic']
        question_number = link_data['question']
        
        logger.info(f"Scraping question {question_number} from topic {topic}")
        
        # Create question object
        question = ExamQuestion(
            topic=topic,
            question_number=question_number,
            url=url
        )
        
        # Get page content
        soup = self.get_page_content(url)
        if not soup:
            logger.error(f"Failed to get content for {url}")
            return question
        
        # Extract data
        question.question_text = self.extract_question_text(soup)
        question.options = self.extract_options(soup)
        question.correct_answer = self.extract_correct_answer(soup)
        question.explanation = self.extract_explanation(soup)
        question.images = self.extract_images(soup, url)
        
        logger.info(f"Successfully scraped question {question_number}")
        return question
    
    def scrape_all_questions(self, csv_file: str, output_file: str = None) -> List[ExamQuestion]:
        """Scrape all questions from the CSV file"""
        if output_file is None:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            output_file = f"scraped_questions_{timestamp}.json"
        
        # Load links
        links = self.load_links_from_csv(csv_file)
        if not links:
            logger.error("No links found in CSV file")
            return []
        
        questions = []
        total_links = len(links)
        
        logger.info(f"Starting to scrape {total_links} questions")
        
        for i, link_data in enumerate(links, 1):
            try:
                question = self.scrape_question(link_data)
                questions.append(question)
                
                logger.info(f"Progress: {i}/{total_links} ({i/total_links*100:.1f}%)")
                
                # Save progress periodically
                if i % 10 == 0:
                    self.save_questions(questions, f"progress_{output_file}")
                
            except Exception as e:
                logger.error(f"Error scraping question {link_data['question']}: {e}")
                continue
        
        # Save final results
        self.save_questions(questions, output_file)
        logger.info(f"Scraping completed. Saved {len(questions)} questions to {output_file}")
        
        return questions
    
    def save_questions(self, questions: List[ExamQuestion], filename: str):
        """Save questions to JSON file"""
        try:
            data = []
            for question in questions:
                data.append({
                    'topic': question.topic,
                    'question_number': question.question_number,
                    'url': question.url,
                    'question_text': question.question_text,
                    'options': question.options,
                    'correct_answer': question.correct_answer,
                    'explanation': question.explanation,
                    'images': question.images,
                    'difficulty': question.difficulty,
                    'tags': question.tags
                })
            
            with open(filename, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
            
            logger.info(f"Saved {len(questions)} questions to {filename}")
            
        except Exception as e:
            logger.error(f"Error saving questions: {e}")
    
    def export_to_csv(self, questions: List[ExamQuestion], filename: str):
        """Export questions to CSV format"""
        try:
            with open(filename, 'w', newline='', encoding='utf-8') as csvfile:
                fieldnames = [
                    'topic', 'question_number', 'url', 'question_text',
                    'options', 'correct_answer', 'explanation', 'images',
                    'difficulty', 'tags'
                ]
                writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
                writer.writeheader()
                
                for question in questions:
                    writer.writerow({
                        'topic': question.topic,
                        'question_number': question.question_number,
                        'url': question.url,
                        'question_text': question.question_text,
                        'options': '|'.join(question.options),
                        'correct_answer': question.correct_answer,
                        'explanation': question.explanation,
                        'images': '|'.join(question.images),
                        'difficulty': question.difficulty,
                        'tags': '|'.join(question.tags)
                    })
            
            logger.info(f"Exported {len(questions)} questions to {filename}")
            
        except Exception as e:
            logger.error(f"Error exporting to CSV: {e}")

def main():
    """Main function to run the scraper"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Scrape ExamTopics questions from CSV links')
    parser.add_argument('csv_file', help='Path to CSV file containing links')
    parser.add_argument('--output', '-o', help='Output JSON file name')
    parser.add_argument('--csv-output', help='Output CSV file name')
    parser.add_argument('--delay', type=float, default=1.0, help='Delay between requests (seconds)')
    parser.add_argument('--retries', type=int, default=3, help='Maximum retry attempts')
    
    args = parser.parse_args()
    
    # Check if CSV file exists
    if not os.path.exists(args.csv_file):
        logger.error(f"CSV file not found: {args.csv_file}")
        sys.exit(1)
    
    # Create scraper instance
    scraper = ExamTopicsScraper(delay=args.delay, max_retries=args.retries)
    
    try:
        # Scrape all questions
        questions = scraper.scrape_all_questions(args.csv_file, args.output)
        
        # Export to CSV if requested
        if args.csv_output:
            scraper.export_to_csv(questions, args.csv_output)
        
        logger.info(f"Scraping completed successfully. Total questions: {len(questions)}")
        
    except KeyboardInterrupt:
        logger.info("Scraping interrupted by user")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main() 