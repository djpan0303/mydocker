# Stage 1: download RustDesk server binaries
FROM debian:bookworm-slim AS builder
ARG RUSTDESK_VERSION=1.1.14
ARG http_proxy
ARG https_proxy
ENV http_proxy=$http_proxy \
    https_proxy=$https_proxy
RUN sed -i 's|deb.debian.org|mirrors.aliyun.com|g' /etc/apt/sources.list.d/debian.sources && \
    apt-get update && apt-get install -y --no-install-recommends \
        wget unzip ca-certificates && \
    wget -q "https://github.com/rustdesk/rustdesk-server/releases/download/${RUSTDESK_VERSION}/rustdesk-server-linux-amd64.zip" && \
    unzip -q rustdesk-server-linux-amd64.zip && \
    mv amd64/hbbs amd64/hbbr /tmp/ && \
    apt-get purge -y wget unzip && \
    rm -rf /var/lib/apt/lists/* rustdesk-server-linux-amd64.zip amd64

# Stage 2: minimal runtime
FROM debian:bookworm-slim
ARG http_proxy
ARG https_proxy
ENV http_proxy=$http_proxy \
    https_proxy=$https_proxy
RUN sed -i 's|deb.debian.org|mirrors.aliyun.com|g' /etc/apt/sources.list.d/debian.sources
COPY --from=builder /tmp/hbbs /tmp/hbbr /usr/local/bin/
RUN chmod +x /usr/local/bin/hbbs /usr/local/bin/hbbr && \
    mkdir -p /data/conf

COPY start_rustdesk.sh /usr/local/bin/start_rustdesk.sh
RUN chmod +x /usr/local/bin/start_rustdesk.sh

EXPOSE 21115/tcp 21116/tcp 21116/udp 21117/tcp 21118/tcp 21119/tcp

WORKDIR /data/conf
ENTRYPOINT ["/usr/local/bin/start_rustdesk.sh"]
