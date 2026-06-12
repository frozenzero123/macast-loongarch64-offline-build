# Macast loongarch64 离线构建包

这个包用于解决“龙芯/银河麒麟机器无法访问 GitHub”的问题。包里已经包含：

- `repos/Macast`：Macast v0.7 [源码](https://github.com/xfangfang/Macast)
- `repos/pystray`：作者 fork 的 pystray 源码
- `repos/pyperclip`：作者 fork 的 pyperclip 源码
- `wheels/`：离线 Python 依赖包，包括 `appdirs`、`CherryPy`、`PyInstaller` 等
- `scripts/build_on_loongarch64.sh`：在你的银河麒麟 V10 SP1 / `loongarch64` 真机上构建官方同结构 `.deb` 的脚本

## 为什么必须在你的龙芯机器上构建

官方 Linux release 的几十 MB 包是 PyInstaller 冻结出的单文件程序。PyInstaller 的 bootloader 和冻结结果必须和 CPU 架构、ABI 匹配。你的系统是旧世界 `loongarch64`，不能使用 Debian Ports 的新世界 `loong64`，所以不能在 x86_64 环境里直接生成可运行的最终二进制。

## 使用方法

在你的龙芯/银河麒麟机器上：

```bash
tar -xzf macast-loongarch64-offline-build.tar.gz
cd macast-loongarch64-offline-build
chmod +x scripts/build_on_loongarch64.sh
./scripts/build_on_loongarch64.sh
```

构建成功后会在当前目录生成：

- `Macast-Linux-v0.7-loongarch64`
- `Macast-Linux-v0.7-loongarch64.deb`

## 网络要求

脚本不会访问 GitHub，也不会访问 PyPI/清华 PyPI。它只会访问你的麒麟 apt 源安装系统依赖；Python 依赖全部从当前包内的 `wheels/` 目录离线安装。
