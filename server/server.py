#!/usr/bin/env python3
import threading
import http.server
import socketserver
import configparser
import os
import time
from urllib.parse import urlparse, parse_qs, quote
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
    max_cache_time = 86400
    auto_refresh_interval = 60
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
                query_string = urlparse(self.path).query
                query_params = parse_qs(query_string)
                nickname = query_params.get('nickname', [''])[0]
                roomid = query_params.get('roomid', [''])[0]
                lang = query_params.get('lang', [self.get_preferred_language()])[0]
                self.send_response(200)
                self.send_header('Content-type', 'text/html')
                self.send_header('Cache-Control', f'public, max-age={max_cache_time}')
                self.end_headers()
                self.wfile.write(self.generate_home_html(nickname, roomid, lang))
            elif self.path.startswith('/chat?'):
                query_params = parse_qs(urlparse(self.path).query)
                nickname = query_params.get('nickname', ['匿名'])[0]
                roomid = query_params.get('roomid', ['默认'])[0]
                message = query_params.get('messageInput', [''])[0]
                lang = query_params.get('lang', [self.get_preferred_language()])[0]
                
                # 检查非法字符
                illegal_chars = ['<', '>', '&', '"', "'", "\\"]
                if any(char in roomid for char in illegal_chars):
                    self.send_msg_error(400, "Bad Request: RoomID contains illegal characters.<br>房间号包含非法字符。")
                    return

                self.send_response(200)
                self.send_header('Content-type', 'text/html')
                self.send_header('Cache-Control', f'public, max-age={max_cache_time}')
                self.end_headers()
                self.wfile.write(self.generate_chat_html(nickname, roomid, message, lang))
            elif self.path.startswith('/log?'):
                print(self.path)
                query_params = parse_qs(urlparse(self.path).query)
                roomid = query_params.get('id', ['默认'])[0]
                lang = query_params.get('lang', [self.get_preferred_language()])[0]
                
                # 检查非法字符
                illegal_chars = ['<', '>', '&', '"', "'", "\\"]
                if any(char in roomid for char in illegal_chars):
                    self.send_msg_error(400, "Bad Request: RoomID contains illegal characters.<br>房间号包含非法字符。")
                    return

                self.send_response(200)
                self.send_header('Content-type', 'text/html')
                self.send_header('Cache-Control', f'public, max-age={auto_refresh_interval}')
                self.end_headers()
                self.wfile.write(self.generate_chat_log_html(roomid, lang))
            elif self.path == '/lb-chat.css':
                self.send_response(200)
                self.send_header('Content-type', 'text/css')
                self.send_header('Cache-Control', f'public, max-age={max_cache_time}')
                self.end_headers()
                self.wfile.write(self.generate_css())
            elif self.path == '/main.js':
                self.send_response(200)
                self.send_header('Content-type', 'text/javascript')
                self.send_header('Cache-Control', f'public, max-age={max_cache_time}')
                self.end_headers()
                self.wfile.write(self.generate_js())
            elif self.path == '/favicon.ico':
                self.send_response(200)
                self.send_header('Content-type', 'image/svg+xml')
                self.send_header('Cache-Control', f'public, max-age={max_cache_time}')
                self.end_headers()
                self.wfile.write(self.generate_favicon())
            else:
                self.send_msg_error(404, "Not Found.<br>未找到该资源。")
        except Exception as e:
            logging.error(f"Error processing GET request: {e}")
            self.send_msg_error(500, f"Server got itself in trouble.<br>服务器出错。<br>{e}")

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
                illegal_chars = ['<', '>', '&', '"', "'", "\\"]
                if any(char in message for char in illegal_chars):
                    self.send_msg_error(400, f"Bad Request: Message contains illegal characters.<br>消息包含非法字符。", f"<a href='./chat?nickname={nickname}&roomid={roomid}'>Back | 返回</a>")
                    return

                # 发送频率上限检查
                if self.check_message_rate_limit(roomid):
                    if message and len(message) <= self.max_message_length:
                        self.add_message(roomid, nickname, message)
                    else:
                        self.send_msg_error(413, f"Request Entity Too Large or is Null.<br>消息过长或为空。", f"<a href='./chat?nickname={nickname}&roomid={roomid}&messageInput={message}'>Back | 返回</a>")
                        return
                    self.send_response(302)
                    self.send_header('Location', f'/chat?nickname={quote(nickname)}&roomid={quote(roomid)}')
                    self.end_headers()
                    self.save_rooms() # 不执行会导致用户无法第一时间读取最新聊天记录
                else:
                    self.send_msg_error(429, f"Too Many Requests.<br>请求过于频繁，请稍后重试。", f"<a href='./send_message?nickname={nickname}&roomid={roomid}&messageInput={message}'>Retry | 重试</a><a href='./chat?nickname={nickname}&roomid={roomid}&messageInput={message}'>Back | 返回</a>")
            else:
                self.send_msg_error(404, "Not Found.<br>未找到该资源。")
        except Exception as e:
            logging.error(f"Error processing POST request: {e}")
            self.send_msg_error(500, f"Server got itself in trouble.<br>服务器出错。<br>{e}")
    
    def get_preferred_language(self):
        headers = self.headers
        accept_language = headers.get('Accept-Language')
    
        # 检查 accept_language 是否为 None 或空字符串
        if accept_language is None or not accept_language:
            # 如果 Accept-Language 不存在或为空，可以设置一个默认值
            accept_language = 'en-US,en;q=0.5'
        # 分割字符串为各个语言标签
        tags = accept_language.split(',')
        
        # 创建一个字典来存储每种语言的质量值
        language_qualities = {}
        
        # 遍历每个语言标签
        for tag in tags:
            # 移除任何前导或尾随的空白字符
            tag = tag.strip()
            
            # 分割语言标签以获取主要的语言代码和质量值
            parts = tag.split(';')
            primary_lang = parts[0].split('-')[0]  # 获取主要语言代码
            quality = 1.0  # 默认质量值
            
            # 如果存在质量值，则更新
            if len(parts) > 1 and parts[1].startswith('q='):
                quality = float(parts[1][2:])
            
            # 将主要语言代码和质量值添加到字典中
            language_qualities[primary_lang] = max(language_qualities.get(primary_lang, 0.0), quality)
        
        # 找到质量值最高的语言
        preferred_language = max(language_qualities, key=language_qualities.get)
        
        return preferred_language

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
        return f'''body{{font-family:Arial,sans-serif;background-color:#f4f4f4;margin:0;padding-top:20px;color:#333}}.container{{box-sizing:border-box;overflow:hidden;width:100%;max-width:600px;margin:0 auto;padding:20px;background-color:#fff;border:1px solid #ccc;box-shadow:2px 2px 5px rgba(0,0,0,0.1);border-radius:5px}}fieldset{{border:1px solid #ddd;padding:10px;margin-bottom:5px}}legend{{font-weight:bold;padding:0 10px}}label{{display:block;margin-bottom:5px}}input[type="text"],iframe,.content{{box-sizing:border-box;max-width:100%;width:100%;padding:8px;margin-bottom:10px;border:1px solid #ddd;border-radius:3px}}a,a:visited,button{{align-items:center;text-decoration:none;padding:8px 15px;margin-right:5px;background-color:#007BFF;color:#fff;border:none;border-radius:3px;cursor:pointer}}a:hover,a:visited:hover,button:hover{{background-color:#0056b3}}button:active{{background-color:#0067b8}}@media (max-width:600px){{.container{{width:100%;height:100%;border:none;border-radius:0;box-shadow:none}}}}.loading-bar{{position:fixed;top:0;left:0;z-index:99999;opacity:0;transition:opacity .4s linear;.progress{{position:fixed;top:0;left:0;width:0;height:4px;background-color:#007bff;box-shadow:0 0 10px rgba(119,182,255,.7)}}&.loading{{opacity:1;transition:none;.progress{{transition:width .4s ease}}}}}}'''.encode('utf-8')

    def generate_js(self):
        return f'''(function(){{var loadingBar=document.querySelector(".loading-bar");var progress=document.querySelector(".loading-bar .progress");var timer=null;let pjax;function initAni(){{loadingBar=document.querySelector(".loading-bar");progress=document.querySelector(".loading-bar .progress")}}function initPjax(){{try{{const Pjax=window.Pjax||function(){{}};pjax=new Pjax({{selectors:["head meta","head title","body container",".pjax-reload"]}})}}catch(e){{console.log('PJAX 初始化出错：'+e)}}}}function endLoad(){{clearInterval(timer);progress.style.width="100%";loadingBar.classList.remove("loading");setTimeout(function(){{progress.style.width=0}},400)}}function initialize(){{initPjax();initAni()}}window.addEventListener('DOMContentLoaded',()=>initialize());document.addEventListener("pjax:send",function(){{var loadingBarWidth=20;var MAX_LOADING_WIDTH=95;loadingBar.classList.add("loading");progress.style.width=loadingBarWidth+"%";clearInterval(timer);timer=setInterval(function(){{loadingBarWidth+=3;if(loadingBarWidth>MAX_LOADING_WIDTH){{loadingBarWidth=MAX_LOADING_WIDTH}}progress.style.width=loadingBarWidth+"%"}},500)}});document.addEventListener("pjax:complete",function(){{endLoad()}})}})();'''.encode('utf-8')

    def generate_favicon(self):
        return f'''<svg xmlns="http://www.w3.org/2000/svg" width="50" height="50"><circle cx="25" cy="25" r="20" fill="blue" /></svg>'''.encode('utf-8')

    def generate_home_html(self, nickname, roomid, lang='zh'):
        if lang != 'zh':
            return f'''<!DOCTYPE html><html lang="en-US"><head><meta charset="UTF-8"><title>LB-Chat</title><link type="text/css" rel="stylesheet" href="lb-chat.css"><meta name="viewport" content="width=192, initial-scale=1.0"><script src="main.js" type="text/javascript"></script></head><body><div class="container"><form action="./chat" method="get"><fieldset><legend>Home</legend><label for="nickname">Nickname:</label><input type="text" id="nickname" name="nickname" value="{nickname}" placeholder="匿名"><br><label for="roomid">Room ID:</label><input type="text" id="roomid" name="roomid" value="{roomid}" placeholder="默认"><br><button type="submit">Enter Chat Romm</button><a href="https://github.com/PJ-568/lb-chat/">Source Code</a><a href="?nickname={quote(nickname)}&roomid={quote(roomid)}&lang=zh">中文</a></fieldset><input type="text" id="lang" name="lang" value="{lang}" style="display: none;"></form></div></body></html>'''.encode('utf-8')
        return f'''<!DOCTYPE html><html lang="zh-Hans"><head><meta charset="UTF-8"><title>LB 聊天室</title><link type="text/css" rel="stylesheet" href="lb-chat.css"><meta name="viewport" content="width=192, initial-scale=1.0"><script src="main.js" type="text/javascript"></script></head><body><div class="container"><form action="./chat" method="get"><fieldset><legend>主页</legend><label for="nickname">昵称：</label><input type="text" id="nickname" name="nickname" value="{nickname}" placeholder="匿名"><br><label for="roomid">房间号：</label><input type="text" id="roomid" name="roomid" value="{roomid}" placeholder="默认"><br><button type="submit">进入聊天室</button><a href="https://gitee.com/PJ-568/lb-chat/">源码</a><a href="?nickname={quote(nickname)}&roomid={quote(roomid)}&lang=en">English</a></fieldset><input type="text" id="lang" name="lang" value="{lang}" style="display: none;"></form></div></body></html>'''.encode('utf-8')

    def generate_chat_html(self, nickname, roomid, message, lang='zh'):
        if lang != 'zh':
            return f'''<!DOCTYPE html><html lang="en-US"><head><meta charset="UTF-8"><title>LB-Chat - {roomid}</title><link type="text/css" rel="stylesheet" href="lb-chat.css"><meta name="viewport" content="width=192, initial-scale=1.0"><script src="main.js" type="text/javascript"></script></head><body><div class="container"><form action="./send_message" method="post"><fieldset><legend>LB-Chat - {roomid}</legend><iframe title="Chat history" src="./log?id={roomid}&lang={lang}" frameborder="0"></iframe><br><label for="messageInput">{nickname} says:</label><input type="text" id="messageInput" name="messageInput" value="{message}"><button type="submit">Send</button><a href=".?nickname={quote(nickname)}&roomid={quote(roomid)}&lang={quote(lang)}">Back</a></fieldset><input type="text" id="nickname" name="nickname" value="{nickname}" style="display: none;"><input type="text" id="roomid" name="roomid" value="{roomid}" style="display: none;"><input type="text" id="lang" name="lang" value="{lang}" style="display: none;"></form></div></body></html>'''.encode('utf-8')
        return f'''<!DOCTYPE html><html lang="zh-Hans"><head><meta charset="UTF-8"><title>LB 聊天室 - {roomid}</title><link type="text/css" rel="stylesheet" href="lb-chat.css"><meta name="viewport" content="width=192, initial-scale=1.0"><script src="main.js" type="text/javascript"></script></head><body><div class="container"><form action="./send_message" method="post"><fieldset><legend>聊天室 - {roomid}</legend><iframe title="聊天记录" src="./log?id={roomid}&lang={lang}" frameborder="0"></iframe><br><label for="messageInput">{nickname}说：</label><input type="text" id="messageInput" name="messageInput" value="{message}"><button type="submit">发送</button><a href=".?nickname={quote(nickname)}&roomid={quote(roomid)}&lang={quote(lang)}">退出</a></fieldset><input type="text" id="nickname" name="nickname" value="{nickname}" style="display: none;"><input type="text" id="roomid" name="roomid" value="{roomid}" style="display: none;"><input type="text" id="lang" name="lang" value="{lang}" style="display: none;"></form></div></body></html>'''.encode('utf-8')

    def generate_chat_log_html(self, roomid, lang='zh'):
        if lang != 'zh':
            empty_msg = 'No messages yet'
        else:
            empty_msg = '无聊天记录'
        messages = self.rooms.get(roomid, [])
        chat_log = '<br>'.join(messages) if messages else f'<p style="color:#ccc">{empty_msg}</p>'
        return f'''<!DOCTYPE html><html lang="zh-Hans"><head><meta charset="UTF-8"><title>聊天记录 - {roomid}</title><meta name="viewport" content="width=device-width, initial-scale=1.0"><meta http-equiv="refresh" content="{auto_refresh_interval}"></head><body style="font-family: Arial, sans-serif;"><span>{chat_log}</span></body></html>'''.encode('utf-8')

    def generate_error_html(self, errorCode, errorMsg = '', buttons = "<a href='/'>返回主页 | Back</a>"):
        if not errorMsg:
            errorMsg = f'错误代码：{errorCode}<br>Error code: {errorCode}'
        return f'''<!DOCTYPE html><html lang="zh-Hans"><head><meta charset="UTF-8"><title>错误：{errorCode}</title><link type="text/css" rel="stylesheet" href="/lb-chat.css"><meta name="viewport" content="width=192, initial-scale=1.0"><script src="/main.js" type="text/javascript"></script></head><body><div class="container"><fieldset><legend>错误：{errorCode}</legend><div class="content">{errorMsg}</div>{buttons}</fieldset></div></body></html>'''.encode('utf-8')

    def send_msg_error(self, errorCode, errorMsg = '', buttons = "<a href='/'>返回主页 | Back</a>"):
        self.send_response(errorCode)
        self.send_header('Content-type', 'text/html')
        self.end_headers()
        self.wfile.write(self.generate_error_html(errorCode, errorMsg, buttons))

    # def send_file(self, filename):
    #     try:
    #         if filename.endswith('.css'):
    #             self.send_response(200)
    #             self.send_header('Content-type', 'text/css; charset=UTF-8')
    #         else:
    #             self.send_response(200)
    #             self.send_header('Content-type', 'text/html; charset=UTF-8')

    #         self.end_headers()
    #         with open(filename, 'rb') as file:
    #             self.wfile.write(file.read())
    #     except FileNotFoundError:
    #         logging.error(f"File not found: {filename}")
    #         self.send_msg_error(404, "Not Found.<br>未找到该资源。")


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
