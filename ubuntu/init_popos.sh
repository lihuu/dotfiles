#!/usr/bin/env bash
set -e

echo "==== 1. 系统更新 ===="
sudo apt update && sudo apt upgrade -y
sudo apt install -y build-essential curl wget git unzip gnome-tweaks software-properties-common apt-transport-https ca-certificates

echo "==== 2. 安装 Homebrew (Linuxbrew) ===="
if ! command -v brew &>/dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >>~/.bashrc
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

echo "==== 3. 安装游戏环境 ===="
sudo apt install -y steam vulkan-tools libvulkan1 vulkan-utils
flatpak install -y flathub net.davidotek.pupgui2 # ProtonUp-Qt

echo "==== 4. 开发环境 ===="
# Java (SDKMAN)
if [ ! -d "$HOME/.sdkman" ]; then
  curl -s "https://get.sdkman.io" | bash
  source "$HOME/.sdkman/bin/sdkman-init.sh"
  sdk install java 21.0.2-tem
  sdk install maven
  sdk install gradle
fi

# Node.js (FNM)
if ! command -v fnm &>/dev/null; then
  curl -fsSL https://fnm.vercel.app/install | bash
  source ~/.bashrc
  fnm install --lts
  npm install -g pnpm yarn
fi

# Rust
if ! command -v rustc &>/dev/null; then
  curl https://sh.rustup.rs -sSf | sh -s -- -y
  source "$HOME/.cargo/env"
fi

# C/C++
sudo apt install -y cmake gdb

# Android SDK
sudo apt install -y android-sdk android-tools-adb android-tools-fastboot

echo "==== 5. 安装 Vim / Neovim / VS Code ===="
sudo apt install -y vim neovim
if ! command -v code &>/dev/null; then
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor >packages.microsoft.gpg
  sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
  sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
  sudo apt update
  sudo apt install -y code
  rm -f packages.microsoft.gpg
fi

echo "==== 6. 安装 Rclone 并配置 Free up space 按需访问 ===="
sudo apt install -y rclone
RCLONE_MOUNT_SCRIPT="$HOME/.local/bin/mount_gdrive.sh"
mkdir -p "$(dirname "$RCLONE_MOUNT_SCRIPT")"
cat >"$RCLONE_MOUNT_SCRIPT" <<'EOF'
#!/usr/bin/env bash
MOUNT_DIR="$HOME/GoogleDrive"
mkdir -p "$MOUNT_DIR"
rclone mount gdrive: "$MOUNT_DIR" \
    --vfs-cache-mode full \
    --vfs-cache-max-size 10G \
    --vfs-cache-max-age 24h \
    --daemon
EOF
chmod +x "$RCLONE_MOUNT_SCRIPT"
echo "提示: 请先运行 'rclone config' 配置 gdrive/onedrive 远程，然后执行 mount_gdrive.sh 挂载。"

echo "==== 7. 安装 Xray 代理工具 ===="
if ! command -v xray &>/dev/null; then
  XRAY_VER=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep tag_name | cut -d '"' -f 4)
  wget https://github.com/XTLS/Xray-core/releases/download/${XRAY_VER}/Xray-linux-64.zip
  sudo unzip Xray-linux-64.zip -d /usr/local/bin
  rm Xray-linux-64.zip
  sudo mkdir -p /etc/xray
  sudo tee /etc/xray/config.json >/dev/null <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "port": 10809,
      "listen": "127.0.0.1",
      "protocol": "socks",
      "settings": { "udp": true }
    },
    {
      "port": 10810,
      "listen": "127.0.0.1",
      "protocol": "http"
    }
  ],
  "outbounds": [
    {
      "protocol": "vmess",
      "settings": {
        "vnext": [
          {
            "address": "your.server.com",
            "port": 443,
            "users": [
              {
                "id": "UUID-REPLACE-ME",
                "alterId": 0,
                "security": "auto"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls"
      }
    }
  ]
}
EOF
  sudo tee /etc/systemd/system/xray.service >/dev/null <<EOF
[Unit]
Description=Xray Service
After=network.target

[Service]
ExecStart=/usr/local/bin/xray -config /etc/xray/config.json
Restart=on-failure
User=nobody
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF
  sudo systemctl daemon-reload
  sudo systemctl enable xray
  echo "Xray 已安装，请修改 /etc/xray/config.json 中的服务器信息，然后运行："
  echo "  sudo systemctl start xray"
fi

echo "==== 8. 通过 Homebrew 安装额外工具 ===="
brew install htop tree bat fzf

echo "==== 9. macOS 键位映射 ===="
gsettings set org.gnome.desktop.input-sources xkb-options "['ctrl:swap_lwin_lctl']"

echo "==== 10. 清理 ===="
sudo apt autoremove -y

echo "✅ 所有安装完成！"
echo "请重启系统，并执行 'rclone config' 配置网盘；修改 /etc/xray/config.json 启动代理。"
