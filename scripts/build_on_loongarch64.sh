#!/usr/bin/env bash
# 在银河麒麟 V10 SP1 / loongarch64 真机上构建 Macast 官方同结构安装包。
# 本脚本不访问 GitHub，源码来自当前离线包的 repos/ 目录。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MACAST_SRC="$ROOT/repos/Macast"
PYSTRAY_SRC="$ROOT/repos/pystray"
PYPERCLIP_SRC="$ROOT/repos/pyperclip"
WHEELS="$ROOT/wheels"
OUT_DIR="$ROOT"

ARCH="$(dpkg --print-architecture 2>/dev/null || true)"
if [ "$ARCH" != "loongarch64" ]; then
    echo "错误：当前系统架构是 '$ARCH'，不是 loongarch64。"
    echo "本脚本只能用于旧世界 loongarch64（银河麒麟/统信等），不能用于 Debian Ports loong64。"
    exit 1
fi

echo "==> 当前架构：$ARCH"
echo "==> 源码目录：$MACAST_SRC"

echo "==> 安装系统构建依赖"
sudo apt update
sudo apt install -y \
    gettext dpkg-dev binutils \
    python3 python3-pip python3-venv python3-dev \
    build-essential pkg-config \
    libxml2-dev libxslt1-dev zlib1g-dev libjpeg-dev libffi-dev \
    python3-gi libgtk-3-dev python3-xlib \
    python3-lxml python3-pil python3-netifaces python3-requests \
    mpv

# 两套托盘库在不同发行版名字不同，尽量都尝试，失败不退出。
sudo apt install -y libappindicator3-dev gir1.2-appindicator3-0.1 || true
sudo apt install -y libayatana-appindicator3-dev gir1.2-ayatanaappindicator3-0.1 || true

cd "$MACAST_SRC"
VERSION="$(cat macast/.version)"
DIST_BIN="$OUT_DIR/Macast-Linux-v${VERSION}-loongarch64"
DIST_DEB="$OUT_DIR/Macast-Linux-v${VERSION}-loongarch64.deb"

echo "==> 编译语言文件"
for file in i18n/*; do
    msgfmt -o "$file/LC_MESSAGES/macast.mo" "$file/LC_MESSAGES/macast.po"
done

echo "==> 创建 Python 构建环境"
rm -rf .venv
python3 -m venv --system-site-packages .venv
source .venv/bin/activate

echo "==> 从离线 wheels 目录升级 setuptools/wheel（不访问 PyPI）"
python -m pip install --no-index --find-links "$WHEELS" --upgrade setuptools wheel

echo "==> 从离线 wheels 目录安装 Python 依赖（不访问 PyPI）"
python -m pip install --no-index --find-links "$WHEELS" \
    appdirs CherryPy cheroot portend tempora more-itertools zc.lockfile \
    jaraco.collections jaraco.functools jaraco.text jaraco.classes \
    jaraco.context importlib-resources \
    autocommand inflect typeguard six python-dateutil pytz

echo "==> 安装 pystray/pyperclip（直接复制源码，绕开 setup.py，不访问网络）"
SITE_PACKAGES="$(python - <<'PY'
import site
paths = site.getsitepackages()
print(paths[0])
PY
)"
rm -rf "$SITE_PACKAGES/pystray" "$SITE_PACKAGES/pyperclip"
cp -a "$PYSTRAY_SRC/lib/pystray" "$SITE_PACKAGES/"
cp -a "$PYPERCLIP_SRC/src/pyperclip" "$SITE_PACKAGES/"
python - <<'PY'
import pystray, pyperclip
print("pystray/pyperclip 源码复制安装完成")
PY

echo "==> 从离线源码包安装 PyInstaller，并在本机编译 loongarch64 bootloader"
python -m pip install --no-index --find-links "$WHEELS" --no-build-isolation pyinstaller==6.11.1

echo "==> PyInstaller 构建"
rm -rf build app dist
pyinstaller --noconfirm -F -w \
    --additional-hooks-dir=. \
    --add-data="macast/.version:." \
    --add-data="macast/xml/*:macast/xml" \
    --add-data="i18n/zh_CN/LC_MESSAGES/*.mo:i18n/zh_CN/LC_MESSAGES" \
    --add-data="macast/assets/*:macast/assets" \
    --add-data="macast/assets/fonts/*:macast/assets/fonts" \
    --exclude-module=tkinter \
    --distpath="app" \
    Macast.py

cp app/Macast "$DIST_BIN"
chmod 0755 "$DIST_BIN"

echo "==> 生成 deb"
rm -rf dist
mkdir -p dist/DEBIAN dist/usr/bin dist/usr/share/applications dist/usr/share/icons

cat > dist/DEBIAN/control <<CTRL
Package: macast
Version: ${VERSION}
Architecture: loongarch64
Maintainer: local loongarch64 build
Section: video
Priority: optional
Description: DLNA Media Renderer
Depends: mpv
CTRL

cat > dist/usr/share/applications/macast.desktop <<DESKTOP
[Desktop Entry]
Name=Macast
Name[zh_CN]=Macast 投屏接收器
Comment=DLNA Media Renderer
Comment[zh_CN]=DLNA 投屏接收器
Exec=/usr/bin/macast
Icon=/usr/share/icons/Macast.png
Terminal=false
Type=Application
Categories=Video;AudioVideo;Player;
DESKTOP

cp app/Macast dist/usr/bin/macast
cp macast/assets/icon.png dist/usr/share/icons/Macast.png
dpkg-deb --build dist "$DIST_DEB"

echo
echo "构建完成："
ls -lh "$DIST_BIN" "$DIST_DEB"
echo
echo "安装命令："
echo "sudo dpkg -i '$DIST_DEB'"
