#!/bin/bash

ZENITY_AVAL=1
DIALOG_AVAL=1
LANG_SET=0
IS_HELPER=0
CURRENT_LANG=0

for i in $@; do
    if [ "$i" == "--en" ]; then
        CURRENT_LANG=0
        LANG_SET=1
    elif [ "$i" == "--zh" ]; then
        CURRENT_LANG=1
        LANG_SET=1
    elif [ "$i" == "--zenity" -o "$i" == "-z" ]; then
        ZENITY_AVAL=1
        DIALOG_AVAL=0
    elif [ "$i" == "--dialog" -o "$i" == "-d" ]; then
        ZENITY_AVAL=0
        DIALOG_AVAL=1
    elif [ "$i" == "--cli" -o "$i" == "-c" ]; then
        ZENITY_AVAL=0
        DIALOG_AVAL=0
    elif [ "$i" == "--version" -o "$i" == "-v" ]; then
        echo "$0 v$VERSION"
        exit 0
    elif [ "$i" == "--help" -o "$i" == "-h" ]; then
        IS_HELPER=1
    fi
done

# 语言相关

## 语言检测

if [ ! $LANG_SET == 1 ]; then
    if [ $(echo ${LANG/_/-} | grep -Ei "\\b(zh|cn)\\b") ]; then CURRENT_LANG=1; fi
fi

## 本地化
recho() {
    if [ $CURRENT_LANG == 1 ]; then
        ### zh-Hans
        echo $1;
    else
        ### en-US
        echo $2;
    fi
}

## 文本初始化

### 公共

#### 基本信息

SOFTWARE_NAME="$(recho "LB 聊天室" "LB-Chat")"
VERSION="0.1.0"

#### 提示

P_SELECT="$(recho "请选择操作。" "Please select an option.")"
P_OPTIN="$(recho "选项" "Options")"
P_SETTINGS="$(recho "设置" "Settings")"
P_BACK="$(recho "返回" "Back")"
P_EXIT="$(recho "退出" "Exit")"
P_FORMATTING="$(recho "正在格式化信息……" "Formatting information...")"
P_LOGGING="$(recho "正在记录日志……" "Logging...")"

#### 错误提示

E_ERR="$(recho "错误" "Error")"
E_TEXT="$(recho "发生意外错误。" "An unexpected error has occurred.")"
E_EXIT="$(recho "发生意外错误。软件即将退出。" "An unexpected error has occurred. The software will exit.")"
E_NETWORK="$(recho "请检查网络链接和服务器地址设置。" "Please check your network connection and server address settings.")"
E_CODE="$(recho "错误代码：" "Error code: ")"
E_INVALID="$(recho "无效输入。" "Invalid input.")"

### 主页

H_SHOW_NICKNAME="$(recho "昵称：" "Nickname: ")"
H_SHOW_ROOM="$(recho "房间号：" "Room ID: ")"
H_ENTER_ROOM="$(recho "进入房间" "Enter Chat Room")"
H_UPD_INFO="$(recho "更新昵称和房间号" "Update Nickname and Room ID")"

### 更新档案

U_TITLE="$(recho "更新信息" "Update Info")"
U_TIC="$(recho "请输入新的信息，留空则维持原样。" "Please enter new info, leave blank to keep the original one.")"
U_SHOW_NICKNAME="$(recho "昵称：" "Nickname: ")"
U_UPD="$(recho "已更新：" "Updated:")"

### 聊天室

C_ENTERING="$(recho "进入聊天室" "Loading Chat Room")"
C_LOAD_HIS="$(recho "正在获取聊天记录……" "Loading chat history...")"
C_LOAD_HIS_CACHE="$(recho "从缓存读取聊天记录……" "Loading from cache...")"
C_FAIL_LOAD="$(recho "无法获取聊天记录！" "Failed to load chat history!")"
C_LOADED="$(recho "已获取聊天记录。" "Chat history loaded.")"
C_TEXT="$(recho "可选操作和聊天记录：" "Optional operations and chat history:")"
C_OPRIONS_AND_MSG="$(recho "选项和消息" "Options and Messages")"
C_SEND_MSG="$(recho "发送消息" "Send Message")"
C_REFRESH="$(recho "刷新" "Refresh")"

### 发送

M_SEND="$(recho "发送" "Send")"
M_SAY="$(recho "说：" "Says: ")"
M_SENDING="$(recho "正在发送……" "Sending...")"
M_FAIL="$(recho "发送失败：" "Failed to send:")"

### 设置

S_EDIT="$(recho "编辑" "Edit")"
S_SHOW_SERVER="$(recho "服务器地址和端口：" "Server Address: ")"

if [ $IS_HELPER -eq 1 ]; then
    printf "$(recho "$SOFTWARE_NAME v$VERSION\n-z --zenity\t使用 zenity 作为 UI\n-d --dialog\t使用 dialog 作为 UI\n-c --cli\t使用命令行作为 UI\n-v --version\t显示版本信息\n-h --help\t显示帮助信息\n--zh\t\t中文模式\n--en\t\t英文模式\n" "$SOFTWARE_NAME v$VERSION\n-z --zenity\tuse zenity as UI\n-d --dialog\tuse dialog as UI\n-c --cli\tuse command line as UI\n-v --version\tshow version information\n-h --help\tshow help information\n--zh\t\tChinese mode\n--en\t\tEnglish mode\n")"
    exit 0
fi

# 依赖缺失提醒
inform_dependency() {
    for i in "$*"; do
        if [ $ZENITY_AVAL -eq 1 ]; then
            zenity --warning --text="$(recho "请先安装 $i 以继续使用。" "Please install $i first to continue.")"
        elif [ $DIALOG_AVAL -eq 1 ]; then
            dialog --msgbox "$(recho "安装 zenity 以获得更佳体验。\n请先安装 $i 以继续使用。" "Install zenity for better experience.\nPlease install $i first to continue.")" 0 0
        else
            printf >&2 "$(recho "安装 zenity 或 dialog 以获得更佳体验。\n请先安装 $i 以继续使用。" "Install zenity or dialog for better experience.\nPlease install $i first to continue.")\n";
        fi
    done
    exit 1
}

# 检查依赖
if [ $ZENITY_AVAL -eq 1 ]; then
    zenity --version > /dev/null 2>&1 || { printf >&2 "$(recho "安装 zenity 以获得更佳体验。" "Install zenity for better experience.")\n"; ZENITY_AVAL=0; }
fi
if [ $DIALOG_AVAL -eq 1 ]; then
    dialog --version > /dev/null 2>&1 || { printf >&2 "$(recho "安装 dialog 以获得更佳体验。" "Install dialog for better experience.")\n"; DIALOG_AVAL=0; }
fi
curl --version > /dev/null 2>&1 || { inform_dependency "curl"; }
mkdir --version > /dev/null 2>&1 || { inform_dependency "mkdir"; }
sed --version > /dev/null 2>&1 || { inform_dependency "sed"; }
mktemp --version > /dev/null 2>&1 || { inform_dependency "mktemp"; }
cat --version > /dev/null 2>&1 || { inform_dependency "cat"; }
grep --version > /dev/null 2>&1 || { inform_dependency "grep"; }

# 设置文件路径
SETTINGS_FILE="${HOME}/.config/html-chat-gtk/setting.txt"

# 创建配置目录
mkdir -p "${HOME}/.config/html-chat-gtk"

# 用户设置默认值
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
    recho "保存设置。" "Saving settings."
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
    HOME_TEXT="$H_SHOW_NICKNAME$NICKNAME\n$H_SHOW_ROOM$ROOM_ID\n$P_SELECT"

    while true; do
        RESPONSE=$(zenity --list --title="$SOFTWARE_NAME" --width=400 --height=400 --text="$HOME_TEXT" --column="$P_OPTIN" "$H_ENTER_ROOM" "$H_UPD_INFO" "$P_SETTINGS" "$P_EXIT")

        case $? in
            0)
                case $RESPONSE in
                    "$H_ENTER_ROOM")
                        show_chat_room
                    ;;
                    "$H_UPD_INFO")
                        edit_info
                    ;;
                    "$P_SETTINGS")
                        show_settings
                    ;;
                    "$P_EXIT")
                        save_settings
                        exit 0
                    ;;
                    *)
                        zenity --info --text="$P_SELECT"
                        continue
                    ;;
                esac
            ;;
            1)
                exit 0
            ;;
            -1)
                zenity --error --text="$E_EXIT"
                exit 1
            ;;
        esac
    done
}

## 更新昵称和房间号
edit_info() {
    RESPONSE=$(zenity --forms --title="$SOFTWARE_NAME - $U_TITLE" --text="$U_TIC" --separator="|" --add-entry="[$NICKNAME]$H_SHOW_NICKNAME" --add-entry="[$ROOM_ID]$H_SHOW_ROOM")

    case $? in
         0)
            IFS='|'
            read -ra ADDR <<< "$RESPONSE"

            NICKNAME=${ADDR[0]:-"$NICKNAME"}
            ROOM_ID=${ADDR[1]:-"$ROOM_ID"}
            printf "$U_UPD\n  $H_SHOW_NICKNAME $NICKNAME\n  $H_SHOW_ROOM $ROOM_ID\n"
            times_down_to_zero
            save_settings
            return 0
        ;;
         1)
            return 0
        ;;
        -1)
            zenity --error --text="$E_TEXT"
            return 1
        ;;
    esac
    return 1
}

## 显示聊天室
show_chat_room() {
    while true; do
        ### 获取聊天记录
        if [ $(($(cat $COUNTING))) -eq 0 ]; then
            (
                RESPONSE=$(curl -G -s --data-urlencode "id=$ROOM_ID" "$SERVER_ADDRESS/log")
                echo "60"
                echo "# $P_FORMATTING"
                if [[ $RESPONSE =~ \<span\>(.*)\<\/span\> ]]; then
                    echo "85"
                    export CHAT_LOG="${BASH_REMATCH[1]}"
                    echo "90"
                    export CHAT_LOG=$(echo "$CHAT_LOG" | sed 's/<br>/\n/g' | sed 's/<[^>]*>//g')
                fi
                echo "# $P_LOGGING"
                echo "$CHAT_LOG" > "$TEMP_FILE"
                echo "100"
            ) |
            zenity --progress --title="$C_ENTERING - $ROOM_ID" --text="$C_LOAD_HIS" --percentage=30 --auto-close
            case $? in
                1)
                    return 0
                ;;
                -1)
                    zenity --error --text="$E_TEXT"
                    return 2
                ;;
            esac
        else
            echo "$C_LOAD_HIS_CACHE"
        fi
        CHAT_LOG=$(cat "$TEMP_FILE")

        ### 判断聊天记录是否正常获取
        if [ -z "$CHAT_LOG" ]; then
            echo "$C_FAIL_LOAD"
            echo "$E_NETWORK"
            zenity --error --text="$C_FAIL_LOAD\n$E_NETWORK"
            times_down_to_zero
            return 1
        else
            times_down
            echo "$C_LOADED"
        fi

        ### 显示聊天记录

        TIMEOUT=$(($(cat $COUNTING)))
        if [ $TIMEOUT -eq 0 ]; then
            TIMEOUT=60
        fi
        ((TIMEOUT+=4))
        CHOICE=$(zenity --list --title="$SOFTWARE_NAME - $ROOM_ID" --width=400 --height=400 --timeout=$TIMEOUT --text="$C_TEXT" --column="$C_OPRIONS_AND_MSG" "$C_SEND_MSG" "$P_BACK" "$CHAT_LOG")

        case $? in
            0)
                case $CHOICE in
                    "$C_SEND_MSG")
                        send_a_message
                    ;;
                    "$P_BACK")
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
                zenity --error --text="$E_TEXT"
                return 3
            ;;
        esac
    done
}

## 发送消息
send_a_message() {
    while true; do
        MESSAGE=$(zenity --entry --title="$SOFTWARE_NAME - $ROOM_ID - $M_SEND" --text="$NICKNAME $M_SAY")

        case $? in
            0)
                if [ ! -z "$MESSAGE" ]; then
                    (
                        RETURN=$(curl -o /dev/null -s -w %{http_code} -X POST --data-urlencode "nickname=$NICKNAME" --data-urlencode "roomid=$ROOM_ID" --data-urlencode "messageInput=$MESSAGE" "$SERVER_ADDRESS/send_message")
                        echo "15"
                        echo "# $P_FORMATTING"
                        times_down_to_zero
                        echo "25"
                        
                        if [ "$RETURN" == "302" ]; then
                            echo "" > "$TEMP_FILE"
                        else
                            echo "$RETURN" > "$TEMP_FILE"
                        fi
                        echo "100"
                    ) |
                    zenity --progress --title="$SOFTWARE_NAME - $ROOM_ID - $M_SENDING" --text="$M_SENDING" --percentage=5 --auto-close
                    case $? in
                        1)
                            return 0
                        ;;
                        -1)
                            zenity --error --text="$E_TEXT"
                            return 2
                        ;;
                    esac
                fi

                ### 判断发送是否成功
                ERR_CODE=$(cat "$TEMP_FILE")
                if [ ! -z "$ERR_CODE" ]; then
                    echo "$M_FAIL"
                    echo "$E_CODE$ERR_CODE"
                    zenity --error --text="$M_FAIL\n$E_CODE$ERR_CODE"
                    continue
                else
                    ### 返回聊天室
                    return 0
                fi
            ;;
            1)
                return 0
            ;;
            -1)
                zenity --error --text="$E_TEXT"
                return 1
            ;;
        esac
    done
}

## 设置
show_settings() {
    RESPONSE=$(zenity --forms --title="$SOFTWARE_NAME - $P_SETTINGS" --text="$S_EDIT $P_SETTINGS" --separator="|" --add-entry="[$SERVER_ADDRESS]$S_SHOW_SERVER")

    case $? in
         0)
            IFS='|'
            read -ra ADDR <<< "$RESPONSE"

            SERVER_ADDRESS=${ADDR[0]:-"https://chat.serv.pj568.sbs"}
            printf "$U_UPD\n  $S_SHOW_SERVER$SERVER_ADDRESS\n"
            save_settings
            return 0
        ;;
         1)
            return 0
        ;;
        -1)
            zenity --error --text="$E_TEXT"
            return 1
        ;;
    esac
}

# dialog 模式

## 显示主页 - dialog
show_home-dialog() {
    while true; do
        HOME_TEXT="$H_SHOW_NICKNAME$NICKNAME\n$H_SHOW_ROOM$ROOM_ID\n$P_SELECT"

        ### 定义选项
        local OPTIONS=(
            "1" "$H_ENTER_ROOM"
            "2" "$H_UPD_INFO"
            "3" "$P_SETTINGS"
            "4" "$P_EXIT"
        )

        ### 使用 dialog 创建选择列表
        CHOICE=$(dialog --no-cancel --backtitle "$SOFTWARE_NAME" \
            --title "$SOFTWARE_NAME" \
            --menu "$HOME_TEXT" 15 60 4 \
            "${OPTIONS[@]}" 2>&1 >/dev/tty)

        ### 根据用户的选择执行相应的操作
        case "$CHOICE" in
            "1")
                show_chat_room-dialog
            ;;
            "2")
                edit_info-dialog
            ;;
            "3")
                show_settings-cli
            ;;
            "4")
                save_settings
                exit 0
            ;;
            *)
                dialog --msgbox "$P_SELECT" 8 30
                continue
            ;;
        esac
    done
}

## 更新昵称和房间号 - dialog
edit_info-dialog() {
    while true; do
        ### 定义对话框的标题
        DIALOG_TITLE="$SOFTWARE_NAME - $U_TITLE"

        ### 创建输入字段
        NEW_NICKNAME=$(dialog --backtitle "$DIALOG_TITLE" \
            --title "$U_TITLE - $H_SHOW_NICKNAME" \
            --inputbox "$U_TIC\n[$NICKNAME]$H_SHOW_NICKNAME" 8 60 3>&1 1>&2 2>&3)
        exit_status=$?

        if [ $exit_status -eq 0 ]; then
            NEW_ROOM_ID=$(dialog --backtitle "$DIALOG_TITLE" \
                --title "$U_TITLE - $H_SHOW_ROOM" \
                --inputbox "$U_TIC\n[$ROOM_ID]$H_SHOW_ROOM" 8 60 3>&1 1>&2 2>&3)
            exit_status=$?
        fi

        if [ $exit_status -eq 0 ]; then
            ### 用户输入了新的昵称或房间号
            NICKNAME=${NEW_NICKNAME:-"$NICKNAME"}
            ROOM_ID=${NEW_ROOM_ID:-"$ROOM_ID"}

            ### 显示更新的信息
            dialog --msgbox "$U_UPD\n  $H_SHOW_NICKNAME $NICKNAME\n  $H_SHOW_ROOM $ROOM_ID" 10 60

            ### 保存设置并返回主页
            times_down_to_zero
            save_settings
            return 0
        elif [ $exit_status -eq 1 ]; then
            ### 用户点击了取消按钮
            return 0
        else
            dialog --title "$E_ERR" --msgbox "$E_TEXT" 0 0
            return 1
        fi
    done
}

## 显示聊天室 - dialog
show_chat_room-dialog() {
    while true; do
        ### 获取聊天记录
        if [ $(($(cat $COUNTING))) -eq 0 ]; then
            echo "$C_LOAD_HIS"
            RESPONSE=$(curl -G -s --data-urlencode "id=$ROOM_ID" "$SERVER_ADDRESS/log")
            if [[ $RESPONSE =~ \<span\>(.*)\<\/span\> ]]; then
                CHAT_LOG="${BASH_REMATCH[1]}"
                CHAT_LOG=$(echo "$CHAT_LOG" | sed 's/<br>/\n/g' | sed 's/<[^>]*>//g')
            fi
        else
            echo "$C_LOAD_HIS_CACHE"
        fi

        ### 判断聊天记录是否正常获取
        if [ -z "$CHAT_LOG" ]; then
            dialog --title "$E_ERR" --msgbox "$$C_FAIL_LOAD\n$E_NETWORK" 0 0
            times_down_to_zero
            return 1
        fi
        times_down

        ### 用户选择
        code=$(dialog --no-cancel --clear --title "$SOFTWARE_NAME - $ROOM_ID" \
            --menu "$(
                echo "$CHAT_LOG"
                echo
                echo "$P_SELECT"
            )" 0 0 0 \
            "1" "$C_SEND_MSG" \
            "2" "$C_REFRESH" \
            "3" "$P_BACK" 2>&1 >/dev/tty)

        case $code in
            1)
                send_a_message-dialog
            ;;
            2)
                continue
            ;;
            3)
                return 0
            ;;
            *)
                dialog --title "$E_ERR" --msgbox "$E_INVALID" 0 0
            ;;
        esac
    done
}

## 发送消息 - dialog
send_a_message-dialog() {
    message=$(dialog --clear --title "$SOFTWARE_NAME - $ROOM_ID - $M_SEND" \
        --inputbox "$NICKNAME $M_SAY" 10 60 \
        2>&1 >/dev/tty)

    if [ $? -eq 0 -o ! -z "$message" ]; then
        echo "$M_SENDING"
        RETURN=$(curl -o /dev/null -s -w %{http_code} -X POST --data-urlencode "nickname=$NICKNAME" --data-urlencode "roomid=$ROOM_ID" --data-urlencode "messageInput=$message" "$SERVER_ADDRESS/send_message")
        recho "$P_FORMATTING"
        times_down_to_zero
        
        if [ "$RETURN" == "302" ]; then
            return 0
        else
            dialog --backtitle "$RETURN" --title "$E_ERR" --msgbox "$M_FAIL\n$E_CODE$ERR_CODE" 0 0
            return $RETURN
        fi
    fi
}

# cli 模式

## 显示主页 - cli
show_home-cli() {
    printf "\ec"
    while true; do
        printf "\n==$SOFTWARE_NAME==\n"
        printf "$H_SHOW_NICKNAME$NICKNAME\n$H_SHOW_ROOM$ROOM_ID\n"
        echo "1. $H_ENTER_ROOM"
        echo "2. $H_UPD_INFO"
        echo "3. $P_SETTINGS"
        echo "4. $P_EXIT"
        printf "$P_SELECT\n> "

        read choice

        if [ "$choice" == "1" ]; then
            show_chat_room-cli
        elif [ "$choice" == "2" ]; then
            edit_info-cli
        elif [ "$choice" == "3" ]; then
            show_settings-cli
        elif [ "$choice" == "4" ]; then
            save_settings
            exit 0
        else
            echo "$E_INVALID"
        fi
    done
}

## 更新昵称和房间号 - cli
edit_info-cli() {
    printf "\ec"
    ### 是否有更新内容
    is_updated=0
    printf "\n==$SOFTWARE_NAME - $U_TITLE==\n"
    printf "$U_TIC\n[$NICKNAME]$H_SHOW_NICKNAME"

    read choice0

    if [ ! -z "$choice0" ]; then
        NICKNAME="$choice0"
        is_updated=1
    fi

    printf "\n==$SOFTWARE_NAME - $U_TITLE==\n"
    printf "$U_TIC\n[$ROOM_ID]$H_SHOW_ROOM"

    read choice1

    if [ ! -z "$choice1" ]; then
        ROOM_ID="$choice1"
        is_updated=1
    fi

    if [ $is_updated -eq 1 ]; then
        printf "$U_UPD\n  $H_SHOW_NICKNAME $NICKNAME\n  $H_SHOW_ROOM $ROOM_ID\n"
        times_down_to_zero
        save_settings
    fi
    return 0
}

## 显示聊天室 - cli
show_chat_room-cli() {
    printf "\ec"
    while true; do
        ### 获取聊天记录
        if [ $(($(cat $COUNTING))) -eq 0 ]; then
            echo "$C_LOAD_HIS"
            RESPONSE=$(curl -G -s --data-urlencode "id=$ROOM_ID" "$SERVER_ADDRESS/log")
            if [[ $RESPONSE =~ \<span\>(.*)\<\/span\> ]]; then
                CHAT_LOG="${BASH_REMATCH[1]}"
                CHAT_LOG=$(echo "$CHAT_LOG" | sed 's/<br>/\n/g' | sed 's/<[^>]*>//g')
            fi
        else
            echo "$C_LOAD_HIS_CACHE"
        fi

        ### 判断聊天记录是否正常获取
        if [ -z "$CHAT_LOG" ]; then
            printf "$C_FAIL_LOAD\n$E_NETWORK\n"
            times_down_to_zero
            return 1
        fi
        times_down

        ### 显示聊天记录
        printf "\n==$SOFTWARE_NAME - $ROOM_ID==\n"
        printf "$CHAT_LOG\n"
        echo "1. $C_SEND_MSG"
        echo "2. $C_REFRESH"
        echo "3. $P_BACK"
        printf "$P_SELECT\n> "

        read choice

        if [ "$choice" == "1" ]; then
            send_a_message-cli
        elif [ "$choice" == "2" ]; then
            continue
        elif [ "$choice" == "3" ]; then
            return 0
        else
            echo "$E_INVALID"
        fi
    done
}

## 发送消息 - cli
send_a_message-cli() {
    printf "\ec"
    printf "\n==$SOFTWARE_NAME - $ROOM_ID - $M_SEND==\n"
    echo "$U_TIC"
    printf "$NICKNAME $M_SAY"

    read message

    if [ ! -z "$message" ]; then
        echo  "$M_SENDING"
        RETURN=$(curl -o /dev/null -s -w %{http_code} -X POST --data-urlencode "nickname=$NICKNAME" --data-urlencode "roomid=$ROOM_ID" --data-urlencode "messageInput=$message" "$SERVER_ADDRESS/send_message")
        echo "$P_FORMATTING"
        times_down_to_zero
        
        if [ "$RETURN" == "302" ]; then
            return 0
        else
            printf "$M_FAIL\n  $E_CODE$RETURN\n"
            return $RETURN
        fi
    fi
}

## 设置 - cli
show_settings-cli() {
    printf "\ec"
    printf "\n==$SOFTWARE_NAME - $P_SETTINGS==\n"
    printf "$U_TIC\n[$SERVER_ADDRESS]$S_SHOW_SERVER"

    read choice0

    if [ ! -z "$choice0" ]; then
        SERVER_ADDRESS="$choice0"
    else
        SERVER_ADDRESS="https://chat.serv.pj568.sbs"
    fi

    printf "$U_UPD\n  $S_SHOW_SERVER$SERVER_ADDRESS\n"
    save_settings
    return 0
}

# 主程序入口
load_settings
if [ $ZENITY_AVAL -eq 1 ]; then
    show_home
elif [ $DIALOG_AVAL -eq 1 ]; then
    show_home-dialog
else
    show_home-cli
fi