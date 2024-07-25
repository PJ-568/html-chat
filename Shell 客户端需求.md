# Shell 客户端需求

统一 UTF-8 编码，中文支持。
前端使用 dialog 或命令行（尽量 sh 且不引入第三方框架）。
慢慢来，实现以下功能：

## 客户端

### 主页

用户界面：

```
聊天室

  昵称：________
房间号：________

[进入房间]  [设置]  [退出]
```

1. 用户设置昵称，空值默认为“匿名”。
2. 输入或创建聊天室ID，空值默认为“默认”。
3. 只能在主页输入设置昵称和号码。

### 聊天室

服务端接口代码片段：

```python
# 发送消息
def do_POST(self):
    try:
        if self.path == '/send_message':
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length).decode('utf-8')
            post_data = parse_qs(post_data)
            nickname = post_data.get('nickname', ['匿名'])[0]
            roomid = post_data.get('roomid', ['默认'])[0]
            message = post_data.get('messageInput', [''])[0]
        # ...

# 接受消息
def do_GET(self):
    try:
        if self.path.startswith('/log'):
            query_string = self.path.split('?', 1)[-1]
            query_params = parse_qs(query_string)
            roomid = query_params.get('id', ['默认'])[0]
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(self.generate_chat_log_html(roomid))
        # ...

# 生成聊天记录页面
def generate_chat_log_html(self, roomid):
    messages = self.rooms.get(roomid, [])
    chat_log = '<br>'.join(messages) if messages else '<p style="color:#ccc">无聊天记录</p>'
    return f'''
<!DOCTYPE html>
<html lang="zh-Hans">
<head>
    <meta charset="UTF-8">
    <title>聊天记录 - {roomid}</title>
    <meta name="viewport" content="width=192, initial-scale=1.0">
    <meta http-equiv="refresh" content="60">
</head>
<body style="font-family: Arial, sans-serif;">
    <span>
        {chat_log}
    </span>
</body>
</html>
'''.encode('utf-8')
```

用户界面：

```
聊天室 - {房间号}

(聊天记录)
(聊天记录)
(聊天记录)
(聊天记录)
(聊天记录)

{昵称}说：_______________

[发送]  [返回]
```

1. 聊天记录区，发送消息，退出键返回主页。
2. 客户端每60秒自动获取聊天记录。发送消息后刷新聊天记录。

### 设置

用户界面：

```
设置

设置服务器地址和端口{当前值}：_______________
是否使用 dialog {当前值}：[是]  [否]
还原默认设置{否}：[是]  [否]

[保存更改并返回]  [不保存并返回]
```
