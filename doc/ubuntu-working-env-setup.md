# Ubuntu Working Environment — App Inventory & Rebuild Guide

**Snapshot:** 2026-10-26
**Host:** `ubt-ASUS-EXPERTBOOK-B1403CVA-P1463CVA`
**OS:** Ubuntu 22.04.5 LTS (jammy), GNOME on **X11**
**Hardware:** Intel integrated graphics (no NVIDIA GPU), 30 GiB RAM, 938 GB NVMe, ASUS ExpertBook B1403CVA
**Login shell:** bash; user in groups `adm cdrom sudo dip plugdev input lpadmin lxd sambashare docker`
**Package footprint:** 166 manually installed apt packages, 11 snaps, no flatpak, vendor `.deb` apps under `/opt`
**Target OS:** a newer Ubuntu (24.04 LTS or later). Ubuntu desktop defaults are omitted entirely; only user-added apps, vendor `.deb`s, and dev tooling are listed.

> **For the AI agent reading this on a fresh machine:** Work top to bottom. §2 has install commands, §3 has desktop/system settings, §4 has migration caveats. Ubuntu desktop defaults, base shell utilities, the boot stack, and language packs are deliberately excluded — do not install them. Appendix A is filtered to non-default packages only. Ask before installing proprietary or company-internal software. Package versions are intentionally unpinned; let apt/pip/nvm resolve current compatible versions, and fetch current vendor `.deb`s.

---

## 1. What is actually used (ranked)

### 1.1 GNOME app-usage scores

Source: `~/.local/share/gnome-shell/application_state`. Score is GNOME Shell's decayed usage score (higher = more launches); it only counts apps started via the desktop, not CLI tools. Ranking excludes apps supplied by the Ubuntu desktop.

| # | App | Desktop ID | Score |
|---|-----|------------|-------|
| 1 | Google Chrome (primary browser) | `google-chrome.desktop` | 23030 |
| 2 | Feishu / Lark | `bytedance-feishu.desktop` | 10336 |
| 3 | WeChat | `wechat.desktop` | 4484 |
| 4 | Terminator | `terminator.desktop` | 935 |
| 5 | VS Code | `com.microsoft.VSCode.desktop` | 600 |
| 6 | WeCom (WeChat Work) | `com.qq.weixin.work.deepin.desktop` | 297 |
| 7 | Beyond Compare | `bcompare.desktop` | 55 |
| 8 | VLC | `vlc.desktop` | 11 |
| 9 | WPS Office | `wps-office-prometheus.desktop` | 10 |
| 10 | Flameshot | `org.flameshot.Flameshot.desktop` | 0 (11 recent-file opens) |
| 11 | gedit | `gedit.desktop` | — (574 recent-file opens) |

gedit is not part of the 24.04+ default set, so it remains installable if wanted.

### 1.2 Recent-file open counts

Source: `~/.local/share/recently-used.xbel` (second usage signal). Only non-default apps are shown.

| App | Opens |
|-----|-------|
| gedit | 574 |
| Google Chrome | 74 |
| VS Code | 59 |
| Flameshot | 11 |
| WeChat | 10 |
| Feishu | 1 |
| Obsidian | 1 |

### 1.3 Pinned dock (installable pins, in order)

`indicator-stickynotes` → `Beyond Compare` → `Terminator` → `WeCom` → `Google Chrome` → `gedit` → `Feishu` → `VS Code`.

Pins that need installation. Ubuntu desktop defaults are omitted; pinning itself is a setting, not an install.

### 1.4 Shell workflow (from `~/.bash_history`, 2000 lines)

Top **non-built-in** command prefixes: `git` 1390, `docker` 29, `claude` 12, `gedit` 6, `vim` 4.
Built-in shell commands are omitted because every Ubuntu already provides them. The working day revolves around **git + Docker + Claude Code**.

### 1.5 The practical install list

- **Apps:** Chrome, Feishu, WeChat, WeCom, Terminator, gedit, VS Code, Beyond Compare, Flameshot, Sticky Notes, VLC, WPS Office, QQ, Tencent Meeting, Zoom, Obsidian, BaiduNetdisk, Calibre, vokoscreen-ng, ToDesk, RustDesk, Sogou Pinyin.
- **Dev stack:** VS Code + 49 extensions, Docker CE + Compose, ROS 2 + Gazebo, Python user packages (torch/whisper/face-recognition), nvm + Node LTS, Claude Code.
- **System:** Sogou Pinyin with fcitx, extra CJK fonts, X11 session.

---

## 2. Installation plan

### 2.0 Scope

This guide installs only software that is **not** part of a standard Ubuntu desktop. Ubuntu-provided apps, shell/base utilities, the boot stack, kernel, and installer-selected language packs are omitted from every list below; configure them if needed (§3), but do not reinstall them.

### 2.1 Packages to add

```bash
# Bootstrap only if missing (standard desktop images normally have the basics)
sudo apt update && sudo apt upgrade -y

sudo apt install -y build-essential cmake git vim htop jq shellcheck shfmt \
  net-tools tcptraceroute sshpass openssh-server dconf-editor aptitude alien dmg2img \
  ifuse libimobiledevice-utils libinput-tools openfortivpn ffmpeg \
  flameshot vokoscreen-ng terminator gedit vlc calibre \
  pipx python3-pip python3-opencv clang-format \
  fonts-arphic-ukai fonts-arphic-uming fonts-noto-cjk-extra \
  libboost-all-dev libgmock-dev libgtest-dev libsqlite3-dev libtinyxml2-dev \
  libzmq3-dev libmosquitto-dev nlohmann-json3-dev libdbus-1-dev
```

Notes:

- Ubuntu-provided desktop apps, shell/base utilities, boot stack, and language packs are not listed (see §2.0).
- Dependency-only packages (Sogou/fcitx/ROS libraries and Python deps such as `python3-yaml`, `python3-distro`, `python3-argcomplete`, `python3-colcon-core`) are installed automatically.
- Add `plocate`, exFAT support, or iPhone support only if actually missing; use the distro's `clang-format` rather than an old pinned version.
- For a Chinese UI, select **English + 简体中文** in the installer; for an English-only system, install `language-pack-zh-hans language-pack-gnome-zh-hans fonts-noto-cjk`.

Package versions are intentionally not pinned; `apt` installs the versions shipped by the target Ubuntu.

### 2.2 Third-party repositories

Commands assume standard download/key tools are present (normal on desktop images); install only if missing.

**Google Chrome** (primary browser):

```bash
wget -qO- https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg
echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome-stable/deb/ stable main' | sudo tee /etc/apt/sources.list.d/google-chrome.list
sudo apt update && sudo apt install -y google-chrome-stable
```

**VS Code** (Microsoft repo):

```bash
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /usr/share/keyrings/microsoft.gpg
echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main' | sudo tee /etc/apt/sources.list.d/vscode.list
sudo apt update && sudo apt install -y code
```

**Docker CE** (this machine used the Aliyun mirror; official repo shown first):

```bash
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin \
  docker-compose-plugin docker-ce-rootless-extras
# Optional, installed here: docker-model-plugin
sudo usermod -aG docker "$USER"
```

China mirror alternative (replace `<codename>` with the target Ubuntu codename):
`deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://mirrors.aliyun.com/docker-ce/linux/ubuntu <codename> stable`

**ROS 2** (Humble on 22.04; use the matching distro on a new Ubuntu — Jazzy on 24.04):

```bash
# Requires standard download/repo tools (normally preinstalled)
sudo add-apt-repository -y universe
curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key | sudo tee /usr/share/keyrings/ros-archive-keyring.gpg >/dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo "$UBUNTU_CODENAME") main" | sudo tee /etc/apt/sources.list.d/ros2.list
sudo apt update
```

This machine also used the USTC mirror; replace `<codename>` with the target codename:
`deb [arch=amd64] https://mirrors.ustc.edu.cn/ros2/ubuntu/ <codename> main`

**Beyond Compare** — use the vendor's Linux download / apt repo at scootersoftware.com.

**Indicator Sticky Notes**:

```bash
sudo add-apt-repository -y ppa:umang/indicator-stickynotes
sudo apt update && sudo apt install -y indicator-stickynotes
```

**deepin-wine** (required only for WeCom):

```bash
# This machine used: deb [trusted=yes] https://deepin-wine.i-m.dev /
# Review the project's setup script before running anything from it.
sudo apt install -y deepin-wine8-stable
```

### 2.3 ROS 2 + Gazebo

```bash
# On 24.04+, replace ros-humble-* with ros-jazzy-* and /opt/ros/humble with /opt/ros/jazzy
sudo apt install -y ros-humble-desktop gazebo python3-colcon-common-extensions \
  python3-rosdep \
  ros-humble-joint-state-publisher ros-humble-mrpt-apps ros-humble-mrpt-navigation \
  ros-humble-rqt-tf-tree ros-humble-usb-cam ros-humble-xacro
sudo rosdep init || true
rosdep update
echo 'source /opt/ros/humble/setup.bash' >> ~/.bashrc
```

Use the ROS 2 release that matches the Ubuntu version (Humble on 22.04, Jazzy on 24.04) and let apt resolve package versions. Gazebo Classic is not packaged on 24.04; use Gazebo Sim (`ros-jazzy-ros-gz`).

### 2.4 Snap packages

```bash
# Non-default snaps only (Ubuntu desktop defaults are omitted)
sudo snap install obsidian --classic
```

No flatpak apps were installed.

### 2.5 Vendor `.deb` apps (download from the official site)

| App             | Package                     | Source                       |
| --------------- | --------------------------- | ---------------------------- |
| WeChat          | `wechat`                    | weixin.qq.com Linux download |
| WeCom           | `com.qq.weixin.work.deepin` | deepin-wine repo             |
| Feishu / Lark   | `bytedance-feishu-stable`   | feishu.cn                    |
| QQ              | `linuxqq`                   | im.qq.com/linuxqq            |
| Tencent Meeting | `wemeet`                    | meeting.tencent.com          |
| Zoom            | `zoom`                      | zoom.us/download             |
| WPS Office      | `wps-office`                | wps.cn                       |
| Baidu Netdisk   | `baidunetdisk`              | pan.baidu.com                |
| ToDesk          | `todesk`                    | todesk.com                   |
| RustDesk        | `rustdesk`                  | rustdesk.com                 |
| Beyond Compare  | `bcompare`                  | scootersoftware.com          |
| Sogou Pinyin    | `sogoupinyin`               | pinyin.sogou.com             |

Install a downloaded `.deb` with `sudo apt install ./file.deb` (not `dpkg -i`, so dependencies resolve).

Install Sogou with the fcitx version matching the Ubuntu release; its `.deb` pulls the pinyin/opencc/Qt dependencies. On 24.04+ use the current fcitx and Sogou builds.

### 2.6 VS Code extensions

All 49 extensions are listed in Appendix C. Restore in one shot:

```bash
while read -r ext; do code --install-extension "$ext"; done <<'EOF'
<contents of Appendix C>
EOF
```

Key extension groups: C/C++ (`ms-vscode.cpptools*`, `clang-format`), Python (`ms-python.*`), ROS 2 (`jaehyunshim.vscode-ros2`, `nonanonno.vscode-ros2`), Docker/Remote (`ms-vscode-remote.*`, `ms-azuretools.*`), Git tools (`mhutchie.git-graph`, `waderyan.gitblame`), markdown/PDF/Office viewers, PlatformIO, Go, and the Chinese language pack.

### 2.7 Python toolchain

- The Python runtime ships with Ubuntu; use the distro version and do not replace it.
- Install `pipx` / `python3-pip`, then the top-level libraries below; Appendix D is the full inventory for reference. Let pip resolve current compatible versions.
- Major libraries: PyTorch, torchvision, ONNX, openai-whisper, face-recognition + dlib, numba, scikit-image/learn, OpenCV (apt `python3-opencv`).
- Note: CUDA/NVIDIA wheel packages are installed even though this laptop has only Intel graphics — they are for CPU/remote inference. On an NVIDIA machine, install the matching wheel set instead.
- `pipx` app: `ubuild` (install with `pipx install ubuild` if the package is reachable).

### 2.8 Node / Claude

- nvm at `~/.nvm`; use the current Node LTS. Node is not bundled with Ubuntu desktop.
- Claude Code, installed globally under `/usr/lib/node_modules/@anthropic-ai/claude-code` (root npm). Alias in `.bashrc`: `claude='claude --dangerously-skip-permissions'`.

```bash
# master tracks the latest nvm installer
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
source ~/.nvm/nvm.sh
nvm install --lts
npm install -g @anthropic-ai/claude-code   # or use Anthropic's native installer
```

### 2.9 Docker

Docker daemon config:

```json
// /etc/docker/daemon.json
{"insecure-registries": ["us.tinybear.cc:5000"]}
```

Docker daemon proxy (`/etc/systemd/system/docker.service.d/http-proxy.conf`):

```ini
[Service]
Environment="HTTP_PROXY=http://127.0.0.1:8118"
Environment="HTTPS_PROXY=http://127.0.0.1:8118"
Environment="NO_PROXY=localhost,127.0.0.1,.local,.internal,registry.tinybear.cc,us.tinybear.cc,glcr.rd.ubtrobot.com,gitlab.rd.ubtrobot.com,.rd.ubtrobot.com,10.10.95.206"
```

Then `sudo systemctl daemon-reload && sudo systemctl restart docker`.

---

## 3. Desktop and system configuration

### 3.1 Session / display

- GNOME on **X11** (`XDG_SESSION_TYPE=x11`). Select "Ubuntu on Xorg" at login on a fresh install — fcitx, remote-desktop tools, and some Chinese apps behave better there.
- Ubuntu Dock at bottom, fixed, autohide on, extend-height on:

```bash
gsettings set org.gnome.shell.extensions.dash-to-dock dock-position 'BOTTOM'
gsettings set org.gnome.shell.extensions.dash-to-dock dock-fixed true
gsettings set org.gnome.shell.extensions.dash-to-dock autohide true
gsettings set org.gnome.shell.extensions.dash-to-dock extend-height true
```

- GNOME extensions are built-in defaults (`ding@rastersoft.com`, `ubuntu-appindicators@ubuntu.com`, `ubuntu-dock@ubuntu.com`) — do not install anything. Verify with `gnome-extensions list`.
- Extension key names can differ on 24.04+; verify keys before applying `gsettings` commands.

### 3.2 Input method + locale

fcitx with Sogou Pinyin. In `~/.bashrc`:

```bash
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
```

Autostart: `fcitx-autostart.desktop`. Locale: select **English + 简体中文** in the installer so the language packs and base CJK fonts are installed; add `fonts-noto-cjk-extra`, AR PL UKai/UMing, and WPS-shipped fonts separately. On Ubuntu 24.04+ use the current fcitx and Sogou builds; keep the same `GTK_IM_MODULE=fcitx` env vars.

### 3.3 Autostart

- Feishu (`/usr/bin/bytedance-feishu-stable %U`)
- fcitx (`fcitx`)
- plus the standard GNOME/X11 daemons.

### 3.4 Shell / git

`~/.bashrc` additions (snippets):

```bash
export GTK_IM_MODULE=fcitx; export QT_IM_MODULE=fcitx; export XMODIFIERS=@im=fcitx

function set_proxy() {
  export http_proxy="http://127.0.0.1:8118"
  export https_proxy="http://127.0.0.1:8118"
  export all_proxy="http://127.0.0.1:8118"
  export NO_PROXY="localhost,127.0.0.1,.local,.internal,registry.tinybear.cc,us.tinybear.cc,glcr.rd.ubtrobot.com,gitlab.rd.ubtrobot.com,.rd.ubtrobot.com,10.10.95.206"
  export no_proxy="$NO_PROXY"
}
function unset_proxy() { unset http_proxy https_proxy all_proxy; }

source /opt/ros/humble/setup.bash
alias claude='claude --dangerously-skip-permissions'
export NVM_DIR="$HOME/.nvm"; [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
```

### 3.5 Proxy / network quirks (important on this machine)

- The internal `ssclient` container runs Privoxy on **127.0.0.1:8118** forwarding through SSR socks5 on 127.0.0.1:1080; it is a **full tunnel**, so internal hosts must bypass it via `NO_PROXY`.
- `set_proxy` / `unset_proxy` functions toggle `http_proxy`/`https_proxy`/`all_proxy`.
- Missing `NO_PROXY` entry for the internal MinIO host `10.10.95.206` previously caused registry pull 502s; keep it.
- Private/internal hosts: `glcr.rd.ubtrobot.com`, `gitlab.rd.ubtrobot.com`, `*.rd.ubtrobot.com` (DNS/route to 10.10.95.250), `us.tinybear.cc`, `registry.tinybear.cc`.
- Some curl versions ignore CIDR entries in `NO_PROXY`: use `curl --noproxy '*'` for localhost checks.

---

## 4. Caveats when moving to a newer Ubuntu

1. **ROS distro mapping:** 22.04 → Humble; 24.04 → Jazzy. All `ros-humble-*` package names change; Gazebo Classic is gone on 24.04.
2. **Older fcitx + Sogou builds** are legacy on 24.04+; install the current fcitx and Sogou Linux packages. Keep `GTK_IM_MODULE=fcitx`.
3. **WeCom via deepin-wine** may break on a newer distro; prefer an official WeCom Linux package if one exists by then.
4. **Third-party apt suites** must be changed from `jammy` to the new codename (Docker, ROS, PPAs, deepin-wine).
5. **Appendix A is filtered** to non-default packages. Base packages, boot stack, built-in desktop apps, language packs, and dependency-only libraries were intentionally removed. Use §2's commands and treat the appendix only as a checklist for omissions.
6. **Ubuntu 22.04 standard support ends 2027**; a new install should be at least 24.04 LTS.
7. **No NVIDIA GPU here** — the installed CUDA pip wheels are for remote/CPU inference. Match the wheel set to the new machine's GPU, or install CPU-only torch.
8. **X11:** keep an Xorg session available for fcitx, remote-desktop tools, and screenshot utilities.
9. **Vendor `.deb`s change often**; download current packages and re-check package names.
10. **Company-internal pieces** — the `ssclient`/`frpc` proxy can't be installed from public sources; obtain access/config from the company.
11. **Desktop defaults move between releases:** the default text editor, image viewer, software center, and other stock apps differ on 24.04+. Do not assume this machine's default set matches the new OS; install older tools only if you specifically want them.

---

## Appendix A — Non-default apt packages (76, install/diff checklist)

Filtered from the live `apt-mark showmanual` (166) by removing base OS packages, the boot stack, preinstalled tools, desktop defaults, language packs, optional language fonts, old version-pinned packages, and dependency-only libraries. `git` is included because it is required even though it was not marked manual on the source machine.

```text
alien aptitude baidunetdisk bcompare build-essential bytedance-feishu-stable calibre
clang-format cmake code com.qq.weixin.work.deepin containerd.io dconf-editor dmg2img
docker-buildx-plugin docker-ce docker-ce-cli docker-ce-rootless-extras docker-compose-plugin
docker-model-plugin fcitx ffmpeg flameshot fonts-arphic-ukai fonts-arphic-uming
fonts-noto-cjk-extra gazebo gedit git google-chrome-stable htop ifuse
indicator-stickynotes jq libboost-all-dev libdbus-1-dev libgmock-dev libgtest-dev
libimobiledevice-utils libinput-tools libmosquitto-dev libsqlite3-dev libtinyxml2-dev
libzmq3-dev linuxqq net-tools nlohmann-json3-dev openfortivpn openssh-server
pipx python3-colcon-common-extensions python3-opencv python3-pip python3-rosdep
ros-humble-desktop ros-humble-joint-state-publisher ros-humble-mrpt-apps
ros-humble-mrpt-navigation ros-humble-rqt-tf-tree ros-humble-usb-cam ros-humble-xacro
rustdesk shellcheck shfmt sogoupinyin sshpass tcptraceroute terminator
todesk vim vlc vokoscreen-ng wechat wemeet wps-office zoom
```

Ubuntu desktop defaults, base shell/coreutils, the boot stack, kernel/HWE, language packs, and dependency-only libraries are intentionally excluded. See §2.0.

## Appendix B — User-installed snaps

```text
obsidian (--classic)
```

Only user-installed snaps are listed. No flatpaks.

## Appendix C — VS Code extensions (49)

```text
alefragnani.project-manager
astx-jp.vscode-pptx-viewer
chanhx.crabviz
cheshirekow.cmake-format
clemenspeters.format-json
codezombiech.gitignore
corotata.pptx-preview
cschlosser.doxdocgen
docker.docker
dotjoshjohnson.xml
evendead.help-me-add
fabiospampinato.vscode-diff
golang.go
grimmer.vscode-back-forward-button
jaehyunshim.vscode-ros2
jeff-hykin.better-cpp-syntax
mhutchie.git-graph
mkhl.shfmt
ms-azuretools.vscode-containers
ms-azuretools.vscode-docker
ms-ceintl.vscode-language-pack-zh-hans
ms-python.black-formatter
ms-python.debugpy
ms-python.python
ms-python.vscode-pylance
ms-python.vscode-python-envs
ms-vscode-remote.remote-containers
ms-vscode-remote.remote-ssh
ms-vscode-remote.remote-ssh-edit
ms-vscode.cpptools
ms-vscode.cpptools-extension-pack
ms-vscode.cpptools-themes
ms-vscode.makefile-tools
ms-vscode.remote-explorer
msyrus.go-doc
natizyskunk.sftp
nonanonno.vscode-ros2
platformio.platformio-ide
pomber.git-file-history
pptxviewerpro.pptx-viewer-pro
rooveterinaryinc.roo-cline
tomoki1207.pdf
twxs.cmake
uctakeoff.vscode-counter
vizards.deepseek-v4-for-copilot
waderyan.gitblame
wps-editor.wps-editor
xaver.clang-format
yzhang.markdown-all-in-one
```

## Appendix D — pip `--user` package names (unpinned)

Reference inventory only — install the top-level packages and let pip resolve current compatible versions.

```text
charset-normalizer
clang-format
cuda-bindings
cuda-pathfinder
cuda-toolkit
dlib
face-recognition
face-recognition-models
filelock
fsspec
ImageIO
joblib
lazy-loader
llvmlite
lxml
ml_dtypes
mpmath
networkx
numba
numpy
nvidia-cublas
nvidia-cublas-cu12
nvidia-cuda-cupti
nvidia-cuda-cupti-cu12
nvidia-cuda-nvrtc
nvidia-cuda-nvrtc-cu12
nvidia-cuda-runtime
nvidia-cuda-runtime-cu12
nvidia-cudnn-cu12
nvidia-cudnn-cu13
nvidia-cufft
nvidia-cufft-cu12
nvidia-cufile
nvidia-cufile-cu12
nvidia-curand
nvidia-curand-cu12
nvidia-cusolver
nvidia-cusolver-cu12
nvidia-cusparse
nvidia-cusparse-cu12
nvidia-cusparselt-cu12
nvidia-cusparselt-cu13
nvidia-nccl-cu12
nvidia-nccl-cu13
nvidia-nvjitlink
nvidia-nvjitlink-cu12
nvidia-nvshmem-cu12
nvidia-nvshmem-cu13
nvidia-nvtx
nvidia-nvtx-cu12
onnx
onnx-ir
onnxscript
openai-whisper
pathspec
pillow
protobuf
pydub
regex
requests
scikit-image
scikit-learn
scipy
SpeechRecognition
sympy
threadpoolctl
tifffile
tiktoken
torch
torchvision
tqdm
triton
typing_extensions
yamllint
```
