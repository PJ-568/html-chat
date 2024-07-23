import os
import json
import datetime
from configparser import ConfigParser
from http.server import BaseHTTPRequestHandler, HTTPServer
import ssl
import argparse

# 使用ConfigParser来读写.ini文件
config = ConfigParser()

class ChatServer(BaseHTTPRequestHandler):
    rooms = {}
    max_rooms = 32
    max_messages_per_room = 50
    max_message_length = 2048
    max_messages_per_minute = 20

    @classmethod
    def load_rooms(cls):
        """从.ini文件加载聊天室数据"""
        config.read('chat_records.ini')
        for section in config.sections():
            cls.rooms[section] = {
                'users': json.loads(config.get(section, 'users')),
                'messages': json.loads(config.get(section, 'messages'))
            }

    @classmethod
    def save_rooms(cls):
        """将聊天室数据保存到.ini文件"""
        config.clear()  # 清除旧的数据
        for room_id, room in cls.rooms.items():
            config.add_section(room_id)
            config.set(room_id, 'users', json.dumps(room['users']))
            config.set(room_id, 'messages', json.dumps(room['messages']))
        with open('chat_records.ini', 'w', encoding='utf-8') as configfile:
            config.write(configfile)

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
        
        self.save_rooms()

    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            with open('index.html', 'rb') as file:
                self.wfile.write(file.read())
        elif self.path.startswith('/messages'):
            self.messages(self.path.split('=')[1])
        self.save_rooms()

    def join(self, nickname, room_id):
        if not room_id:
            room_id = 'default'
        if room_id not in self.rooms:
            self.rooms[room_id] = {'users': [], 'messages': []}
            if len(self.rooms) > self.max_rooms:
                oldest_room = next(iter(self.rooms))
                del self.rooms[oldest_room]
        self.rooms[room_id]['users'].append(nickname)
        self.send_response(200)
        self.end_headers()

    def send(self, message, room_id):
        if not room_id:
            room_id = 'default'
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
        if not room_id:
            room_id = 'default'
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(self.rooms[room_id]['messages']).encode())

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Simple chat server.')
    parser.add_argument('--port', type=int, default=2666, help='Port to listen on')
    args = parser.parse_args()

    server_address = ('0.0.0.0', args.port)
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

    ChatServer.load_rooms()
    httpd.serve_forever()