#!/bin/sh

# 检查 curl 是否已安装
command -v curl > /dev/null 2>&1 || { echo >&2 "curl 未找到。请先安装 curl 才能继续。"; 
exit 1; }

# 检查 dialog 是否已安装
DIALOG_INSTALLED=false
if ! command -v dialog > /dev/null 2>&1; then
    echo >&2 "dialog 未找到。建议安装以获得更好体验。"
else
    DIALOG_INSTALLED=true
fi

# 设置默认昵称为“匿名”
NICKNAME=匿名
# 设置服务器地址和端口
SERVER=https://chat.serv.pj568.sbs:80

# 函数：设置昵称
set_nickname() {
    if [ "$DIALOG_INSTALLED" = true ]; then
        NICKNAME=$(dialog --inputbox "请输入你的昵称（默认为‘匿名’）: " 10 60 2>/dev/null)
        [ -z "$NICKNAME" ] && NICKNAME=匿名
    else
        echo -n "请输入你的昵称（默认为‘匿名’）: "
        read NICKNAME
        [ -z "$NICKNAME" ] && NICKNAME=匿名
    fi
}

# 函数：加入或创建聊天室
join_or_create_room() {
    echo -n "请输入聊天室号码（ID）: "
    read ROOM_ID
    echo -n "已进入聊天室 $ROOM_ID"
    while : ; do
        echo ""
        echo "1. 发送消息"
        echo "2. 查看聊天室消息"
        echo "3. 退出聊天室"
        echo -n "请选择一个操作: "
        read CHOICE

        case $CHOICE in
            1)
                send_message
                ;;
            2)
                get_messages
                ;;
            3)
                leave_room
                break
                ;;
            *)
                echo "无效的选择，请重新输入！"
                ;;
        esac
    done
}

# 函数：发送消息
send_message() {
    echo -n "请输入你的消息: "
    read MESSAGE
    echo "{\"message\": \"$MESSAGE\", \"roomId\": \"$ROOM_ID\"}" | curl -s -X POST "$SERVER/send" -d @-
}

# 函数：获取聊天室消息
get_messages() {
    curl -s "$SERVER/messages?roomId=$ROOM_ID"
}

# 函数：退出聊天室
leave_room() {
    echo "{\"roomId\": \"$ROOM_ID\"}" | curl -s -X POST "$SERVER/leave" -d @-
}

# 函数：修改服务器和端口
modify_server_and_port() {
    echo -n "请输入新的服务器地址（例如：https://new.chat.serv:80）: "
    read SERVER
}

# 函数：恢复默认服务器和端口
reset_server_and_port() {
    SERVER=https://chat.serv.pj568.sbs:80
}

# 主循环
while : ; do
    echo "欢迎来到聊天室客户端！"
    echo "1. 设置昵称"
    echo "2. 加入或创建聊天室"
    echo "3. 修改服务器和端口"
    echo "4. 恢复默认服务器和端口"
    echo "5. 退出程序"
    echo -n "请选择一个操作: "
    read CHOICE

    case $CHOICE in
        1)
            set_nickname
            ;;
        2)
            join_or_create_room
            ;;
        3)
            modify_server_and_port
            ;;
        4)
            reset_server_and_port
            ;;
        5)
            exit 0
            ;;
        *)
            echo "无效的选择，请重新输入！"
            ;;
    esac
done