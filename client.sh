#!/bin/bash

# 加载配置
source config.ini

# 主页界面
show_home_page() {
    dialog --title "聊天室" \
        --form "请选择操作:" 0 0 \
        0 "昵称:" 1 1 "$NICKNAME" 1 15 20 \
        1 "房间号:" 2 1 "$ROOM_ID" 2 15 20 \
        2 "" 3 1 "" 3 1 "" \
        3 "进入房间" 4 1 "" 4 1 "" \
        4 "设置" 5 1 "" 5 1 "" \
        5 "退出" 6 1 "" 6 1 ""
    case $? in
        3) show_settings ;;
        4) enter_room ;;
        5) exit ;;
    esac
}
# show_home_page() {
#     local nickname=$(dialog --stdout --inputbox "请输入昵称：" 10 60)
#     local room_id=$(dialog --stdout --inputbox "请输入房间号：" 10 60)

#     NICKNAME=${nickname:-"匿名"}
#     ROOM_ID=${room_id:-"默认"}

#     dialog --title "聊天室" \
#            --menu "请选择操作:" 0 0 0 \
#            "1" "进入房间" \
#            "2" "设置" \
#            "3" "退出"
#     case $? in
#         1) enter_room ;;
#         2) show_settings ;;
#         3) exit ;;
#     esac
# }

# 设置界面
show_settings() {
    local server_address=$(dialog --stdout --inputbox "设置服务器地址和端口：" 10 60 $SERVER_ADDRESS)
    local use_dialog=$(dialog --stdout --radiolist "是否使用 dialog：" 10 60 4 "yes" "是" on "no" "否" off)
    local reset_default=$(dialog --stdout --checklist "还原默认设置：" 10 60 1 "reset" "是" off)
    
    if [[ $server_address ]]; then
        SERVER_ADDRESS=$server_address
    fi
    if [[ $use_dialog == "yes" ]]; then
        USE_DIALOG=true
    else
        USE_DIALOG=false
    fi
    if [[ $reset_default == "reset" ]]; then
        # Reset to default settings
        source defaults.ini
    fi
    
    echo "Settings updated."
}

# 进入房间
enter_room() {
    while true; do
        local message=$(dialog --stdout --inputbox "输入消息：" 10 60)
        if [[ $message ]]; then
            curl -X POST -d "nickname=$NICKNAME&roomid=$ROOM_ID&messageInput=$message" http://$SERVER_ADDRESS/send_message
            sleep 1
        fi
        
        local log=$(curl -s "http://$SERVER_ADDRESS/log?id=$ROOM_ID")
        dialog --msgbox "$log" 0 0
    done
}

# 执行主页界面
show_home_page