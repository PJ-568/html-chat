import os
from http.server import BaseHTTPRequestHandler, HTTPServer
import ssl
import json
import argparse
import datetime

class ChatServer(BaseHTTPRequestHandler):
    rooms = {}
    max_rooms = 32
    max_messages_per_room = 50
    max_message_length = 2048
    max_messages_per_minute = 20

    def do_POST(self):
        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length)
        data = json.loads(post_data)

        if self.path == '/join':
            self.join(data['nickname'], data['roomId'])
        elif self.path == '/send':
            self.send(data['message'], data['roomId'])
        elif self.path == '/leave':
            self.leave(data['roomId'])

    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            with open('index.html', 'rb') as file:
                self.wfile.write(file.read())
        elif self.path.startswith('/messages'):
            self.messages(self.path.split('=')[1])

    def join(self, nickname, room_id):
        if room_id not in self.rooms:
            self.rooms[room_id] = {'users': [], 'messages': []}
            if len(self.rooms) > self.max_rooms:
                oldest_room = next(iter(self.rooms))
                del self.rooms[oldest_room]
        self.rooms[room_id]['users'].append(nickname)
        self.send_response(200)
        self.end_headers()

    def send(self, message, room_id):
        nickname = "匿名"  # 默认昵称，应根据实际情况获取
        if room_id in self.rooms and self.rooms[room_id]['users']:
            nickname = self.rooms[room_id]['users'][-1]  # 获取最新加入用户的昵称
        if len(message) > self.max_message_length:
            return
        if len(self.rooms[room_id]['messages']) >= self.max_messages_per_room:
            self.rooms[room_id]['messages'].pop(0)
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        self.rooms[room_id]['messages'].append({"timestamp": timestamp, "nickname": nickname, "message": message})
        self.send_response(200)
        self.end_headers()

    def leave(self, room_id):
        self.send_response(200)
        self.end_headers()

    def messages(self, room_id):
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(self.rooms[room_id]['messages']).encode())

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Simple chat server.')
    parser.add_argument('--port', type=int, default=8000, help='Port to listen on')
    args = parser.parse_args()

    server_address = ('', args.port)
    httpd = HTTPServer(server_address, ChatServer)
    
    # 检查证书和私钥文件是否存在
    if os.path.exists("server.crt") and os.path.exists("server.key"):
        # 创建SSL上下文并加载证书和私钥
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        try:
            context.load_cert_chain(certfile="server.crt", keyfile="server.key")
            # 将SSL上下文应用于HTTP服务器
            httpd.socket = context.wrap_socket(httpd.socket, server_side=True)
            print(f'Starting HTTPS server on port {args.port}')
        except ssl.SSLError as e:
            print(f'Error loading SSL certificate or key: {e}')
            print(f'Continuing with HTTP server on port {args.port}')
    else:
        print(f'Certificate or key files not found. Continuing with HTTP service on port {args.port}')

    httpd.serve_forever()