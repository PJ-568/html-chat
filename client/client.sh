#!/bin/bash

# 检查依赖
zenity --version > /dev/null 2>&1 || { echo >&2 "请先安装 zenity 以继续使用。"; exit 1; }
curl --version > /dev/null 2>&1 || { zenity --warning --text="请先安装 curl 以继续使用。"; exit 1; }
mkdir --version > /dev/null 2>&1 || { zenity --warning --text="请先安装 mkdir 以继续使用。"; exit 1; }
sed --version > /dev/null 2>&1 || { zenity --warning --text="请先安装 sed 以继续使用。"; exit 1; }
mktemp --version > /dev/null 2>&1 || { zenity --warning --text="请先安装 mktemp 以继续使用。"; exit 1; }
cat --version > /dev/null 2>&1 || { zenity --warning --text="请先安装 cat 以继续使用。"; exit 1; }
grep --version > /dev/null 2>&1 || { zenity --warning --text="请先安装 grep 以继续使用。"; exit 1; }

# 设置文件路径
SETTINGS_FILE="${HOME}/.config/html-chat-gtk/setting.txt"

# 创建配置目录
mkdir -p "${HOME}/.config/html-chat-gtk"

# 默认值
NICKNAME="匿名"
ROOM_ID="默认"
SERVER_ADDRESS="https://chat.serv.pj568.sbs"

# 全局变量
TEMP_FILE=$(mktemp)
## 用于记录当前是否正在执行计时
COUNTING=$(mktemp)
echo 0 > $COUNTING

time_downs() {
    if [ $(($(cat $COUNTING))) -ne 0 ]; then
        echo 60 > $COUNTING
        return
    else
        (
            echo 60 > $COUNTING
            while [ $(($(cat $COUNTING))) -gt 0 ]; do
                NUM=$(($(cat $COUNTING)))
                ((NUM--))
                echo $NUM > $COUNTING
                sleep 1
            done
            echo 0 > $COUNTING
        ) &
    fi
}

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
        *)
            zenity --info --text="请选择一个选项。"
            show_home
        ;;
    esac
}

# 更新昵称和房间号
edit_info() {
    RESPONSE=$(zenity --forms --title="聊天室 - 更新信息" --text="更新昵称和房间号，留空则维持原样" --separator="|" --add-entry="昵称（$NICKNAME）：" --add-entry="房间号（$ROOM_ID）：")
    
    if [ "$?" = 1 ] ; then
        show_home
    fi

    IFS='|'
    read -ra ADDR <<< "$RESPONSE"

    NICKNAME=${ADDR[0]:-"$NICKNAME"}
    ROOM_ID=${ADDR[1]:-"$ROOM_ID"}
    printf "已更新昵称和房间号：\n- 昵称：$NICKNAME\n- 房间号：$ROOM_ID\n"
    echo 0 > $COUNTING
    save_settings
    show_home
}

# 显示聊天室
show_chat_room() {
    if [ $(($(cat $COUNTING))) -eq 0 ]; then
        # 获取聊天记录
        (
            RESPONSE=$(curl -G -s --data-urlencode "id=$ROOM_ID" "$SERVER_ADDRESS/log")
            echo "65"
            echo "已请求聊天记录信息：$RESPONSE"
            echo "70"
            echo "# 正在格式化信息……"
            if [[ $RESPONSE =~ \<span\>(.*)\<\/span\> ]]; then
                echo "85"
                export CHAT_LOG="${BASH_REMATCH[1]}"
                echo "90"
                export CHAT_LOG=$(echo "$CHAT_LOG" | sed 's/<br>/\n/g' | sed 's/<[^>]*>//g')
            fi
            echo "# 正在记录日志……"
            echo "$CHAT_LOG" > "$TEMP_FILE"
            echo "100"
        ) |
        zenity --progress --title="进入聊天室 - $ROOM_ID" --text="正在获取聊天记录……" --percentage=30 --auto-close
        if [ "$?" = 1 ] ; then
            show_home
        fi
        time_downs
    else
        echo "从缓存读取聊天记录……"
    fi
    CHAT_LOG=$(cat "$TEMP_FILE")

    if [ -z "$CHAT_LOG" ]; then
        printf "无法获取聊天记录！\n请检查网络链接和服务器地址设置。\n"
        zenity --error --text="无法获取聊天记录！\n请检查网络链接和服务器地址设置。"
        show_home
    fi

    # 显示聊天记录
    CHOICE=$(zenity --list --title="聊天室 - $ROOM_ID" --width=400 --height=400 --text="聊天记录和可选操作：" --column="选项" "发送消息" "刷新消息" "返回主页" "$CHAT_LOG")

    if [ "$?" = 1 ] ; then
        show_home
    fi
    case $CHOICE in
        "发送消息")
            send_a_message
        ;;
        "刷新消息")
            echo 0 > $COUNTING
            show_chat_room
        ;;
        "返回主页")
            show_home
        ;;
        *)
            show_chat_room
        ;;
    esac
}

# 发送消息
send_a_message() {
    MESSAGE=$(zenity --entry --title="聊天室 - $ROOM_ID - 发送消息" --text="$NICKNAME 说:")

    if [ ! -z "$MESSAGE" ]; then
        (
            RETURN=$(curl -s -X POST --data-urlencode "nickname=$NICKNAME" --data-urlencode "roomid=$ROOM_ID" --data-urlencode "messageInput=$MESSAGE" "$SERVER_ADDRESS/send_message")
            echo "25"
            echo "# 正在记录日志……"
            echo 0 > $COUNTING
            echo "已发送消息：$RETURN"
            echo "100"
        ) |
        zenity --progress --title="聊天室 - $ROOM_ID - 发送消息中" --text="正在发送消息……" --percentage=15 --auto-close
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