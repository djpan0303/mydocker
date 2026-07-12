#!/bin/bash
#
# RustDesk GFW 隧道一键配置脚本
# 适用场景：国内电脑受 GFW 干扰，TCP 21115/21116 被 RST 阻断
# 原理：SSH 隧道加密 TCP 流量 + iptables 透明重定向，UDP 直连
#
# 用法：bash setup-rustdesk-tunnel.sh
#

set -e

VPS_HOST="us.tinybear.cc"
VPS_IP="199.180.117.155"
VPS_USER="root"
SSH_ALIAS="vps-us"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "============================================"
echo "  RustDesk GFW 隧道配置脚本"
echo "  服务器: ${VPS_HOST}"
echo "============================================"
echo ""

# ---------- 1. 检查 SSH 连接 ----------
log_info "1/7 检查 SSH 连接到 ${VPS_ALIAS}..."

# 添加 SSH config
mkdir -p ~/.ssh
chmod 700 ~/.ssh
if ! grep -q "Host ${VPS_ALIAS}" ~/.ssh/config 2>/dev/null; then
    log_info "添加 SSH config 条目: ${VPS_ALIAS}"
    cat >> ~/.ssh/config << EOF

Host ${VPS_ALIAS}
        User ${VPS_USER}
        Hostname ${VPS_HOST}
        ServerAliveInterval 30
        ServerAliveCountMax 3
EOF
    chmod 600 ~/.ssh/config
fi

# 测试 SSH 连接
if ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new ${VPS_ALIAS} 'echo OK' &>/dev/null; then
    log_warn "SSH 密钥未授权，尝试 ssh-copy-id..."
    ssh-copy-id -o StrictHostKeyChecking=accept-new ${VPS_USER}@${VPS_HOST} || {
        log_error "无法配置 SSH 免密登录，请手动执行: ssh-copy-id ${VPS_USER}@${VPS_HOST}"
        exit 1
    }
fi
log_info "SSH 连接 OK"

# ---------- 2. 创建 SSH 隧道 systemd 服务 ----------
log_info "2/7 创建 SSH 隧道 systemd 服务..."

mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/rustdesk-tunnel.service << 'SERVICEEOF'
[Unit]
Description=RustDesk SSH Tunnel via vps-us
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/ssh -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes -N -L 21115:localhost:21115 -L 21116:localhost:21116 -L 21117:localhost:21117 vps-us
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
SERVICEEOF

systemctl --user daemon-reload
systemctl --user enable rustdesk-tunnel.service
systemctl --user restart rustdesk-tunnel.service
log_info "隧道服务已创建并启动"

# ---------- 3. 启用 linger（用户未登录时也能运行） ----------
log_info "3/7 启用 linger..."
sudo loginctl enable-linger "$USER" 2>/dev/null || log_warn "无法启用 linger，服务仅在登录时运行"

# ---------- 4. 配置 iptables 透明重定向 ----------
log_info "4/7 配置 iptables 透明重定向..."

# 检查是否已存在规则
if sudo iptables -t nat -C OUTPUT -d ${VPS_IP} -p tcp --dport 21115 -j DNAT --to-destination 127.0.0.1:21115 2>/dev/null; then
    log_info "iptables 规则已存在，跳过"
else
    sudo iptables -t nat -A OUTPUT -d ${VPS_IP} -p tcp --dport 21115 -j DNAT --to-destination 127.0.0.1:21115
    sudo iptables -t nat -A OUTPUT -d ${VPS_IP} -p tcp --dport 21116 -j DNAT --to-destination 127.0.0.1:21116
    log_info "iptables 规则已添加"
fi

# ---------- 5. 持久化 iptables ----------
log_info "5/7 持久化 iptables 规则..."

sudo mkdir -p /etc/iptables
sudo iptables-save -t nat > /etc/iptables/rules.v4

# 创建 restore 服务（如果没有 netfilter-persistent）
if ! command -v netfilter-persistent &>/dev/null && ! systemctl is-active --quiet netfilter-persistent 2>/dev/null; then
    sudo tee /etc/systemd/system/iptables-restore.service > /dev/null << 'RESTOREEOF'
[Unit]
Description=Restore iptables rules on boot
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/iptables-restore /etc/iptables/rules.v4
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
RESTOREEOF
    sudo systemctl daemon-reload
    sudo systemctl enable iptables-restore.service 2>/dev/null || true
fi
log_info "iptables 规则已持久化"

# ---------- 6. 验证 ----------
log_info "6/7 验证连接..."

sleep 2
FAIL=0

if nc -zv -w 3 ${VPS_HOST} 21116 2>&1 | grep -q succeeded; then
    log_info "✅ TCP ${VPS_HOST}:21116 → 隧道 OK"
else
    log_error "❌ TCP ${VPS_HOST}:21116 不通"
    FAIL=1
fi

if nc -zv -w 3 ${VPS_HOST} 21115 2>&1 | grep -q succeeded; then
    log_info "✅ TCP ${VPS_HOST}:21115 → 隧道 OK"
else
    log_error "❌ TCP ${VPS_HOST}:21115 不通"
    FAIL=1
fi

if nc -zvu -w 3 ${VPS_HOST} 21116 2>&1 | grep -q succeeded; then
    log_info "✅ UDP ${VPS_HOST}:21116 → 直连 OK"
else
    log_error "❌ UDP ${VPS_HOST}:21116 不通"
    FAIL=1
fi

# ---------- 7. 配置 RustDesk 客户端 ----------
log_info "7/7 配置 RustDesk 客户端..."

RUSTDESK_DIR="${HOME}/.config/rustdesk"
RUSTDESK_CONF="${RUSTDESK_DIR}/RustDesk2.toml"

if [ -f "${RUSTDESK_CONF}" ]; then
    # 更新 rendezvous_server（ID 服务器，带端口）
    if grep -q '^rendezvous_server' "${RUSTDESK_CONF}"; then
        sed -i "s/^rendezvous_server = .*/rendezvous_server = '${VPS_HOST}:21116'/" "${RUSTDESK_CONF}"
    else
        echo "rendezvous_server = '${VPS_HOST}:21116'" >> "${RUSTDESK_CONF}"
    fi

    # 确保 [options] 段存在
    if ! grep -q '^\[options\]' "${RUSTDESK_CONF}"; then
        echo "" >> "${RUSTDESK_CONF}"
        echo "[options]" >> "${RUSTDESK_CONF}"
    fi

    # 更新 custom-rendezvous-server（ID 服务器）
    if grep -q 'custom-rendezvous-server' "${RUSTDESK_CONF}"; then
        sed -i "s/^custom-rendezvous-server = .*/custom-rendezvous-server = '${VPS_HOST}'/" "${RUSTDESK_CONF}"
    else
        sed -i "/^\[options\]/a custom-rendezvous-server = '${VPS_HOST}'" "${RUSTDESK_CONF}"
    fi

    # 更新 relay-server（中继服务器）
    if grep -q 'relay-server' "${RUSTDESK_CONF}"; then
        sed -i "s/^relay-server = .*/relay-server = '${VPS_HOST}'/" "${RUSTDESK_CONF}"
    else
        sed -i "/^\[options\]/a relay-server = '${VPS_HOST}'" "${RUSTDESK_CONF}"
    fi

    # 递增 serial 以触发配置重载
    CUR_SERIAL=$(grep '^serial' "${RUSTDESK_CONF}" | grep -oP '\d+' || echo "0")
    NEW_SERIAL=$((CUR_SERIAL + 1))
    if grep -q '^serial' "${RUSTDESK_CONF}"; then
        sed -i "s/^serial = .*/serial = ${NEW_SERIAL}/" "${RUSTDESK_CONF}"
    else
        sed -i "1a serial = ${NEW_SERIAL}" "${RUSTDESK_CONF}"
    fi

    log_info "RustDesk 配置已更新:"
    log_info "  ID 服务器:   ${VPS_HOST}"
    log_info "  中继服务器:  ${VPS_HOST}"
else
    # 首次安装，创建配置
    mkdir -p "${RUSTDESK_DIR}"
    cat > "${RUSTDESK_CONF}" << CONFEOF
rendezvous_server = '${VPS_HOST}:21116'
nat_type = 2
serial = 0

[options]
custom-rendezvous-server = '${VPS_HOST}'
relay-server = '${VPS_HOST}'
CONFEOF
    log_info "RustDesk 配置文件已创建"
fi

# 重启 RustDesk（如果正在运行）
RUSTDESK_PID=$(pgrep -f "rustdesk --server" 2>/dev/null || true)
if [ -n "${RUSTDESK_PID}" ]; then
    log_info "检测到 RustDesk 正在运行，尝试重启..."
    # 结束用户态 RustDesk
    pkill -f "rustdesk --tray" 2>/dev/null || true
    pkill -f "rustdesk --server" 2>/dev/null || true
    sleep 2
    # 重新启动（方式取决于安装方式）
    if systemctl is-active --quiet rustdesk 2>/dev/null; then
        sudo systemctl restart rustdesk 2>/dev/null && log_info "已通过 systemd 重启 RustDesk"
    else
        # flatpak / snap / 手动安装，尝试重新拉起
        nohup rustdesk &>/dev/null &
    fi
    log_info "RustDesk 已重启，请在通知栏确认图标出现"
else
    log_info "RustDesk 未运行，请手动启动后配置即生效"
fi

echo ""
echo "============================================"
if [ $FAIL -eq 0 ]; then
    log_info "🎉 全部配置完成！"
    echo ""
    echo "  RustDesk 客户端设置（已自动配置）:"
    echo "    ID 服务器:   ${VPS_HOST}"
    echo "    中继服务器:  ${VPS_HOST}"
    echo ""
    echo "  SSH 隧道:    开机自启 ✅"
    echo "  iptables:    已持久化 ✅"
else
    log_error "存在失败项，请检查上述输出"
fi
echo "============================================"
