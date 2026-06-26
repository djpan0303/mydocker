FROM scratch

# busybox rootfs (shell + basic tools)
COPY rootfs/ /

COPY --chmod=755 frpc /usr/local/bin/frpc
COPY frpc.toml /etc/frp/frpc.toml
COPY --chmod=755 start_frpc.sh /usr/local/bin/start_frpc.sh

ENTRYPOINT ["/usr/local/bin/start_frpc.sh"]
