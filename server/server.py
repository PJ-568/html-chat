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
    max_message_length = 1024
    max_messages_per_minute = 45
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
            if self.path == '/' or self.path == '/index.html' or self.path.startswith('/?') or self.path.startswith('/index.html?'):
                query_string = self.path.split('?', 1)[-1]
                query_params = parse_qs(query_string)
                nickname = query_params.get('nickname', [''])[0]
                roomid = query_params.get('roomid', [''])[0]
                self.send_response(200)
                self.send_header('Content-type', 'text/html')
                self.end_headers()
                self.wfile.write(self.generate_home_html(nickname, roomid))
            elif self.path.startswith('/chat'):
                query_params = parse_qs(self.path[6:])
                nickname = query_params.get('nickname', ['匿名'])[0]
                roomid = query_params.get('roomid', ['默认'])[0]
                self.send_response(200)
                self.send_header('Content-type', 'text/html')
                self.end_headers()
                self.wfile.write(self.generate_chat_html(nickname, roomid))
            elif self.path.startswith('/log'):
                query_string = self.path.split('?', 1)[-1]
                query_params = parse_qs(query_string)
                roomid = query_params.get('id', ['默认'])[0]
                self.send_response(200)
                self.send_header('Content-type', 'text/html')
                self.end_headers()
                self.wfile.write(self.generate_chat_log_html(roomid))
            elif self.path.endswith('.css'):
                self.send_response(200)
                self.send_header('Content-type', 'text/css')
                self.end_headers()
                self.wfile.write(self.generate_css())
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

                # 发送频率上限检查
                if self.check_message_rate_limit(roomid):
                    if message and len(message) <= self.max_message_length:
                        self.add_message(roomid, nickname, message)
                    else:
                        self.send_error(413, "Request Entity Too Large or is Null")
                        return
                    self.send_response(302)
                    self.send_header('Location', f'/chat?nickname={quote(nickname)}&roomid={quote(roomid)}')
                    self.end_headers()
                    self.save_rooms() # 不执行会导致用户无法第一时间读取最新聊天记录
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

    def generate_css(self):
        return f'''body {{font-family: Arial, sans-serif;background-color: #f4f4f4;margin: 0;padding-top: 20px;color: #333;}}.container {{box-sizing: border-box;overflow: hidden;width: 100%;max-width: 600px;margin: 0 auto;padding: 20px;background-color: #fff;border: 1px solid #ccc;box-shadow: 2px 2px 5px rgba(0, 0, 0, 0.1);border-radius: 5px;}}fieldset {{border: 1px solid #ddd;padding: 10px;margin-bottom: 5px;}}legend {{font-weight: bold;padding: 0 10px;}}label {{display: block;margin-bottom: 5px;}}input[type="text"],iframe {{box-sizing: border-box;max-width: 100%;width: 100%;padding: 8px;margin-bottom: 10px;border: 1px solid #ddd;border-radius: 3px;}}a,a:visited,button {{align-items: center;text-decoration: none;padding: 8px 15px;margin-right: 5px;background-color: #007BFF;color: #fff;border: none;border-radius: 3px;cursor: pointer;}}a:hover,a:visited:hover,button:hover {{background-color: #0056b3;}}button:active {{background-color: #0067b8;}}@media (max-width: 600px) {{.container {{width: 100%;height: 100%;border: none;border-radius: 0;box-shadow: none;}}}}'''.encode('utf-8')

    def generate_home_html(self, nickname, roomid):
        return f'''<!DOCTYPE html><html lang="zh-Hans"><head><meta charset="UTF-8"><title>聊天室</title><link type="text/css" rel="stylesheet" href="html-chat.css"><meta name="viewport" content="width=192, initial-scale=1.0"></head><body><div class="container"><form action="./chat" method="get"><fieldset><legend>主页</legend><label for="nickname">昵称：</label><input type="text" id="nickname" name="nickname" value="{nickname}" placeholder="匿名"><br><label for="roomid">房间号：</label><input type="text" id="roomid" name="roomid" value="{roomid}" placeholder="默认"><br><button type="submit">进入聊天室</button></fieldset></form></div></body></html>'''.encode('utf-8')

    def generate_chat_html(self, nickname, roomid):
        return f'''<!DOCTYPE html><html lang="zh-Hans"><head><meta charset="UTF-8"><title>聊天室 - {roomid}</title><link type="text/css" rel="stylesheet" href="html-chat.css"><meta name="viewport" content="width=192, initial-scale=1.0"></head><body><div class="container"><form action="./send_message" method="post"><fieldset><legend>聊天室 - {roomid}</legend><iframe src="./log?id={roomid}" frameborder="0">加载中……</iframe><br><label for="messageInput">{nickname}说：</label><input type="text" id="messageInput" name="messageInput"><button type="submit">发送</button><a href=".?nickname={nickname}&roomid={roomid}">退出</a></fieldset><input type="text" id="nickname" name="nickname" value="{nickname}" style="display: none;"><input type="text" id="roomid" name="roomid" value="{roomid}" style="display: none;"></form></div></body></html>'''.encode('utf-8')

    def generate_chat_log_html(self, roomid):
        messages = self.rooms.get(roomid, [])
        chat_log = '<br>'.join(messages) if messages else '<p style="color:#ccc">无聊天记录</p>'
        return f'''<!DOCTYPE html><html lang="zh-Hans"><head><meta charset="UTF-8"><title>聊天记录 - {roomid}</title><meta name="viewport" content="width=device-width, initial-scale=1.0"><meta http-equiv="refresh" content="60"></head><body style="font-family: Arial, sans-serif;"><span>{chat_log}</span></body></html>'''.encode('utf-8')

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
    parser.add_argument('--port', type=int, default=2666, help='Port to listen on.')
    args = parser.parse_args()

    server_address = ('0.0.0.0', args.port)
    httpd = socketserver.TCPServer(server_address, ChatServer)
    httpd.allow_reuse_address = True

    print(f'Starting server at http://127.0.0.1:{args.port} ...')
    httpd.serve_forever()

if __name__ == '__main__':
    main()
