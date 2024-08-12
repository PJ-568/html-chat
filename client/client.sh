#!/bin/bash

ZENITY_AVAL="true"
DIALOG_AVAL="true"

for i in "$*"; do
    if [ "$i" = "--zenity" ]; then
        ZENITY_AVAL="true"
        DIALOG_AVAL="false"
    elif [ "$i" = "--dialog" ]; then
        ZENITY_AVAL="false"
        DIALOG_AVAL="true"
    elif [ "$i" = "--cli" ]; then
        ZENITY_AVAL="false"
        DIALOG_AVAL="false"
    fi
done

# 检查依赖
if [ "$ZENITY_AVAL" = "true" ]; then
    zenity --version > /dev/null 2>&1 || { echo >&2 "安装 zenity 以获得更佳体验。"; ZENITY_AVAL="false"; }
fi
if [ "$DIALOG_AVAL" = "true" ]; then
    dialog --version > /dev/null 2>&1 || { echo >&2 "安装 dialog 以获得更佳体验。"; DIALOG_AVAL="false"; }
fi
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

# 公用函数

## 计时器归零
times_down_to_zero() {
    echo 0 > $COUNTING
}

times_down_to_zero

## 计时器
times_down() {
    if [ $(($(cat $COUNTING))) -eq 0 ]; then
        (
            echo 60 > $COUNTING
            while [ $(($(cat $COUNTING))) -gt 0 ]; do
                NUM=$(($(cat $COUNTING)))
                ((NUM--))
                echo $NUM > $COUNTING
                sleep 1
            done
            times_down_to_zero
        ) &
    fi
}

## 保存设置
save_settings() {
    echo "保存设置。"
    echo "# 昵称 房间号 服务器地址" > "$SETTINGS_FILE"
    echo "$NICKNAME" >> "$SETTINGS_FILE"
    echo "$ROOM_ID" >> "$SETTINGS_FILE"
    echo "$SERVER_ADDRESS" >> "$SETTINGS_FILE"
}

## 加载设置
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

# zenity 模式

## 显示主页
show_home() {
    while true; do
        RESPONSE=$(zenity --list --title="聊天室" --width=400 --height=400 --text="昵称：$NICKNAME\n房间号：$ROOM_ID\n请选择操作。" --column="选项" \ "进入房间" "更新昵称和房间号" "设置" "退出")

        case $? in
            0)
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
            ;;
            1)
                exit 0
            ;;
            -1)
                zenity --error --text="发生意外错误。软件即将退出。"
                exit 1
            ;;
        esac
    done
}

## 更新昵称和房间号
edit_info() {
    RESPONSE=$(zenity --forms --title="聊天室 - 更新信息" --text="更新昵称和房间号，留空则维持原样" --separator="|" --add-entry="昵称（$NICKNAME）：" --add-entry="房间号（$ROOM_ID）：")

    case $? in
         0)
            IFS='|'
            read -ra ADDR <<< "$RESPONSE"

            NICKNAME=${ADDR[0]:-"$NICKNAME"}
            ROOM_ID=${ADDR[1]:-"$ROOM_ID"}
            printf "已更新昵称和房间号：\n- 昵称：$NICKNAME\n- 房间号：$ROOM_ID\n"
            times_down_to_zero
            save_settings
            return 0
        ;;
         1)
            return 0
        ;;
        -1)
            zenity --error --text="发生意外错误。"
            return 1
        ;;
    esac
    return 1
}

## 显示聊天室
show_chat_room() {
    while true; do
        # 获取聊天记录
        if [ $(($(cat $COUNTING))) -eq 0 ]; then
            (
                RESPONSE=$(curl -G -s --data-urlencode "id=$ROOM_ID" "$SERVER_ADDRESS/log")
                echo "60"
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
            case $? in
                1)
                    return 0
                ;;
                -1)
                    zenity --error --text="发生意外错误。"
                    return 2
                ;;
            esac
        else
            echo "从缓存读取聊天记录……"
        fi
        CHAT_LOG=$(cat "$TEMP_FILE")

        # 判断聊天记录是否正常获取
        if [ -z "$CHAT_LOG" ]; then
            printf "无法获取聊天记录！\n请检查网络链接和服务器地址设置。\n"
            zenity --error --text="无法获取聊天记录！\n请检查网络链接和服务器地址设置。"
            times_down_to_zero
            return 1
        else
            times_down
            printf "聊天记录：\n$CHAT_LOG\n"
        fi

        # 显示聊天记录
        TIMEOUT=$(($(cat $COUNTING)))
        if [ $TIMEOUT -eq 0 ]; then
            TIMEOUT=60
        fi
        ((TIMEOUT+=4))
        CHOICE=$(zenity --list --title="聊天室 - $ROOM_ID" --width=400 --height=400 --timeout=$TIMEOUT --text="可选操作和聊天记录：" --column="选项和消息" \ "发送消息" "返回主页" "$CHAT_LOG")

        case $? in
            0)
                case $CHOICE in
                    "发送消息")
                        send_a_message
                    ;;
                    "返回主页")
                        return 0
                    ;;
                    *)
                        continue
                    ;;
                esac
            ;;
            1)
                return 0
            ;;
            5)
                continue
            ;;
            -1)
                zenity --error --text="发生意外错误。"
                return 3
            ;;
        esac
    done
}

## 发送消息
send_a_message() {
    MESSAGE=$(zenity --entry --title="聊天室 - $ROOM_ID - 发送消息" --text="$NICKNAME 说:")

    case $? in
         0)
            if [ ! -z "$MESSAGE" ]; then
                (
                    RETURN=$(curl -o /dev/null -s -w %{http_code} -X POST --data-urlencode "nickname=$NICKNAME" --data-urlencode "roomid=$ROOM_ID" --data-urlencode "messageInput=$MESSAGE" "$SERVER_ADDRESS/send_message")
                    echo "15"
                    echo "# 正在处理信息……"
                    times_down_to_zero
                    echo "25"
                    ech
                    if [ "$RETURN" = "302" ]; then
                        echo "" > "$TEMP_FILE"
                    else
                        echo "$RETURN" > "$TEMP_FILE"
                    fi
                    echo "已发送消息：$RETURN"
                    echo "100"
                ) |
                zenity --progress --title="聊天室 - $ROOM_ID - 发送消息中" --text="正在发送消息……" --percentage=5 --auto-close
            fi

            # 判断发送是否成功
            ERR_CODE=$(cat "$TEMP_FILE")
            if [ ! -z "$ERR_CODE" ]; then
                printf "消息发送失败：\n- 错误代码：$ERR_CODE\n"
                zenity --error --text="消息发送失败：\n错误代码：$ERR_CODE"
                send_a_message
            else
                # 返回聊天室
                show_chat_room
            fi
        ;;
         1)
            show_chat_room
        ;;
        -1)
            zenity --error --text="发生意外错误。"
        ;;
    esac
}

## 设置
show_settings() {
    RESPONSE=$(zenity --forms --title="聊天室 - 设置" --text="修改设置" --separator="|" --add-entry="服务器地址和端口（$SERVER_ADDRESS）：")

    case $? in
         0)
            IFS='|'
            read -ra ADDR <<< "$RESPONSE"

            SERVER_ADDRESS=${ADDR[0]:-"https://chat.serv.pj568.sbs"}
            printf "已修改设置：\n- 服务器地址和端口：$SERVER_ADDRESS\n"
            save_settings
            show_home
        ;;
         1)
            show_home
        ;;
        -1)
            zenity --error --text="发生意外错误。"
        ;;
    esac
}

# dialog 模式

## 显示主页 - dialog
show_home-dialog() {
    # 定义对话框的内容
    local DIALOG_CONTENT="昵称：$NICKNAME\n房间号：$ROOM_ID\n请选择操作。"

    # 定义选项
    local OPTIONS=(
        "1" "进入房间"
        "2" "更新昵称和房间号"
        "3" "设置"
        "4" "退出"
    )

    # 使用 dialog 创建选择列表
    CHOICE=$(dialog --backtitle "聊天室" \
                    --title "聊天室" \
                    --menu "$DIALOG_CONTENT" 15 60 4 \
                    "${OPTIONS[@]}" 2>&1 >/dev/tty)

    # 根据用户的选择执行相应的操作
    case "$CHOICE" in
        "1")
            show_chat_room-dialog
        ;;
        "2")
            edit_info-dialog
        ;;
        "3")
            show_settings
        ;;
        "4")
            save_settings
            exit 0
        ;;
        "")
            # 如果用户点击了取消按钮
            exit 0
        ;;
        *)
            dialog --msgbox "请选择一个选项。" 8 30
            show_home
        ;;
    esac
}

## 更新昵称和房间号 - dialog
edit_info-dialog() {
    # 定义对话框的标题
    DIALOG_TITLE="聊天室 - 更新信息"

    # 定义对话框的内容
    DIALOG_CONTENT="更新昵称和房间号，留空则维持原样"

    # 创建输入字段
    NEW_NICKNAME=$(dialog --backtitle "$DIALOG_TITLE" \
                          --title "更新昵称" \
                          --inputbox "留空以保持现有状态。\n昵称（$NICKNAME）：" 8 60 3>&1 1>&2 2>&3)
    exit_status=$?

    if [ $exit_status -eq 0 ]; then
        NEW_ROOM_ID=$(dialog --backtitle "$DIALOG_TITLE" \
                             --title "更新房间号" \
                             --inputbox "留空以保持现有状态。\n房间号（$ROOM_ID）：" 8 60 3>&1 1>&2 2>&3)
        exit_status=$?
    fi

    if [ $exit_status -eq 0 ]; then
        # 用户输入了新的昵称或房间号
        NICKNAME=${NEW_NICKNAME:-"$NICKNAME"}
        ROOM_ID=${NEW_ROOM_ID:-"$ROOM_ID"}

        # 显示更新的信息
        dialog --msgbox "已更新昵称和房间号：\n- 昵称：$NICKNAME\n- 房间号：$ROOM_ID" 10 60

        # 保存设置并返回主页
        times_down_to_zero
        save_settings
        show_home-dialog
    elif [ $exit_status -eq 1 ]; then
        # 用户点击了取消按钮
        show_home-dialog
    else
        # 发生了错误
        dialog --error "发生意外错误。"
    fi
}

## 显示聊天室 - dialog（有毛病）
show_chat_room-dialog() {
    # 获取聊天记录
    if [ $(($(cat $COUNTING))) -eq 0 ]; then
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
        ) &
        pid=$!
        while kill -0 $pid > /dev/null 2>&1; do
            dialog --progressbox "正在获取聊天记录……" 10 60 0 100
            sleep 1
        done
        wait $pid
        case $? in
            1)
                show_home-dialog
            ;;
            -1)
                dialog --msgbox "发生意外错误。" 8 30
            ;;
        esac
    else
        echo "从缓存读取聊天记录……"
    fi
    CHAT_LOG=$(cat "$TEMP_FILE")

    # 判断聊天记录是否正常获取
    if [ -z "$CHAT_LOG" ]; then
        printf "无法获取聊天记录！\n请检查网络链接和服务器地址设置。\n"
        dialog --msgbox "无法获取聊天记录！\n请检查网络链接和服务器地址设置。" 10 60
        times_down_to_zero
        show_home-dialog
    else
        times_down
        printf "聊天记录：\n$CHAT_LOG\n"

        # 显示聊天记录
        TIMEOUT=$(($(cat $COUNTING)))
        if [ $TIMEOUT -eq 0 ]; then
            TIMEOUT=60
        fi
        ((TIMEOUT+=4))

        # 使用 dialog 创建列表对话框
        CHOICE=$(dialog --backtitle "聊天室 - $ROOM_ID" \
                        --title "聊天记录" \
                        --ok-label "发送消息" \
                        --cancel-label "返回主页" \
                        --extra-button --extra-label "刷新" \
                        --textbox "$TEMP_FILE" 15 60 2>&1 >/dev/tty)

        case $? in
            0)  # 发送消息
                send_a_message
            ;;
            1)  # 返回主页
                show_home
            ;;
            2)  # 刷新
                show_chat_room
            ;;
            255)  # 取消或关闭对话框
                show_home
            ;;
            *)
                dialog --msgbox "发生意外错误。" 8 30
            ;;
        esac
    fi
}

# cli 模式

## 显示主页 - cli
show_home-cli() {
    while true; do
        echo "==聊天室=="
        printf "- 昵称：$NICKNAME\n- 房间号：$ROOM_ID\n"
        echo "1. 进入房间"
        echo "2. 更新昵称和房间号"
        echo "3. 设置"
        echo "4. 退出"
        printf "请选择操作："

        read choice

        if [ "$choice" -eq 1 ]; then
            show_chat_room-cli
        elif [ "$choice" -eq 2 ]; then
            edit_info-cli
        elif [ "$choice" -eq 3 ]; then
            show_settings
        elif [ "$choice" -eq 4 ]; then
            save_settings
            exit 0
        else
            echo "选择无效，请重新选择："
        fi
    done
}

## 更新昵称和房间号
edit_info-cli() {
    # 是否有更新内容
    is_updated=0
    echo "==聊天室 - 更新信息=="
    printf "- 当前昵称：$NICKNAME\n请输入新的昵称，留空则维持原样。\n新昵称："

    read choice0

    if [ ! -z "$choice0" ]; then
        NICKNAME="$choice0"
        is_updated=1
    fi

    echo "==聊天室 - 更新信息=="
    printf "- 当前房间号：$ROOM_ID\n请输入新的房间号，留空则维持原样。\n新房间号："

    read choice1

    if [ ! -z "$choice1" ]; then
        ROOM_ID="$choice1"
        is_updated=1
    fi

    if [ $is_updated -eq 1 ]; then
        printf "已更新昵称和房间号：\n- 昵称：$NICKNAME\n- 房间号：$ROOM_ID\n"
        times_down_to_zero
        save_settings
    fi
    return 0
}

## 显示聊天室
show_chat_room-cli() {
    while true; do
        # 获取聊天记录
        if [ $(($(cat $COUNTING))) -eq 0 ]; then
            RESPONSE=$(curl -G -s --data-urlencode "id=$ROOM_ID" "$SERVER_ADDRESS/log")
            if [[ $RESPONSE =~ \<span\>(.*)\<\/span\> ]]; then
                CHAT_LOG="${BASH_REMATCH[1]}"
                CHAT_LOG=$(echo "$CHAT_LOG" | sed 's/<br>/\n/g' | sed 's/<[^>]*>//g')
            fi
        else
            echo "从缓存读取聊天记录……"
        fi

        # 判断聊天记录是否正常获取
        if [ -z "$CHAT_LOG" ]; then
            printf "无法获取聊天记录！\n请检查网络链接和服务器地址设置。\n"
            zenity --error --text="无法获取聊天记录！\n请检查网络链接和服务器地址设置。"
            times_down_to_zero
            return 1
        fi
        times_down

        # 显示聊天记录
        echo "==聊天室 - $ROOM_ID=="
        printf "$CHAT_LOG"
        echo "1. 发送消息"
        echo "2. 刷新消息"
        echo "3. 返回主页"
        printf "请选择操作："

        read choice

        if [ "$choice" -eq 1 ]; then
            send_a_message
        elif [ "$choice" -eq 2 ]; then
            continue
        elif [ "$choice" -eq 3 ]; then
            return 0
        else
            echo "选择无效，请重新选择："
        fi
    done
}

# 主程序入口
load_settings
if [ "$ZENITY_AVAL" = "true" ]; then
    show_home
elif [ "$DIALOG_AVAL" = "true" ]; then
    show_home-dialog
else
    show_home-cli
fi