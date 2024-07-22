# chat_server.py
import http.server
import socketserver
import argparse
from collections import defaultdict
from datetime import datetime, timedelta
import time
from urllib.parse import urlparse, parse_qs
import json

PORT = 8000

class ChatHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            self.path = 'index.html'
            return super().do_GET()
        elif self.path.startswith('/get_messages'):
            query = parse_qs(urlparse(self.path).query)
            room_id = query.get('room_id', [''])[0]
            if room_id in rooms:
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                messages = [{'username': user, 'message': msg} for _, user, msg in rooms[room_id]['messages']]
                self.wfile.write(json.dumps({'messages': messages}).encode('utf-8'))
            else:
                self.send_response(404)
                self.end_headers()
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        global rooms
        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length).decode('utf-8')
        data = dict(x.split('=') for x in post_data.split('&'))
        
        if self.path == '/enter_room':
            room_id = data.get('room_id', '')
            username = data.get('username', '匿名')
            if room_id not in rooms:
                rooms[room_id] = {'messages': [], 'users': set()}
            rooms[room_id]['users'].add(username)
            self.send_response(200)
            self.end_headers()
            self.wfile.write(f"Welcome to room {room_id}".encode('utf-8'))
        elif self.path == '/send_message':
            room_id = data.get('room_id')
            message = data.get('message')
            if room_id in rooms and len(message) <= 2048:
                rooms[room_id]['messages'].append((datetime.now(), data.get('username', '匿名'), message))
                # Limit messages per room
                if len(rooms[room_id]['messages']) > 50:
                    rooms[room_id]['messages'].pop(0)
                self.send_response(200)
                self.end_headers()
                self.wfile.write("Message sent".encode('utf-8'))
            else:
                self.send_response(400)
                self.end_headers()
                self.wfile.write("Invalid request".encode('utf-8'))

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Simple chat server')
    parser.add_argument('--port', type=int, default=PORT, help='Server port')
    args = parser.parse_args()
    
    rooms = defaultdict(lambda: {'messages': [], 'users': set()})
    with socketserver.TCPServer(("", args.port), ChatHandler) as httpd:
        print("serving at port", args.port)
        httpd.serve_forever()