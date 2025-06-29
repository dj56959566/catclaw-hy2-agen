#!/bin/bash
set -e

# 通过 GitHub API 获取探针下载地址
ARCH="linux_amd64"

# 判断是否传入 DASHBOARD_VERSION 参数
# 如果没传，调用 GitHub API 获取最新版本号
if [ -z "$DASHBOARD_VERSION" ]; then
  echo "未指定 DASHBOARD_VERSION，开始获取最新版本号..."
  DASHBOARD_VERSION=$(curl -s https://api.github.com/repos/nezhahq/agent/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
  if [ -z "$DASHBOARD_VERSION" ]; then
    echo "获取最新版本失败，退出"
    exit 1
  fi
  echo "✅最新版本号为: $DASHBOARD_VERSION"
else
  echo "✅使用指定版本号: $DASHBOARD_VERSION"
fi

# 构造下载链接
FILE="nezha-agent_${ARCH}.zip"
URL="https://github.com/nezhahq/agent/releases/download/${DASHBOARD_VERSION}/${FILE}"

wget -q -O "$FILE" "$URL"
if [ $? -ne 0 ]; then
  echo "下载失败 跳过"
fi

unzip -qo "$FILE"
if [ $? -ne 0 ]; then
  echo "解压失败，跳过继续执行"
fi

rm -f "$FILE"
chmod +x nezha-agent

# 自动生成 UUID（如果未提供）
if [ -z "$NZ_UUID" ]; then
  NZ_UUID=$(cat /proc/sys/kernel/random/uuid)
  echo "⚠️ 未提供 NZ_UUID，已自动生成：$NZ_UUID"
fi

echo "✅ 探针配置如下："
echo "NZ_SERVER: ${NZ_SERVER}"
echo "NZ_UUID: ${NZ_UUID}"
echo "NZ_CLIENT_SECRET: ${NZ_CLIENT_SECRET}"
echo "NZ_TLS: ${NZ_TLS}"
echo "DASHBOARD_VERSION: ${DASHBOARD_VERSION:-latest}"

# 生成 Nezha Agent 配置
cat > /app/config.yaml <<EOF
debug: true
disable_auto_update: true
disable_command_execute: false
disable_force_update: true
disable_nat: false
disable_send_query: false
gpu: false
insecure_tls: false
ip_report_period: 1800
report_delay: 4
server: ${NZ_SERVER}
skip_connection_count: false
skip_procs_count: false
temperature: false
tls: ${NZ_TLS}
use_gitee_to_upgrade: false
use_ipv6_country_code: false
uuid: ${NZ_UUID}
client_secret: ${NZ_CLIENT_SECRET}
EOF

echo "✅ 正在启动 Hysteria2，配置如下："
echo "SERVER_DOMAIN: ${SERVER_DOMAIN}"
echo "UDP_PORT: ${UDP_PORT}"
echo "PASSWORD: ${PASSWORD}"

# 创建 Hysteria2 配置文件
cat > /etc/hysteria/config.yaml <<EOF
listen: :${UDP_PORT}

tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key

auth:
  type: password
  password: ${PASSWORD}

masquerade:
  type: proxy
  proxy:
    url: https://bing.com/
    rewriteHost: true
EOF

# 启动 Hysteria2 到后台
/usr/local/bin/hysteria server -c /etc/hysteria/config.yaml &

# 获取公网 IP 和国家代码
SERVER_IP=$(curl -s https://api.ipify.org)
COUNTRY_CODE=$(curl -s https://ipapi.co/${SERVER_IP}/country/ || echo "Unable to get")

echo "✅ Hysteria2 启动成功"
echo "------------------------------------------------------------------------"
echo "🎯 客户端连接配置（请将端口替换为爪云分配的外网 UDP 端口）："
echo "hy2://${PASSWORD}@${SERVER_DOMAIN}:${UDP_PORT}?sni=bing.com&insecure=1#claw.cloud-hy2-${COUNTRY_CODE}"
echo "------------------------------------------------------------------------"

echo "✅ 正在启动探针..."
exec ./nezha-agent --config /app/config.yaml
