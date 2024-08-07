#!/bin/sh

# 默认值
DEFAULT_NICKNAME="匿名"
DEFAULT_ROOM_ID="默认"

# 函数定义
show_home() {
    # 显示主页
    NICKNAME=$(zenity --entry --title="聊天室" --text="请输入您的昵称" --entry-text="$DEFAULT_NICKNAME")
    ROOM_ID=$(zenity --entry --title="聊天室" --text="请输入聊天室ID" --entry-text="$DEFAULT_ROOM_ID")

    if [ -z "$NICKNAME" ]; then
        NICKNAME=$DEFAULT_NICKNAME
    fi

    if [ -z "$ROOM_ID" ]; then
        ROOM_ID=$DEFAULT_ROOM_ID
    fi

    OPTIONS=("进入房间" "设置" "退出")
    RESPONSE=$(zenity --list --title="聊天室" --text="请选择操作" --column="选项" "${OPTIONS[@]}")

    case $RESPONSE in
        "进入房间")
            show_chat_room "$NICKNAME" "$ROOM_ID"
            ;;
        "设置")
            show_settings
            ;;
        "退出")
            exit 0
            ;;
    esac
}

show_chat_room() {
    # 显示聊天室
    NICKNAME=$1
    ROOM_ID=$2

    # 获取聊天记录
    CHAT_LOG=$(curl -s "http://localhost:8000/log?id=$ROOM_ID")

    # 显示聊天记录
    zenity --text-info --title="聊天室 - $ROOM_ID" --width=400 --height=400 --editable --text="$CHAT_LOG"

    # 输入消息
    MESSAGE=$(zenity --entry --title="聊天室 - $ROOM_ID" --text="$NICKNAME 说:")

    if [ ! -z "$MESSAGE" ]; then
        # 发送消息
        curl -s -X POST -d "nickname=$NICKNAME&roomid=$ROOM_ID&messageInput=$MESSAGE" http://localhost:8000/send_message
        # 刷新聊天记录
        show_chat_room "$NICKNAME" "$ROOM_ID"
    fi
}

show_settings() {
    # 显示设置
    SERVER_ADDRESS=$(zenity --entry --title="设置" --text="设置服务器地址和端口" --entry-text="http://localhost:8000")
    USE_DIALOG=$(zenity --question --title="设置" --text="是否使用 dialog?" --no-button="否" --yes-button="是")
    RESET_DEFAULTS=$(zenity --question --title="设置" --text="还原默认设置?" --no-button="否" --yes-button="是")

    # 处理设置
    # ...
}

# 主程序入口
show_home