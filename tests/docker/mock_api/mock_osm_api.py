#!/usr/bin/env python3
"""
Mock OSM API Server for Testing
Author: Andres Gomez (AngocA)
Version: 2025-07-20
"""

import json
import time
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import xml.etree.ElementTree as ET

class MockOSMAPIHandler(BaseHTTPRequestHandler):
    """Mock handler for OSM API endpoints"""
    
    def __init__(self, *args, **kwargs):
        self.api_responses = self._load_responses()
        super().__init__(*args, **kwargs)
    
    def _load_responses(self):
        """Load predefined API responses"""
        return {
            '/api/0.6/notes': self._get_notes_response,
            '/api/0.6/notes/123': self._get_note_detail_response,
            '/api/0.6/notes/456': self._get_note_detail_response,
            '/api/0.6/notes/789': self._get_note_detail_response,
        }
    
    def do_GET(self):
        """Handle GET requests"""
        parsed_url = urlparse(self.path)
        path = parsed_url.path
        
        # Set CORS headers
        self.send_response(200)
        self.send_header('Content-type', 'application/xml')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()
        
        # Handle different endpoints
        if path in self.api_responses:
            response = self.api_responses[path]()
            self.wfile.write(response.encode('utf-8'))
        else:
            # Default response for unknown endpoints
            self.wfile.write(self._get_default_response().encode('utf-8'))
    
    def do_OPTIONS(self):
        """Handle OPTIONS requests for CORS"""
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()
    
    def _get_notes_response(self):
        """Mock response for /api/0.6/notes"""
        return '''<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6" generator="OpenStreetMap server">
  <note lat="40.7128" lon="-74.0060">
    <id>123</id>
    <url>https://www.openstreetmap.org/api/0.6/notes/123</url>
    <comment_url>https://www.openstreetmap.org/api/0.6/notes/123/comment</comment_url>
    <close_url>https://www.openstreetmap.org/api/0.6/notes/123/close</close_url>
    <date_created>2013-04-28T02:39:27Z</date_created>
    <status>open</status>
    <comments>
      <comment>
        <date>2013-04-28T02:39:27Z</date>
        <uid>123</uid>
        <user>user1</user>
        <action>opened</action>
        <text>Test comment 1</text>
      </comment>
    </comments>
  </note>
  <note lat="34.0522" lon="-118.2437">
    <id>456</id>
    <url>https://www.openstreetmap.org/api/0.6/notes/456</url>
    <comment_url>https://www.openstreetmap.org/api/0.6/notes/456/comment</comment_url>
    <close_url>https://www.openstreetmap.org/api/0.6/notes/456/close</close_url>
    <date_created>2013-04-30T15:20:45Z</date_created>
    <status>closed</status>
    <comments>
      <comment>
        <date>2013-04-30T15:20:45Z</date>
        <uid>456</uid>
        <user>user2</user>
        <action>opened</action>
        <text>Test comment 2</text>
      </comment>
      <comment>
        <date>2013-05-01T10:15:30Z</date>
        <uid>789</uid>
        <user>user3</user>
        <action>closed</action>
        <text>Closing this note</text>
      </comment>
    </comments>
  </note>
</osm>'''
    
    def _get_note_detail_response(self):
        """Mock response for individual note details"""
        return '''<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6" generator="OpenStreetMap server">
  <note lat="40.7128" lon="-74.0060">
    <id>123</id>
    <url>https://www.openstreetmap.org/api/0.6/notes/123</url>
    <comment_url>https://www.openstreetmap.org/api/0.6/notes/123/comment</comment_url>
    <close_url>https://www.openstreetmap.org/api/0.6/notes/123/close</close_url>
    <date_created>2013-04-28T02:39:27Z</date_created>
    <status>open</status>
    <comments>
      <comment>
        <date>2013-04-28T02:39:27Z</date>
        <uid>123</uid>
        <user>user1</user>
        <action>opened</action>
        <text>Test comment 1</text>
      </comment>
    </comments>
  </note>
</osm>'''
    
    def _get_default_response(self):
        """Default response for unknown endpoints"""
        return '''<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6" generator="OpenStreetMap server">
</osm>'''

def run_mock_server(port=8000):
    """Run the mock OSM API server"""
    server_address = ('', port)
    httpd = HTTPServer(server_address, MockOSMAPIHandler)
    print(f"Mock OSM API server running on port {port}")
    print("Available endpoints:")
    print("  - GET /api/0.6/notes")
    print("  - GET /api/0.6/notes/{id}")
    httpd.serve_forever()

if __name__ == '__main__':
    run_mock_server() 