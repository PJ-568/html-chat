#!/usr/bin/env python3
import threading
import http.server
import socketserver
import configparser
import os
import time
from urllib.parse import parse_qs, quote
import argparse
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)

class ChatConfig:
    def __init__(self):
        self.config = configparser.ConfigParser()
        self.config_file = 'chat_records.ini'
        if not os.path.exists(self.config_file):
            open(self.config_file, 'w', encoding='utf-8').close()
        with open(self.config_file, 'r', encoding='utf-8') as config_file:
            self.config.read_file(config_file)

class ChatServer(http.server.BaseHTTPRequestHandler):
    rooms = {}
    max_rooms = 32
    max_messages_per_room = 50
    max_message_length = 2048
    max_messages_per_minute = 20
    message_rate_limit = {}  # To track messages per minute

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.load_rooms()

        # 创建一个线程，每 120 秒保存一次聊天数据
        self.save_thread = threading.Thread(target=self.save_rooms_periodically)
        self.save_thread.daemon = True
        self.save_thread.start()

    def do_GET(self):
        try:
            if self.path == '/':
                self.send_response(302)
                self.send_header('Location', '/index.html')
                self.end_headers()
            elif self.path == '/index.html':
                self.send_file('index.html')
            elif self.path.startswith('/chat'):
                query_params = parse_qs(self.path[6:])
                nickname = query_params.get('nickname', ['匿名'])[0]
                roomid = query_params.get('roomid', ['默认'])[0]
                self.send_response(200)
                self.send_header('Content-type', 'text/html')
                self.end_headers()
                self.wfile.write(self.generate_chat_html(nickname, roomid))
            elif self.path.endswith('.css'):
                self.send_file(self.path.lstrip('/'))
            else:
                self.send_error(404)
        except Exception as e:
            logging.error(f"Error processing GET request: {e}")
            self.send_error(500)

    def do_POST(self):
        try:
            if self.path == '/send_message':
                content_length = int(self.headers['Content-Length'])
                post_data = self.rfile.read(content_length).decode('utf-8')
                post_data = parse_qs(post_data)
                nickname = post_data.get('nickname', ['匿名'])[0]
                roomid = post_data.get('roomid', ['默认'])[0]
                message = post_data.get('messageInput', [''])[0]

                # 检查非法字符
                illegal_chars = ['<', '>', '&', '"', "'"]
                if any(char in message for char in illegal_chars):
                    self.send_error(400, "Bad Request: Message contains illegal characters.")
                    return

                # 长度检查
                if len(message) > self.max_message_length:
                    self.send_error(413, "Request Entity Too Large")
                    return

                # 发送频率上限检查
                if self.check_message_rate_limit(roomid):
                    if message and len(message) <= self.max_message_length:
                        self.add_message(roomid, nickname, message)
                    self.send_response(302)
                    self.send_header('Location', f'/chat?nickname={quote(nickname)}&roomid={quote(roomid)}')
                    self.end_headers()
                else:
                    self.send_error(429, "Too Many Requests")
            else:
                self.send_error(404)
        except Exception as e:
            logging.error(f"Error processing POST request: {e}")
            self.send_error(500)

    def check_message_rate_limit(self, roomid):
        current_time = time.time()
        if roomid not in self.message_rate_limit:
            self.message_rate_limit[roomid] = [current_time]
            return True

        # Remove old timestamps
        self.message_rate_limit[roomid] = [t for t in self.message_rate_limit[roomid] if t > current_time - 60]

        # 检查是否达到频率上限
        if len(self.message_rate_limit[roomid]) >= self.max_messages_per_minute:
            return False

        self.message_rate_limit[roomid].append(current_time)
        return True

    def add_message(self, roomid, nickname, message):
        if roomid not in self.rooms:
            if len(self.rooms) >= self.max_rooms:
                oldest_room = next(iter(self.rooms))
                del self.rooms[oldest_room]
            self.rooms[roomid] = []
        messages = self.rooms[roomid]
        timestamp = time.strftime('%Y-%m-%d %H:%M:%S', time.localtime())
        messages.append(f'{timestamp} {nickname}: {message}')
        if len(messages) > self.max_messages_per_room:
            messages.pop(0)

    def save_rooms(self):
        config = ChatConfig().config
        for roomid, messages in self.rooms.items():
            config[roomid] = {'messages': '\n'.join(messages)}
        with open(ChatConfig().config_file, 'w', encoding='utf-8') as configfile:
            config.write(configfile)

    def save_rooms_periodically(self):
        while True:
            self.save_rooms()
            time.sleep(120)

    def load_rooms(self):
        config = ChatConfig().config
        for section in config.sections():
            self.rooms[section] = config.get(section, 'messages').split('\n')

    def generate_chat_html(self, nickname, roomid):
        chat_log = '\n'.join(self.rooms.get(roomid, []))
        return f'''
<!DOCTYPE html>
<html lang="zh-Hans">
<head>
    <meta charset="UTF-8">
    <title>聊天室 - {roomid}</title>
    <meta http-equiv="refresh" content="60">
    <link type="text/css" rel="stylesheet" href="html-chat.css">
    <meta name="viewport" content="width=192, initial-scale=1.0">
</head>
<body>
    <div class="container">
        <form action="/send_message" method="post">
            <fieldset>
                <legend>聊天室 - {roomid}</legend>
                <textarea id="chatLog" rows="10" cols="50" readonly>{chat_log}</textarea>
                <br>
                <label for="messageInput">{nickname}说：</label>
                <input type="text" id="messageInput" name="messageInput">
                <button type="submit">发送</button>
                <a href=".">退出</a>
            </fieldset>
            <input type="text" id="nickname" name="nickname" value="{nickname}" style="display: none;">
            <input type="text" id="roomid" name="roomid" value="{roomid}" style="display: none;">
        </form>
    </div>
</body>
</html>
'''.encode('utf-8')

    def send_file(self, filename):
        try:
            if filename.endswith('.css'):
                self.send_response(200)
                self.send_header('Content-type', 'text/css; charset=UTF-8')
            else:
                self.send_response(200)
                self.send_header('Content-type', 'text/html; charset=UTF-8')

            self.end_headers()
            with open(filename, 'rb') as file:
                self.wfile.write(file.read())
        except FileNotFoundError:
            logging.error(f"File not found: {filename}")
            self.send_error(404)


def main():
    parser = argparse.ArgumentParser(description='聊天室')
    parser.add_argument('--port', type=int, default=8000, help='Port to listen on.')
    args = parser.parse_args()

    server_address = ('0.0.0.0', args.port)
    httpd = socketserver.TCPServer(server_address, ChatServer)
    httpd.allow_reuse_address = True

    print(f'Starting server on port {args.port}...')
    httpd.serve_forever()

if __name__ == '__main__':
    main()
