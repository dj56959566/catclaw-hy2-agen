FROM alpine:latest
WORKDIR /app

# 设置环境变量默认值
ENV UDP_PORT=20000

# 安装依赖 & 创建必要目录
RUN apk update && \
    apk add --no-cache curl wget openssl bash jq unzip ca-certificates && \
    mkdir -p /etc/hysteria

# 下载 hysteria2 主程序
RUN wget -q -O /usr/local/bin/hysteria https://download.hysteria.network/app/latest/hysteria-linux-amd64 && \
    chmod +x /usr/local/bin/hysteria

# 自签 TLS 证书
RUN openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) \
    -keyout /etc/hysteria/server.key \
    -out /etc/hysteria/server.crt \
    -subj "/CN=bing.com" -days 36500

# 拷贝 entrypoint 启动脚本
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 显示 UDP 端口
EXPOSE ${UDP_PORT}/udp

# 启动脚本作为容器入口
ENTRYPOINT ["/entrypoint.sh"]
