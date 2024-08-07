#!/bin/bash

# 检查依赖
zenity --version > /dev/null 2>&1 || { echo >&2 "请先安装 zenity 以继续使用。"; exit 1; }
curl --version > /dev/null 2>&1 || { zenity --warning --text="请先安装 curl 以继续使用。"; exit 1; }
mkdir --version > /dev/null 2>&1 || { zenity --warning --text="请先安装 mkdir 以继续使用。"; exit 1; }
sed --version > /dev/null 2>&1 || { zenity --warning --text="请先安装 sed 以继续使用。"; exit 1; }

# 设置文件路径
SETTINGS_FILE="${HOME}/.config/html-chat-gtk/setting.txt"

# 创建配置目录
mkdir -p "${HOME}/.config/html-chat-gtk"

# 默认值
NICKNAME="匿名"
ROOM_ID="默认"
SERVER_ADDRESS="https://chat.serv.pj568.sbs"

# 保存设置
save_settings() {
    echo "# 昵称 房间号 服务器地址" > "$SETTINGS_FILE"
    echo "$NICKNAME" >> "$SETTINGS_FILE"
    echo "$ROOM_ID" >> "$SETTINGS_FILE"
    echo "$SERVER_ADDRESS" >> "$SETTINGS_FILE"
}

# 加载设置
load_settings() {
    if [ -f "$SETTINGS_FILE" ]; then
        mapfile -t SETTINGS < <(grep -v '^#' "$SETTINGS_FILE")
        NICKNAME=${SETTINGS[0]:-"匿名"}
        ROOM_ID=${SETTINGS[1]:-"默认"}
        SERVER_ADDRESS=${SETTINGS[2]:-"https://chat.serv.pj568.sbs"}
    else
        save_settings
    fi
}

# 加载默认值
load_settings

# 显示主页
show_home() {
    RESPONSE=$(zenity --list --title="聊天室" --width=400 --height=400 --text="昵称：$NICKNAME\n房间号：$ROOM_ID\n请选择操作。" --column="选项" "进入房间" "更新昵称和房间号" "设置" "退出")

    if [ "$?" = 1 ] ; then
        exit 0
    fi

    case $RESPONSE in
        "进入房间")
            show_chat_room
        ;;
        "更新昵称和房间号")
            edit_info
        ;;
        "设置")
            show_settings
        ;;
        "退出")
            save_settings
            exit 0
        ;;
    esac
}

# 更新昵称和房间号
edit_info() {
    RESPONSE=$(zenity --forms --title="聊天室 - 更新信息" --text="更新昵称和房间号" --separator="|" --add-entry="昵称（$NICKNAME）：" --add-entry="房间号（$ROOM_ID）：")
    IFS='|'
    read -ra ADDR <<< "$RESPONSE"

    NICKNAME=${ADDR[0]:-"匿名"}
    ROOM_ID=${ADDR[1]:-"默认"}
    printf "已更新昵称和房间号：\n- 昵称：$NICKNAME\n- 房间号：$ROOM_ID\n"
    save_settings
    show_home
}

# 显示聊天室
show_chat_room() {
    # 获取聊天记录
    # (
    #     RESPONSE=$(curl -G -s --data-urlencode "id=$ROOM_ID" "$SERVER_ADDRESS/log")
    #     echo "65"
    #     echo "已请求聊天记录信息：$RESPONSE"
    #     echo "70"
    #     if [[ $RESPONSE =~ \<span\>(.*)\<\/span\> ]]; then
    #         echo "85"
    #         export CHAT_LOG="${BASH_REMATCH[1]}"
    #         echo "90"
    #         export CHAT_LOG=$(echo "$CHAT_LOG" | sed 's/<[^>]*>//g')
    #     fi
    #     echo "100"
    # ) |
    # zenity --progress --title="进入聊天室 - $ROOM_ID" --text="正在获取聊天记录……" --percentage=30 --auto-close

    # if [ "$?" = 1 ] ; then
    #     show_home
    # fi
    RESPONSE=$(curl -G -s --data-urlencode "id=$ROOM_ID" "$SERVER_ADDRESS/log")
    echo "已请求聊天记录信息：$RESPONSE"
    if [[ $RESPONSE =~ \<span\>(.*)\<\/span\> ]]; then
        export CHAT_LOG="${BASH_REMATCH[1]}"
        export CHAT_LOG=$(echo "$CHAT_LOG" | sed 's/<br>/\n/g' | sed 's/<[^>]*>//g')
    fi

    if [ -z "$CHAT_LOG" ]; then
        zenity --error --text="无法获取聊天记录！"; exit 2;
    fi

    # 显示聊天记录
    CHOICE=$(zenity --list --title="聊天室 - $ROOM_ID" --width=400 --height=400 --text="$ROOM_ID 的聊天记录：\n\n$CHAT_LOG\n\n请选择操作。" --column="选项" "发送消息" "刷新消息" "返回主页")

    if [ "$?" = 1 ] ; then
        show_home
    fi
    case $CHOICE in
        "发送消息")
            send_a_message
        ;;
        "刷新消息")
            show_chat_room
        ;;
        "返回主页")
            show_home
        ;;
    esac
}

# 发送消息
send_a_message() {
    MESSAGE=$(zenity --entry --title="聊天室 - $ROOM_ID - 发送消息" --text="$NICKNAME 说:")

    if [ ! -z "$MESSAGE" ]; then
        RETURN=$(curl -s -X POST --data-urlencode "nickname=$NICKNAME" --data-urlencode "roomid=$ROOM_ID" --data-urlencode "messageInput=$MESSAGE" "$SERVER_ADDRESS/send_message")
        echo "已发送消息：$RETURN"
    fi
    # 返回聊天室
    show_chat_room
}

# 设置
show_settings() {
    RESPONSE=$(zenity --forms --title="聊天室 - 设置" --text="修改设置" --separator="|" --add-entry="服务器地址和端口（$SERVER_ADDRESS）：")
    
    if [ "$?" = 1 ] ; then
        show_home
    fi

    IFS='|'
    read -ra ADDR <<< "$RESPONSE"

    SERVER_ADDRESS=${ADDR[0]:-"https://chat.serv.pj568.sbs"}
    printf "已修改设置：\n- 服务器地址和端口：$SERVER_ADDRESS\n"
    save_settings
    show_home
}

# 主程序入口
show_home