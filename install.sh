#!/bin/bash

# 定义颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

INSTALL_DIR="$HOME/nodetool"
BINARY_NAME="NodeTool"
SERVICE_NAME="nodetool"
PORT=5000
LOG_FILE="$INSTALL_DIR/server.log"

echo -e "${GREEN}=============================================${NC}"
echo -e "${GREEN}      NodeTool 安装/更新脚本 (Debug版)       ${NC}"
echo -e "${GREEN}=============================================${NC}"

# ---------------------------------------------------------
# 辅助函数：检查并卸载旧版本 (Clean Install)
# ---------------------------------------------------------
function check_and_uninstall_if_exists() {
    local SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
    local CONTROL_SCRIPT_PATH="/usr/local/bin/nt"

    if [ -f "$SERVICE_FILE" ] || [ -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}--- 检测到 NodeTool 已安装 ---${NC}"
        read -r -p "是否要完全卸载旧版本并重新安装？(这将删除所有旧文件和数据库) [y/N] " response
        
        if [[ "$response" =~ ^([yY])$ ]]; then
            echo -e "${RED}执行完全卸载...${NC}"
            
            # 确保有权限执行命令
            local PREFIX=""
            if [ "$EUID" -ne 0 ] && command -v sudo &> /dev/null; then
                PREFIX="sudo"
            fi

            # 停止和禁用服务
            $PREFIX systemctl stop $SERVICE_NAME 2>/dev/null
            $PREFIX systemctl disable $SERVICE_NAME 2>/dev/null
            $PREFIX rm -f $SERVICE_FILE 2>/dev/null
            $PREFIX systemctl daemon-reload 2>/dev/null
            
            # 删除安装目录
            rm -rf $INSTALL_DIR
            
            # 删除控制命令
            $PREFIX rm -f $CONTROL_SCRIPT_PATH
            
            echo -e "${GREEN}🎉 旧版本已彻底卸载。${NC}"
        else
            echo -e "${CYAN}取消卸载。正在尝试更新...${NC}"
        fi
    fi
}


# ---------------------------------------------------------
# 辅助函数：安装 nt 控制脚本
# ---------------------------------------------------------
function install_control_script() {
    # 定义控制脚本路径
    local CONTROL_SCRIPT_PATH="/usr/local/bin/nt"
    local SERVICE_NAME="nodetool"
    local INSTALL_DIR="$HOME/nodetool"
    local BINARY_NAME="NodeTool" # 从主脚本继承

    echo -e "${YELLOW}--- 正在创建 nt 控制命令 ---${NC}"
    
    # 使用 heredoc 创建 nt 脚本内容
    cat <<'NT_SCRIPT_EOF' | $CMD_PREFIX tee $CONTROL_SCRIPT_PATH > /dev/null
#!/bin/bash

# NodeTool 服务控制脚本
SERVICE_NAME="nodetool"
INSTALL_DIR="$HOME/nodetool"
BIN_PATH="/usr/local/bin/nt"
# 定义颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# 检查是否使用 sudo
if [ "$EUID" -ne 0 ] && command -v sudo &> /dev/null; then
    CMD_PREFIX="sudo"
else
    CMD_PREFIX=""
fi

# 显示服务状态
function show_status() {
    echo -e "\n${CYAN}--- ${SERVICE_NAME} 运行状态 ---${NC}"
    if command -v systemctl &> /dev/null; then
        $CMD_PREFIX systemctl status $SERVICE_NAME --no-pager
    else
        echo -e "${RED}Systemctl 命令不可用。${NC}"
        # 备用显示进程状态
        echo "进程状态: $($CMD_PREFIX pgrep -f ${INSTALL_DIR}/NodeTool)"
    fi
    echo "----------------------------------"
}

# 卸载功能
function uninstall() {
    read -r -p "警告：您确定要彻底卸载 NodeTool 吗？(这将删除服务和安装目录：$INSTALL_DIR) [y/N] " response
    if [[ "$response" =~ ^([yY])$ ]]; then
        echo -e "${YELLOW}停止并禁用服务...${NC}"
        $CMD_PREFIX systemctl stop $SERVICE_NAME 2>/dev/null
        $CMD_PREFIX systemctl disable $SERVICE_NAME 2>/dev/null
        $CMD_PREFIX rm -f /etc/systemd/system/${SERVICE_NAME}.service 2>/dev/null
        $CMD_PREFIX systemctl daemon-reload 2>/dev/null
        
        echo -e "${YELLOW}删除安装目录 $INSTALL_DIR...${NC}"
        rm -rf $INSTALL_DIR
        
        echo -e "${YELLOW}删除控制命令 'nt'...${NC}"
        $CMD_PREFIX rm -f $BIN_PATH
        
        echo -e "${GREEN}🎉 NodeTool 已彻底卸载。${NC}"
        exit 0
    else
        echo -e "${CYAN}取消卸载。${NC}"
    fi
}

# ---------------------------------------------------------
# 主控制逻辑：支持参数或菜单
# ---------------------------------------------------------
if [ -z "$1" ]; then
    # 菜单模式
    while true; do
        echo -e "\n${GREEN}--- NodeTool 控制台 ---${NC}"
        echo -e "1) ${CYAN}查看服务状态 (status)${NC}"
        echo -e "2) ${CYAN}启动服务 (start)${NC}"
        echo -e "3) ${CYAN}重启服务 (restart)${NC}"
        echo -e "4) ${CYAN}停止服务 (stop)${NC}"
        echo -e "5) ${RED}完全卸载 (uninstall)${NC}"
        echo -e "0) ${YELLOW}退出面板${NC}"
        read -r -p "请输入选项 [0-5]: " choice
        
        case "$choice" in
            1) show_status ;;
            2) 
                echo -e "${CYAN}正在启动 NodeTool...${NC}"
                $CMD_PREFIX systemctl start $SERVICE_NAME
                sleep 1 # 短暂等待
                show_status
                ;;
            3) 
                echo -e "${CYAN}正在重启 NodeTool...${NC}"
                $CMD_PREFIX systemctl restart $SERVICE_NAME
                sleep 1 # 短暂等待
                show_status
                ;;
            4) 
                echo -e "${CYAN}正在停止 NodeTool...${NC}"
                $CMD_PREFIX systemctl stop $SERVICE_NAME
                sleep 1 # 短暂等待
                show_status
                ;;
            5) uninstall; break ;;
            0) echo -e "${CYAN}退出控制面板。${NC}"; break ;;
            *) echo -e "${RED}输入无效，请重新选择。${NC}" ;;
        esac
    done
else
    # 参数模式 (兼容旧命令)
    case "$1" in
        start)
            echo -e "${CYAN}正在启动 NodeTool...${NC}"
            $CMD_PREFIX systemctl start $SERVICE_NAME
            sleep 2
            show_status
            ;;
        stop)
            echo -e "${CYAN}正在停止 NodeTool...${NC}"
            $CMD_PREFIX systemctl stop $SERVICE_NAME
            sleep 2
            show_status
            ;;
        restart)
            echo -e "${CYAN}正在重启 NodeTool...${NC}"
            $CMD_PREFIX systemctl restart $SERVICE_NAME
            sleep 2
            show_status
            ;;
        status)
            show_status
            ;;
        uninstall)
            uninstall
            ;;
        *)
            echo -e "${RED}NodeTool 控制台${NC}"
            echo -e "${CYAN}用法: nt [start | stop | restart | status | uninstall]${NC}"
            echo -e "例如: nt status"
            ;;
    esac
fi
NT_SCRIPT_EOF

    # 赋予执行权限
    $CMD_PREFIX chmod +x $CONTROL_SCRIPT_PATH
    echo -e "✅ 'nt' 命令已安装到 $CONTROL_SCRIPT_PATH"
}
# ---------------------------------------------------------
# 主脚本开始
# ---------------------------------------------------------

# 0. 🟢 检查并卸载旧版本 (新增步骤)
check_and_uninstall_if_exists

# 1. 检查依赖
echo -e "${YELLOW}[1/7] 检查系统环境...${NC}"
DEPENDENCIES=("unzip" "curl" "wget" "pgrep") # 增加 pgrep 检查，确保进程检测命令可用
for cmd in "${DEPENDENCIES[@]}"; do
    if ! command -v $cmd &> /dev/null; then
        echo "未找到 $cmd，正在尝试自动安装..."
        INSTALL_SUCCESS=0
        if [ -x "$(command -v apt-get)" ]; then
            # 尝试使用 apt-get 安装 (区分是否有sudo)
            if [ "$EUID" -eq 0 ]; then sudo apt-get update && sudo apt-get install -y $cmd; else apt-get update && apt-get install -y $cmd; fi
            INSTALL_SUCCESS=$?
        elif [ -x "$(command -v yum)" ]; then
            # 尝试使用 yum 安装
            if [ "$EUID" -eq 0 ]; then sudo yum install -y $cmd; else yum install -y $cmd; fi
            INSTALL_SUCCESS=$?
        fi
        
        if [ $INSTALL_SUCCESS -ne 0 ]; then
            echo -e "${RED}错误: 无法自动安装 $cmd。请手动运行 'apt install $cmd' 或 'yum install $cmd'。${NC}"
            exit 1
        fi
    fi
done
echo "环境检查通过。"

# 2. 获取下载链接
if [ -n "$1" ]; then
    DOWNLOAD_URL="$1"
    echo -e "${YELLOW}[2/7] 使用参数中的下载链接: ${NC}$DOWNLOAD_URL"
else
    echo -e "${YELLOW}[2/7] 请输入下载链接:${NC}"
    read -p "链接: " DOWNLOAD_URL
fi

if [ -z "$DOWNLOAD_URL" ]; then
    echo -e "${RED}错误: 未提供链接。${NC}"
    exit 1
fi

# 3. 下载
echo -e "${YELLOW}[3/7] 正在下载文件...${NC}"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR" || exit
rm -f package.zip

# 尝试使用 wget 下载，并将输出重定向，避免下载失败卡住
wget -O package.zip "$DOWNLOAD_URL"
if [ $? -ne 0 ]; then
    echo -e "${RED}下载失败。请检查链接是否正确，或尝试使用加速链接。${NC}"
    exit 1
fi

# 4. 安装
echo -e "${YELLOW}[4/7] 正在安装...${NC}"

# 🟢 修复：确保解压成功
unzip -o package.zip > /dev/null
if [ $? -ne 0 ]; then
    echo -e "${RED}错误: 解压文件失败！请确保 'unzip' 工具已安装。${NC}"
    exit 1
fi

if [ ! -f "./$BINARY_NAME" ]; then
    # 尝试在子目录中查找 NodeTool
    FOUND_BIN=$(find . -name "$BINARY_NAME" -type f | head -n 1)
    if [ -n "$FOUND_BIN" ]; then
        # 移动子目录中的所有内容到安装根目录
        mv "$(dirname "$FOUND_BIN")"/* .
    else
        echo -e "${RED}错误: 在压缩包中未找到二进制文件 '$BINARY_NAME'。${NC}"
        echo "请检查压缩包内容是否包含名为 '$BINARY_NAME' 的可执行文件。"
        exit 1
    fi
fi

chmod +x "$BINARY_NAME"

# 5. 配置 Systemd 和控制脚本
echo -e "${YELLOW}[5/7] 正在配置 Systemd 和控制脚本...${NC}"
ABS_DIR=$(cd "$INSTALL_DIR" && pwd)
CURRENT_USER=$(whoami)

# 清理旧日志
rm -f "$LOG_FILE"

# 生成 Systemd Service 文件
cat <<EOF > ${SERVICE_NAME}.service
[Unit]
Description=NodeTool Web Service
After=network.target

[Service]
Type=simple
User=$CURRENT_USER
WorkingDirectory=$ABS_DIR
ExecStart=$ABS_DIR/$BINARY_NAME
Restart=always
RestartSec=5
StandardOutput=append:$LOG_FILE
StandardError=append:$LOG_FILE

[Install]
WantedBy=multi-user.target
EOF

CMD_PREFIX=""
if [ "$EUID" -ne 0 ] && command -v sudo &> /dev/null; then
    CMD_PREFIX="sudo"
fi

if [ -n "$CMD_PREFIX" ] || [ "$EUID" -eq 0 ]; then
    # 安装服务
    $CMD_PREFIX mv ${SERVICE_NAME}.service /etc/systemd/system/${SERVICE_NAME}.service
    $CMD_PREFIX systemctl daemon-reload > /dev/null 2>&1
    $CMD_PREFIX systemctl enable ${SERVICE_NAME}
    $CMD_PREFIX systemctl restart ${SERVICE_NAME}
    echo "服务已安装并重启。"
    # 🟢 安装 nt 脚本
    install_control_script
else
    echo -e "${RED}警告: 无 root/sudo 权限。使用 nohup 后备模式启动。${NC}"
    pkill -f "./$BINARY_NAME" || true
    nohup ./$BINARY_NAME > "$LOG_FILE" 2>&1 &
fi

# 🟢 [修改] 缩短等待时间
echo "正在等待服务启动 (3秒)..."
sleep 3

# 6. 状态检查与调试
echo -e "${YELLOW}[6/7] 正在执行健康检查...${NC}"

# 检查 1: 进程 (使用 nt status 逻辑来简化)
if pgrep -f "./$BINARY_NAME" > /dev/null; then
    echo -e "✅ 进程正在运行 (PID: $(pgrep -f "./$BINARY_NAME"))"
else
    echo -e "${RED}❌ 进程未运行！${NC}"
    echo -e "${CYAN}--- 应用启动日志 ($LOG_FILE) ---${NC}"
    if [ -f "$LOG_FILE" ]; then
        tail -n 20 "$LOG_FILE"
    else
        echo "无日志文件生成。"
    fi
    echo -e "${CYAN}-------------------------------${NC}"
    exit 1
fi

# 🟢 [新增调试] 检查 systemd status 获取崩溃原因
echo -e "${YELLOW}--- Systemd 状态诊断 (获取崩溃原因) ---${NC}"
# 尝试使用 systemctl status (如果环境支持)
if command -v systemctl &> /dev/null; then
    $CMD_PREFIX systemctl status $SERVICE_NAME --no-pager
else
    echo "Systemctl 命令不完整或不可用，跳过详细状态检查。"
fi
echo "------------------------------"

# 检查 2 & 3: 端口监听和本地 HTTP 请求
# (保留原有的精确检查)
if command -v netstat &> /dev/null; then
    PORT_CHECK_CMD="netstat -tuln"
elif command -v ss &> /dev/null; then
    PORT_CHECK_CMD="ss -tuln"
else
    PORT_CHECK_CMD=""
fi

if [ -n "$PORT_CHECK_CMD" ]; then
    if $PORT_CHECK_CMD | grep -q ":$PORT "; then
        echo -e "✅ 端口 $PORT 正在监听"
    else
        echo -e "${RED}❌ 进程正在运行，但端口 $PORT 未监听。${NC}"
    fi
fi

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:$PORT)
if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 302 ]; then
    echo -e "✅ 本地 HTTP 请求成功 (状态码: $HTTP_CODE)"
else
    echo -e "${RED}❌ 本地 HTTP 请求失败 (状态码: $HTTP_CODE)。${NC}"
    
    echo -e "${CYAN}--- 应用启动日志 ($LOG_FILE) ---${NC}"
    if [ -f "$LOG_FILE" ]; then
        tail -n 20 "$LOG_FILE"
    else
        echo -e "${RED}警告：日志文件 $LOG_FILE 未找到或为空。${NC}"
    fi
    echo -e "${CYAN}-------------------------------${NC}"
    
    # 额外调试：检查依赖库
    echo -e "${YELLOW}[调试] 检查二进制文件依赖:${NC}"
    if command -v ldd &> /dev/null; then
        ldd "./$BINARY_NAME" | grep "not found"
        if [ $? -eq 0 ]; then
            echo -e "${RED}发现缺失的系统库！${NC}"
        else
            echo "依赖库检查看起来正常。"
        fi
    fi
    
    exit 1
fi

# 7. 最终总结
echo -e "${YELLOW}[7/7] 总结${NC}"
IP=$(curl -s ifconfig.me)
echo -e "${GREEN}=============================================${NC}"
echo -e "${GREEN}🎉 NodeTool 正在运行！${NC}"
echo -e "---------------------------------------------"
echo -e "管理命令: ${CYAN}nt [start|stop|restart|status|uninstall]${NC}"
echo -e "日志查看: ${CYAN}sudo journalctl -u nodetool -f${NC}"
echo -e "公网地址:   ${YELLOW}http://$IP:$PORT${NC}"
echo -e "${GREEN}=============================================${NC}"
