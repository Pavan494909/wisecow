#!/usr/bin/env python3

import requests
import time
import sys
import json
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime
import argparse

class ApplicationHealthChecker:
    def __init__(self, config_file=None):
        self.results = []
        self.config = self.load_config(config_file)
        
    def load_config(self, config_file):
        """Load configuration from JSON file or use defaults"""
        default_config = {
            "timeout": 10,
            "retry_attempts": 3,
            "retry_delay": 2,
            "expected_status_codes": [200, 201, 202, 204],
            "critical_keywords": ["error", "exception", "down", "maintenance"],
            "success_keywords": ["success", "ok", "running", "healthy"],
            "alert_email": None,
            "smtp_server": "localhost",
            "smtp_port": 587
        }
        
        if config_file:
            try:
                with open(config_file, 'r') as f:
                    user_config = json.load(f)
                    default_config.update(user_config)
            except FileNotFoundError:
                print(f"⚠️  Config file {config_file} not found. Using defaults.")
            except json.JSONDecodeError:
                print(f"⚠️  Invalid JSON in config file {config_file}. Using defaults.")
        
        return default_config
    
    def check_application(self, url, name=None, method='GET', headers=None, data=None):
        """Check if application is up and functioning correctly"""
        if name is None:
            name = url
        
        print(f"🔍 Checking {name}...")
        
        for attempt in range(self.config['retry_attempts']):
            try:
                start_time = time.time()
                
                if method.upper() == 'GET':
                    response = requests.get(
                        url, 
                        timeout=self.config['timeout'],
                        headers=headers,
                        verify=False  # For testing with self-signed certs
                    )
                elif method.upper() == 'POST':
                    response = requests.post(
                        url,
                        timeout=self.config['timeout'],
                        headers=headers,
                        data=data,
                        verify=False
                    )
                else:
                    response = requests.request(
                        method,
                        url,
                        timeout=self.config['timeout'],
                        headers=headers,
                        data=data,
                        verify=False
                    )
                
                response_time = round((time.time() - start_time) * 1000, 2)
                
                # Check status code
                status_ok = response.status_code in self.config['expected_status_codes']
                
                # Check response content for critical/success keywords
                content = response.text.lower()
                has_critical_keyword = any(keyword in content for keyword in self.config['critical_keywords'])
                has_success_keyword = any(keyword in content for keyword in self.config['success_keywords'])
                
                # Determine application status
                if status_ok and not has_critical_keyword:
                    if has_success_keyword:
                        status = "UP"
                        status_emoji = "✅"
                    else:
                        status = "UP"
                        status_emoji = "✅"
                else:
                    status = "DOWN"
                    status_emoji = "❌"
                
                result = {
                    'name': name,
                    'url': url,
                    'status': status,
                    'status_code': response.status_code,
                    'response_time_ms': response_time,
                    'timestamp': datetime.now().isoformat(),
                    'content_analysis': {
                        'has_critical_keywords': has_critical_keyword,
                        'has_success_keywords': has_success_keyword
                    }
                }
                
                self.results.append(result)
                
                print(f"{status_emoji} {name}: {status} "
                      f"(Status: {response.status_code}, "
                      f"Response Time: {response_time}ms)")
                
                return result
                
            except requests.exceptions.RequestException as e:
                if attempt < self.config['retry_attempts'] - 1:
                    print(f"⚠️  Attempt {attempt + 1} failed for {name}. Retrying...")
                    time.sleep(self.config['retry_delay'])
                else:
                    result = {
                        'name': name,
                        'url': url,
                        'status': 'DOWN',
                        'status_code': None,
                        'response_time_ms': None,
                        'timestamp': datetime.now().isoformat(),
                        'error': str(e)
                    }
                    
                    self.results.append(result)
                    print(f"❌ {name}: DOWN (Error: {e})")
                    return result
    
    def check_multiple_applications(self, applications):
        """Check multiple applications"""
        print("🚀 Starting Application Health Check...")
        print("=" * 60)
        
        for app in applications:
            self.check_application(**app)
        
        print("=" * 60)
        self.generate_report()
    
    def generate_report(self):
        """Generate a summary report"""
        total_checks = len(self.results)
        up_checks = len([r for r in self.results if r['status'] == 'UP'])
        down_checks = total_checks - up_checks
        
        print(f"\n📊 HEALTH CHECK SUMMARY")
        print(f"Total Applications: {total_checks}")
        print(f"✅ UP: {up_checks}")
        print(f"❌ DOWN: {down_checks}")
        print(f"📈 Success Rate: {(up_checks/total_checks)*100:.1f}%")
        
        # Show response times for UP applications
        up_times = [r['response_time_ms'] for r in self.results if r['status'] == 'UP' and r['response_time_ms']]
        if up_times:
            avg_time = sum(up_times) / len(up_times)
            max_time = max(up_times)
            min_time = min(up_times)
            print(f"⏱️  Response Times - Avg: {avg_time:.2f}ms, Min: {min_time:.2f}ms, Max: {max_time:.2f}ms")
        
        # Show details for DOWN applications
        down_apps = [r for r in self.results if r['status'] == 'DOWN']
        if down_apps:
            print(f"\n🔴 DOWN APPLICATIONS:")
            for app in down_apps:
                print(f"   - {app['name']}: {app.get('error', 'Unknown error')}")
        
        return up_checks == total_checks
    
    def send_alert(self, subject, message):
        """Send email alert if configured"""
        if not self.config.get('alert_email'):
            return
        
        try:
            msg = MIMEMultipart()
            msg['From'] = self.config['alert_email']
            msg['To'] = self.config['alert_email']
            msg['Subject'] = subject
            
            msg.attach(MIMEText(message, 'plain'))
            
            server = smtplib.SMTP(self.config['smtp_server'], self.config['smtp_port'])
            server.send_message(msg)
            server.quit()
            
            print(f"📧 Alert email sent to {self.config['alert_email']}")
        except Exception as e:
            print(f"⚠️  Failed to send alert email: {e}")
    
    def save_results(self, filename=None):
        """Save results to JSON file"""
        if filename is None:
            filename = f"health_check_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        
        with open(filename, 'w') as f:
            json.dump(self.results, f, indent=2)
        
        print(f"💾 Results saved to {filename}")

def main():
    parser = argparse.ArgumentParser(description='Application Health Checker')
    parser.add_argument('-c', '--config', help='Configuration file (JSON)')
    parser.add_argument('-u', '--url', help='Single URL to check')
    parser.add_argument('-f', '--file', help='File with list of URLs (JSON)')
    parser.add_argument('-s', '--save', help='Save results to file')
    parser.add_argument('--email', action='store_true', help='Send email alerts')
    
    args = parser.parse_args()
    
    checker = ApplicationHealthChecker(args.config)
    
    applications = []
    
    # Single URL check
    if args.url:
        applications.append({'url': args.url})
    
    # File with multiple URLs
    elif args.file:
        try:
            with open(args.file, 'r') as f:
                applications = json.load(f)
        except FileNotFoundError:
            print(f"❌ File {args.file} not found")
            sys.exit(1)
        except json.JSONDecodeError:
            print(f"❌ Invalid JSON in {args.file}")
            sys.exit(1)
    
    # Default applications to check
    else:
        applications = [
            {'url': 'http://localhost:30007', 'name': 'WiseCow App'},
            {'url': 'https://httpbin.org/status/200', 'name': 'HTTPBin Test'},
            {'url': 'https://google.com', 'name': 'Google'},
        ]
    
    # Perform health checks
    checker.check_multiple_applications(applications)
    
    # Save results if requested
    if args.save:
        checker.save_results(args.save)
    
    # Send alert if any application is down and email is configured
    down_apps = [r for r in checker.results if r['status'] == 'DOWN']
    if down_apps and args.email:
        subject = f"🚨 Application Health Alert - {len(down_apps)} apps down"
        message = f"The following applications are down:\n"
        for app in down_apps:
            message += f"- {app['name']}: {app.get('error', 'Unknown error')}\n"
        checker.send_alert(subject, message)
    
    # Exit with appropriate code
    sys.exit(0 if not down_apps else 1)

if __name__ == "__main__":
    main()
