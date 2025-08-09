#!/usr/bin/env python3
"""
Advanced ExamTopics Scraper
A specialized Python script to scrape exam questions from ExamTopics.com
with enhanced parsing for the specific site structure
"""

import csv
import json
import time
import requests
from bs4 import BeautifulSoup
from urllib.parse import urljoin, urlparse
import os
import sys
from typing import Dict, List, Optional, Any, Tuple
import logging
from dataclasses import dataclass, asdict
from datetime import datetime
import re

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('advanced_scraper.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

@dataclass
class ExamQuestion:
    """Enhanced data class to store exam question information"""
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
    discussion_comments: List[Dict] = None
    vote_count: int = 0
    is_premium: bool = False
    
    def __post_init__(self):
        if self.options is None:
            self.options = []
        if self.images is None:
            self.images = []
        if self.tags is None:
            self.tags = []
        if self.discussion_comments is None:
            self.discussion_comments = []

class AdvancedExamTopicsScraper:
    """Advanced scraper class specifically for ExamTopics.com"""
    
    def __init__(self, delay: float = 2.0, max_retries: int = 3):
        self.delay = delay
        self.max_retries = max_retries
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.9',
            'Accept-Encoding': 'gzip, deflate, br',
            'Connection': 'keep-alive',
            'Upgrade-Insecure-Requests': '1',
            'Sec-Fetch-Dest': 'document',
            'Sec-Fetch-Mode': 'navigate',
            'Sec-Fetch-Site': 'none',
            'Cache-Control': 'max-age=0',
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
        """Get page content with enhanced retry logic"""
        for attempt in range(self.max_retries):
            try:
                logger.info(f"Fetching: {url} (attempt {attempt + 1})")
                response = self.session.get(url, timeout=30)
                response.raise_for_status()
                
                # Check if we got a valid HTML response
                if 'text/html' not in response.headers.get('content-type', ''):
                    logger.warning(f"Non-HTML response from {url}")
                    return None
                
                soup = BeautifulSoup(response.content, 'html.parser')
                
                # Check if we got a valid page (not error page)
                if soup.find('title') and 'error' in soup.find('title').get_text().lower():
                    logger.warning(f"Error page received from {url}")
                    return None
                
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
        """Extract question text with ExamTopics-specific selectors"""
        try:
            # ExamTopics specific selectors
            selectors = [
                '.discussion-content h1',
                '.discussion-content h2',
                '.discussion-content h3',
                '.discussion-content .question-text',
                '.discussion-content .question-content',
                '.discussion-content p:first-of-type',
                'h1',
                'h2',
                'h3',
                '.discussion-content p'
            ]
            
            for selector in selectors:
                elements = soup.select(selector)
                for element in elements:
                    text = element.get_text(strip=True)
                    # Filter out navigation and other non-question text
                    if (text and len(text) > 30 and 
                        not any(keyword in text.lower() for keyword in ['home', 'login', 'register', 'search', 'menu'])):
                        return text
            
            # Fallback: get the first substantial paragraph
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
        """Extract answer options with ExamTopics-specific parsing"""
        options = []
        try:
            # Look for options in various formats
            option_patterns = [
                r'^[A-E]\.\s*',  # A. B. C. D. E.
                r'^[A-E]\)\s*',  # A) B) C) D) E)
                r'^[A-E]\s*',    # A B C D E
            ]
            
            # Find all text elements that might contain options
            text_elements = soup.find_all(['p', 'li', 'div'])
            
            for element in text_elements:
                text = element.get_text(strip=True)
                if not text:
                    continue
                
                # Check if this looks like an option
                for pattern in option_patterns:
                    if re.match(pattern, text, re.IGNORECASE):
                        # Clean up the option text
                        clean_text = re.sub(pattern, '', text, flags=re.IGNORECASE).strip()
                        if clean_text and len(clean_text) > 5:
                            options.append(text)
                            break
                
                # Stop if we have enough options
                if len(options) >= 5:
                    break
            
            return options
            
        except Exception as e:
            logger.error(f"Error extracting options: {e}")
            return []
    
    def extract_correct_answer(self, soup: BeautifulSoup) -> str:
        """Extract correct answer with ExamTopics-specific logic"""
        try:
            # Look for correct answer indicators
            answer_indicators = [
                'correct answer',
                'correct option',
                'right answer',
                'answer is',
                'correct choice',
                'correct:',
                'answer:'
            ]
            
            # Search in various elements
            search_elements = soup.find_all(['p', 'div', 'span', 'strong', 'b'])
            
            for element in search_elements:
                text = element.get_text(strip=True).lower()
                for indicator in answer_indicators:
                    if indicator in text:
                        # Extract the answer from the text
                        full_text = element.get_text(strip=True)
                        return full_text
            
            # Look for specific answer elements
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
                    if text and len(text) > 5:
                        return text
            
            return "Correct answer not found"
            
        except Exception as e:
            logger.error(f"Error extracting correct answer: {e}")
            return "Error extracting correct answer"
    
    def extract_explanation(self, soup: BeautifulSoup) -> str:
        """Extract explanation with ExamTopics-specific parsing"""
        try:
            # Look for explanation sections
            explanation_selectors = [
                '.explanation',
                '.solution',
                '.discussion',
                '.answer-explanation',
                '.comment-content',
                '.discussion-content'
            ]
            
            explanations = []
            
            for selector in explanation_selectors:
                elements = soup.select(selector)
                for element in elements:
                    text = element.get_text(strip=True)
                    if text and len(text) > 50:
                        explanations.append(text)
            
            # Combine all explanations
            if explanations:
                return ' '.join(explanations)
            
            # Fallback: look for paragraphs with explanation-like content
            paragraphs = soup.find_all('p')
            explanation_texts = []
            
            for p in paragraphs:
                text = p.get_text(strip=True)
                if (text and len(text) > 100 and 
                    any(keyword in text.lower() for keyword in ['because', 'therefore', 'thus', 'hence', 'explanation', 'reason'])):
                    explanation_texts.append(text)
            
            if explanation_texts:
                return ' '.join(explanation_texts)
            
            return "Explanation not found"
            
        except Exception as e:
            logger.error(f"Error extracting explanation: {e}")
            return "Error extracting explanation"
    
    def extract_images(self, soup: BeautifulSoup, base_url: str) -> List[str]:
        """Extract image URLs with enhanced filtering"""
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
                    
                    # Filter out common non-content images
                    if not any(skip in src.lower() for skip in ['logo', 'icon', 'avatar', 'banner', 'ad']):
                        images.append(src)
            
            return images
            
        except Exception as e:
            logger.error(f"Error extracting images: {e}")
            return []
    
    def extract_discussion_comments(self, soup: BeautifulSoup) -> List[Dict]:
        """Extract discussion comments from the page"""
        comments = []
        try:
            # Look for comment elements
            comment_selectors = [
                '.comment',
                '.discussion-comment',
                '.reply',
                '.post'
            ]
            
            for selector in comment_selectors:
                elements = soup.select(selector)
                for element in elements:
                    # Extract comment text
                    text_elem = element.find(['p', 'div', 'span'])
                    if text_elem:
                        text = text_elem.get_text(strip=True)
                        if text and len(text) > 10:
                            comments.append({
                                'text': text,
                                'author': 'Unknown',  # Could be enhanced to extract author
                                'timestamp': 'Unknown'  # Could be enhanced to extract timestamp
                            })
            
            return comments
            
        except Exception as e:
            logger.error(f"Error extracting comments: {e}")
            return []
    
    def extract_vote_count(self, soup: BeautifulSoup) -> int:
        """Extract vote count if available"""
        try:
            # Look for vote indicators
            vote_selectors = [
                '.votes',
                '.vote-count',
                '.rating',
                '.score'
            ]
            
            for selector in vote_selectors:
                elements = soup.select(selector)
                for element in elements:
                    text = element.get_text(strip=True)
                    # Extract numbers from text
                    numbers = re.findall(r'\d+', text)
                    if numbers:
                        return int(numbers[0])
            
            return 0
            
        except Exception as e:
            logger.error(f"Error extracting vote count: {e}")
            return 0
    
    def check_premium_content(self, soup: BeautifulSoup) -> bool:
        """Check if content is premium/paid"""
        try:
            # Look for premium indicators
            premium_indicators = [
                'premium',
                'paid',
                'subscribe',
                'upgrade'
            ]
            
            page_text = soup.get_text().lower()
            return any(indicator in page_text for indicator in premium_indicators)
            
        except Exception as e:
            logger.error(f"Error checking premium content: {e}")
            return False
    
    def scrape_question(self, link_data: Dict[str, str]) -> ExamQuestion:
        """Scrape a single question with enhanced data extraction"""
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
        
        # Extract all data
        question.question_text = self.extract_question_text(soup)
        question.options = self.extract_options(soup)
        question.correct_answer = self.extract_correct_answer(soup)
        question.explanation = self.extract_explanation(soup)
        question.images = self.extract_images(soup, url)
        question.discussion_comments = self.extract_discussion_comments(soup)
        question.vote_count = self.extract_vote_count(soup)
        question.is_premium = self.check_premium_content(soup)
        
        logger.info(f"Successfully scraped question {question_number}")
        return question
    
    def scrape_all_questions(self, csv_file: str, output_file: str = None, 
                           start_index: int = 0, end_index: int = None) -> List[ExamQuestion]:
        """Scrape all questions from the CSV file with optional range"""
        if output_file is None:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            output_file = f"advanced_scraped_questions_{timestamp}.json"
        
        # Load links
        links = self.load_links_from_csv(csv_file)
        if not links:
            logger.error("No links found in CSV file")
            return []
        
        # Apply range if specified
        if end_index is None:
            end_index = len(links)
        links = links[start_index:end_index]
        
        questions = []
        total_links = len(links)
        
        logger.info(f"Starting to scrape {total_links} questions (range: {start_index}-{end_index})")
        
        for i, link_data in enumerate(links, 1):
            try:
                question = self.scrape_question(link_data)
                questions.append(question)
                
                logger.info(f"Progress: {i}/{total_links} ({i/total_links*100:.1f}%)")
                
                # Save progress periodically
                if i % 5 == 0:
                    self.save_questions(questions, f"progress_{output_file}")
                
            except Exception as e:
                logger.error(f"Error scraping question {link_data['question']}: {e}")
                continue
        
        # Save final results
        self.save_questions(questions, output_file)
        logger.info(f"Scraping completed. Saved {len(questions)} questions to {output_file}")
        
        return questions
    
    def save_questions(self, questions: List[ExamQuestion], filename: str):
        """Save questions to JSON file with enhanced serialization"""
        try:
            data = []
            for question in questions:
                question_dict = asdict(question)
                data.append(question_dict)
            
            with open(filename, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
            
            logger.info(f"Saved {len(questions)} questions to {filename}")
            
        except Exception as e:
            logger.error(f"Error saving questions: {e}")
    
    def export_to_csv(self, questions: List[ExamQuestion], filename: str):
        """Export questions to CSV format with enhanced fields"""
        try:
            with open(filename, 'w', newline='', encoding='utf-8') as csvfile:
                fieldnames = [
                    'topic', 'question_number', 'url', 'question_text',
                    'options', 'correct_answer', 'explanation', 'images',
                    'difficulty', 'tags', 'vote_count', 'is_premium'
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
                        'tags': '|'.join(question.tags),
                        'vote_count': question.vote_count,
                        'is_premium': question.is_premium
                    })
            
            logger.info(f"Exported {len(questions)} questions to {filename}")
            
        except Exception as e:
            logger.error(f"Error exporting to CSV: {e}")
    
    def generate_summary_report(self, questions: List[ExamQuestion]) -> Dict:
        """Generate a summary report of the scraping results"""
        if not questions:
            return {}
        
        total_questions = len(questions)
        questions_with_text = sum(1 for q in questions if q.question_text and q.question_text != "Question text not found")
        questions_with_options = sum(1 for q in questions if q.options)
        questions_with_explanation = sum(1 for q in questions if q.explanation and q.explanation != "Explanation not found")
        questions_with_images = sum(1 for q in questions if q.images)
        premium_questions = sum(1 for q in questions if q.is_premium)
        
        topics = {}
        for q in questions:
            topic = q.topic
            if topic not in topics:
                topics[topic] = 0
            topics[topic] += 1
        
        return {
            'total_questions': total_questions,
            'questions_with_text': questions_with_text,
            'questions_with_options': questions_with_options,
            'questions_with_explanation': questions_with_explanation,
            'questions_with_images': questions_with_images,
            'premium_questions': premium_questions,
            'success_rate': {
                'text': f"{questions_with_text/total_questions*100:.1f}%",
                'options': f"{questions_with_options/total_questions*100:.1f}%",
                'explanation': f"{questions_with_explanation/total_questions*100:.1f}%",
                'images': f"{questions_with_images/total_questions*100:.1f}%"
            },
            'topics_distribution': topics
        }

def main():
    """Main function to run the advanced scraper"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Advanced ExamTopics Scraper')
    parser.add_argument('csv_file', help='Path to CSV file containing links')
    parser.add_argument('--output', '-o', help='Output JSON file name')
    parser.add_argument('--csv-output', help='Output CSV file name')
    parser.add_argument('--delay', type=float, default=2.0, help='Delay between requests (seconds)')
    parser.add_argument('--retries', type=int, default=3, help='Maximum retry attempts')
    parser.add_argument('--start', type=int, default=0, help='Start index for scraping range')
    parser.add_argument('--end', type=int, help='End index for scraping range')
    parser.add_argument('--summary', action='store_true', help='Generate summary report')
    
    args = parser.parse_args()
    
    # Check if CSV file exists
    if not os.path.exists(args.csv_file):
        logger.error(f"CSV file not found: {args.csv_file}")
        sys.exit(1)
    
    # Create scraper instance
    scraper = AdvancedExamTopicsScraper(delay=args.delay, max_retries=args.retries)
    
    try:
        # Scrape all questions
        questions = scraper.scrape_all_questions(
            args.csv_file, 
            args.output,
            args.start,
            args.end
        )
        
        # Export to CSV if requested
        if args.csv_output:
            scraper.export_to_csv(questions, args.csv_output)
        
        # Generate summary if requested
        if args.summary:
            summary = scraper.generate_summary_report(questions)
            summary_file = f"summary_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
            with open(summary_file, 'w', encoding='utf-8') as f:
                json.dump(summary, f, indent=2, ensure_ascii=False)
            logger.info(f"Summary report saved to {summary_file}")
            logger.info(f"Summary: {json.dumps(summary, indent=2)}")
        
        logger.info(f"Scraping completed successfully. Total questions: {len(questions)}")
        
    except KeyboardInterrupt:
        logger.info("Scraping interrupted by user")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main() 