#!/bin/bash

# 定义要重启的节点（可修改传参方式）
NODES=("2" "3")

# 可配置节点到端口的映射
declare -A PORT_MAP=( ["1"]=8545 ["2"]=8546 ["3"]=8547 )

_log() {
    # $1=文字 $2=颜色
    local COLOR_RESET="\033[0m"
    local COLOR_GREEN="\033[1;32m"
    local COLOR_YELLOW="\033[1;33m"
    local COLOR_RED="\033[1;31m"
    local COLOR="$COLOR_RESET"

    case "$2" in
        "green") COLOR=$COLOR_GREEN ;;
        "yellow") COLOR=$COLOR_YELLOW ;;
        "red") COLOR=$COLOR_RED ;;
        *) COLOR=$COLOR_RESET ;;
    esac

    echo -e "${COLOR}[`date '+%Y-%m-%d %H:%M:%S'`] $1${COLOR_RESET}"
}

_log "Restarting nodes: ${NODES[*]}" "green"

for nodeNum in "${NODES[@]}"; do
    _log "Stopping node $nodeNum..." "yellow"
    port=${PORT_MAP[$nodeNum]}

    # 查找监听端口的PID（假设go节点进程监听该端口）
    pids=$(lsof -i :$port -t 2>/dev/null)
    for pid in $pids; do
        pname=$(ps -p $pid -o comm=)
        if [[ $pname == *node* ]] || [[ $pname == *go* ]]; then
            echo "Killing process $pid ($pname)"
            kill -9 $pid
        fi
    done

    sleep 2

    _log "Starting node $nodeNum..." "yellow"
    configFile="configs/node${nodeNum}.yaml"
    logFile="logs/node${nodeNum}.log"
    errFile="logs/node${nodeNum}.err"

    # 假设 go 可调用 go run，或你可用可执行文件路径替换
    nohup go run cmd/node/main.go --config "$configFile" >"$logFile" 2>"$errFile" &

    sleep 3

    # 健康检查
    rpcPort=${PORT_MAP[$nodeNum]}
    healthUrl="http://localhost:$rpcPort/health"
    resp=$(curl -s --max-time 5 "$healthUrl")
    if [[ $? -eq 0 && "$resp" =~ \"height\": && "$resp" =~ \"peers\": ]]; then
        height=$(echo "$resp" | grep -o '"height":[0-9]*' | head -1 | awk -F: '{print $2}')
        peers=$(echo "$resp" | grep -o '"peers":[0-9]*' | head -1 | awk -F: '{print $2}')
        _log "✅ Node $nodeNum is healthy (Height: $height, Peers: $peers)" "green"
    else
        _log "❌ Node $nodeNum health check failed: $resp" "red"
    fi

done

_log "Node restart completed!" "green"
