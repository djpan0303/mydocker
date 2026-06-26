# Docker Setup

开始前务必保证两件事：
+ 设置好域名解析，将registry.tinybear.cc解析到registry server所在的服务器IP
+ 不论是推送构建好的镜像还是拉取镜像，需要设置号/etc/docker/daemon.json,在其中加入如下配置：
```
{
  "registry-mirrors": ["https://docker.mirrors.ustc.edu.cn"],
  "insecure-registries": ["registry.tinybear.cc:5000"]
}
```

搭建registry时docker pull拉取官方镜像可能会拉取失败，需要设置docker代理。
sudo mkdir -p /etc/systemd/system/docker.service.d
vim /etc/systemd/system/docker.service.d/http-proxy.conf
添加如下内容：
[Service]
Environment="HTTP_PROXY=http://127.0.0.1:8118"
Environment="HTTPS_PROXY=http://127.0.0.1:8118"
Environment="NO_PROXY=localhost,127.0.0.1"

然后执行如下命令：
sudo systemctl daemon-reload
sudo systemctl restart docker

用如下命令检查代理是否设置正确：
sudo systemctl show --property=Environment docker

[如何优雅的给 Docker 配置网络代理](https://www.cnblogs.com/Chary/p/18096678)

# Registry Server

deploy and start registry server
```
registry_ctrl --start_server
```
启动服务器后，浏览器上打开tinybear.cc:8080可以看到当前仓库中的镜像。

stop registry server
```
registry_ctrl --stop_server
```


# Image
新增image，需要在container_ctrl.sh的start函数匹配对应的docker启动
build image without removing old image of current date
```
image_ctrl.sh --build ssclient
```

build image and remove old image of current date
```
image_ctrl.sh --cbuild ssclient
```

push image to registry server
```
image_ctrl.sh --push ssclient
```

# Container
start local container
```
container_ctrl.sh --start ssclient
```

stop local container
```
container_ctrl.sh --stop ssclient
```

log in local container
```
container_ctrl.sh --login ssclient
```

# frps (FRP Server)

## Build & Push

build image and push to registry
```
cd frps && docker build -t registry.tinybear.cc:5000/frps:0.58.1 -t registry.tinybear.cc:5000/frps:latest . && docker push registry.tinybear.cc:5000/frps:0.58.1 && docker push registry.tinybear.cc:5000/frps:latest
```

## Deploy

The image uses `FROM scratch` with busybox, total size ~24MB.
On startup, the script checks `/data/conf/frps.toml`:
- If not exists, copies default config
- If `webServer.password` or `auth.token` is empty, auto-generates 16-char random credentials

first time pull and run
```
docker pull registry.tinybear.cc:5000/frps:0.58.1
docker run -d --name frps --restart=always --network host \
  -v /data/conf:/data/conf \
  registry.tinybear.cc:5000/frps:0.58.1
```

install as systemd service (auto-start on boot)
```
cat > /etc/systemd/system/frps.service << 'EOF'
[Unit]
Description=frps container service
Requires=docker.service
After=docker.service

[Service]
Type=simple
Restart=always
RestartSec=10
ExecStartPre=-/usr/bin/docker rm -f frps
ExecStart=/usr/bin/docker run --name frps --restart=always --network host -v /data/conf:/data/conf registry.tinybear.cc:5000/frps:0.58.1
ExecStop=/usr/bin/docker stop frps
ExecStopPost=/usr/bin/docker rm -f frps

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable frps.service
systemctl start frps.service
```

## Management

```
systemctl status frps      # check status
systemctl restart frps     # restart service
systemctl stop frps        # stop service
journalctl -u frps -f      # tail logs
```

```
docker logs frps           # view container logs
docker rm -f frps          # force remove container
```

```
cat /data/conf/frps.toml   # view config (includes auto-generated credentials)
```

# frpc (FRP Client)

## Build & Push

```
cd frpc && docker build -t registry.tinybear.cc:5000/frpc:0.58.1 -t registry.tinybear.cc:5000/frpc:latest . && docker push registry.tinybear.cc:5000/frpc:0.58.1 && docker push registry.tinybear.cc:5000/frpc:latest
```

## Deploy

On startup, the script checks `/data/conf/frpc.toml` and copies the default config if not exists. Edit the config to set `serverAddr`, `auth.token`, and `proxies` before use.

```
docker pull registry.tinybear.cc:5000/frpc:0.58.1
docker run -d --name frpc --restart=always --network host \
  -v /data/conf:/data/conf \
  registry.tinybear.cc:5000/frpc:0.58.1
```

systemd service (auto-start on boot)
```
cat > /etc/systemd/system/frpc.service << 'EOF'
[Unit]
Description=frpc container service
Requires=docker.service
After=docker.service

[Service]
Type=simple
Restart=always
RestartSec=10
ExecStartPre=-/usr/bin/docker rm -f frpc
ExecStart=/usr/bin/docker run --name frpc --restart=always --network host -v /data/conf:/data/conf registry.tinybear.cc:5000/frpc:0.58.1
ExecStop=/usr/bin/docker stop frpc
ExecStopPost=/usr/bin/docker rm -f frpc

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable frpc.service
systemctl start frpc.service
```

## Management

```
systemctl status frpc       # check status
systemctl restart frpc      # restart service
systemctl stop frpc         # stop service
journalctl -u frpc -f       # tail logs
```

```
docker logs frpc            # view container logs
docker rm -f frpc           # force remove container
```

```
cat /data/conf/frpc.toml    # view/edit config (serverAddr, auth.token, proxies)
```