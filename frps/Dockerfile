FROM scratch

# busybox rootfs (shell + basic tools)
COPY rootfs/ /

COPY --chmod=755 frps /usr/local/bin/frps
COPY frps.toml /etc/frp/frps.toml
COPY --chmod=755 start_frps.sh /usr/local/bin/start_frps.sh

EXPOSE 80 443 5443 6443

ENTRYPOINT ["/usr/local/bin/start_frps.sh"]
