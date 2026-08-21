<img src="https://avatars.githubusercontent.com/u/53193414?s=200&v=4" alt="logo" width="200" height="200" align="right">

# Project ImmortalWrt

ImmortalWrt is a fork of [OpenWrt](https://openwrt.org), with more packages ported, more devices supported, default optimized profiles and localization modifications for mainland China users.<br/>
Compared to upstream, we allow to use (non-upstreamable) modifications/hacks to provide better feature/performance/support.

This repository contains a custom multi-target build based on ImmortalWrt v23.05.7.

Default login address: http://192.168.50.1, username: __root__, password: __password__.

## 最新固件下载 ✅ 已完成

固件发布到 [GitHub Releases](https://github.com/Jasonsmod/immortalwrt-v23.05.7-custom/releases)，以下链接由 GitHub Actions 自动更新。

<!-- FIRMWARE_RELEASES_START -->
首次成功发布后自动生成下载链接。
<!-- FIRMWARE_RELEASES_END -->

## 定制固件架构 ✅ 已完成

本仓库在 ImmortalWrt `v23.05.7` 完整源码上维护三套独立 seed config，通过相同的软件包同步、默认配置和验证流程生成固件。

| 配置文件 | 目标 | 设备/Profile |
|---|---|---|
| `configs/r619ac.config` | `ipq40xx/generic` | P&W R619AC 128M NAND |
| `configs/x86.config` | `x86/generic` | 32 位通用 x86 |
| `configs/x86_64.config` | `x86/64` | 64 位通用 x86_64 |

R619AC 不构建 64M 版本。x86 和 x86_64 的根文件系统分区默认设为 512 MiB。

## 默认系统配置 ✅ 已完成

| 项目 | 默认值 |
|---|---|
| Web/SSH 地址 | `192.168.50.1` |
| 用户名 | `root` |
| 密码 | `password`（固件内保存为密码哈希） |
| LuCI 主题 | Argon |
| opkg 镜像 | `https://mirrors.vsean.net/openwrt` |
| DNS/DHCP | `dnsmasq-full` |
| TCP 拥塞控制 | BBR，默认队列规则为 FQ |

默认设置由 `custom-firmware-defaults` 包在首次启动时应用。软件源的具体架构路径仍由 ImmortalWrt 构建系统按照目标自动生成。

## 默认应用 ✅ 已完成

- PassWall：`luci-app-passwall` 及其依赖。
- OpenClash：`luci-app-openclash` 及其依赖。
- MOSDNS：`luci-app-mosdns`、`mosdns`、`v2dat`。
- WireGuard：LuCI 协议、工具和内核模块。
- OpenVPN 服务端/客户端：LuCI、OpenSSL 版本、Easy-RSA、TUN 和证书工具。
- MultiWAN：`luci-app-mwan3`、`mwan3`。
- 网络唤醒：`luci-app-wol`、`etherwake`。
- KMS：`luci-app-vlmcsd`、`vlmcsd`。
- 动态 DNS：LuCI、DDNS Scripts 和阿里云服务脚本。
- BBR：`kmod-tcp-bbr` 和 FQ 调度支持。
- 
## 本地编译流程 ✅ 已完成

必须在大小写敏感的 Linux 文件系统中编译，源码路径不得包含空格或非 ASCII 字符。Windows 用户应将仓库放入 WSL2 的 Linux 文件系统，而不是直接在 NTFS 项目目录中编译。

```bash
bash scripts/custom/restore-symlinks.sh
./scripts/feeds update -a
./scripts/feeds install -a
bash scripts/custom/prepare-packages.sh
bash scripts/custom/configure-source.sh
bash scripts/custom/check-package-conflicts.sh
bash scripts/custom/select-config.sh r619ac   # 或 x86、x86_64
bash scripts/custom/verify-config.sh r619ac
make download -j8
make -j"$(nproc)" || make -j1 V=s
```

构建结果位于 `bin/targets/`。

## Download
Built firmware images are available for many architectures and come with a package selection to be used as WiFi home router. To quickly find a factory image usable to migrate from a vendor stock firmware to ImmortalWrt, try the *Firmware Selector*.

- [ImmortalWrt Firmware Selector](https://firmware-selector.immortalwrt.org/)

If your device is supported, please follow the **Info** link to see install instructions or consult the support resources listed below.

## Development
To build your own firmware you need a GNU/Linux, BSD or MacOSX system (case sensitive filesystem required). Cygwin is unsupported because of the lack of a case sensitive file system.<br/>

  ### Requirements
  To build with this project, Debian 11 is preferred. And you need use the CPU based on AMD64 architecture, with at least 4GB RAM and 25 GB available disk space. Make sure the __Internet__ is accessible.

  The following tools are needed to compile ImmortalWrt, the package names vary between distributions.

  - Here is an example for Debian/Ubuntu users:<br/>
    - Method 1:
      <details>
        <summary>Setup dependencies via APT</summary>

        ```bash
        sudo apt update -y
        sudo apt full-upgrade -y
        sudo apt install -y ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential \
          bzip2 ccache clang cmake cpio curl device-tree-compiler ecj fastjar flex gawk gettext gcc-multilib \
          g++-multilib git gnutls-dev gperf haveged help2man intltool lib32gcc-s1 libc6-dev-i386 libelf-dev \
          libglib2.0-dev libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev libncurses-dev libpython3-dev \
          libreadline-dev libssl-dev libtool libyaml-dev libz-dev lld llvm lrzsz mkisofs msmtp nano \
          ninja-build p7zip p7zip-full patch pkgconf python3 python3-pip python3-ply python3-docutils \
          python3-pyelftools qemu-utils re2c rsync scons squashfs-tools subversion swig texinfo uglifyjs \
          upx-ucl unzip vim wget xmlto xxd zlib1g-dev
        ```
      </details>
    - Method 2:
      ```bash
      sudo bash -c 'bash <(curl -s https://build-scripts.immortalwrt.org/init_build_environment.sh)'
      ```

  Note:
  - Do everything as an unprivileged user, not root, without sudo.
  - Using CPUs based on other architectures should be fine to compile ImmortalWrt, but more hacks are needed - No warranty at all.
  - You must __not__ have spaces or non-ascii characters in PATH or in the work folders on the drive.
  - If you're using Windows Subsystem for Linux (or WSL), removing Windows folders from PATH is required, please see [Build system setup WSL](https://openwrt.org/docs/guide-developer/build-system/wsl) documentation.
  - Using macOS as the host build OS is __not__ recommended. No warranty at all. You can get tips from [Build system setup macOS](https://openwrt.org/docs/guide-developer/build-system/buildroot.exigence.macosx) documentation.
  - For more details, please see [Build system setup](https://openwrt.org/docs/guide-developer/build-system/install-buildsystem) documentation.

  ### Quickstart
  1. Run `git clone -b <branch> --single-branch --filter=blob:none https://github.com/Jasonsmod/immortalwrt-v23.05.7-custom.git` to clone this custom source repository.
  2. Run `cd immortalwrt` to enter source directory.
  3. Run `./scripts/feeds update -a` to obtain all the latest package definitions defined in feeds.conf / feeds.conf.default
  4. Run `./scripts/feeds install -a` to install symlinks for all obtained packages into package/feeds/
  5. Run `make menuconfig` to select your preferred configuration for the toolchain, target system & firmware packages.
  6. Run `make` to build your firmware. This will download all sources, build the cross-compile toolchain and then cross-compile the GNU/Linux kernel & all chosen applications for your target system.

  ### Related Repositories
  The main repository uses multiple sub-repositories to manage packages of different categories. All packages are installed via the OpenWrt package manager called opkg. If you're looking to develop the web interface or port packages to ImmortalWrt, please find the fitting repository below.
  - [LuCI Web Interface](https://github.com/immortalwrt/luci): Modern and modular interface to control the device via a web browser.
  - [ImmortalWrt Packages](https://github.com/immortalwrt/packages): Community repository of ported packages.
  - [OpenWrt Routing](https://github.com/openwrt/routing): Packages specifically focused on (mesh) routing.
  - [OpenWrt Video](https://github.com/openwrt/video): Packages specifically focused on display servers and clients (Xorg and Wayland).

## Support Information
For a list of supported devices see the [OpenWrt Hardware Database](https://openwrt.org/supported_devices)
  ### Documentation
  - [Quick Start Guide](https://openwrt.org/docs/guide-quick-start/start)
  - [User Guide](https://openwrt.org/docs/guide-user/start)
  - [Developer Documentation](https://openwrt.org/docs/guide-developer/start)
  - [Technical Reference](https://openwrt.org/docs/techref/start)

  ### Support Community
  - Support Chat: group [@ctcgfw_openwrt_discuss](https://t.me/ctcgfw_openwrt_discuss) on [Telegram](https://telegram.org/).
  - Support Chat: group [#immortalwrt](https://matrix.to/#/#immortalwrt:matrix.org) on [Matrix](https://matrix.org/).

## License
ImmortalWrt is licensed under [GPL-2.0-only](https://spdx.org/licenses/GPL-2.0-only.html).

## Acknowledgements
<table>
  <tr>
    <td><a href="https://dlercloud.com/"><img src="https://user-images.githubusercontent.com/22235437/111103249-f9ec6e00-8588-11eb-9bfc-67cc55574555.png" width="183" height="52" border="0" alt="Dler Cloud"></a></td>
    <td><a href="https://www.jetbrains.com/"><img src="https://resources.jetbrains.com/storage/products/company/brand/logos/jb_square.png" width="120" height="120" border="0" alt="JetBrains Black Box Logo logo"></a></td>
    <td><a href="https://sourceforge.net/"><img src="https://sourceforge.net/sflogo.php?type=17&group_id=3663829" alt="SourceForge" width=200></a></td>
  </tr>
</table>

[2026-08-21] 修改 | 模块：GitHub Release 发布 | 内容：x86 和 x86_64 仅保留 squashfs-combined 镜像、sha256sums 与 version.buildinfo。

[2026-08-21] 修改 | 模块：GitHub Release 发布 | 内容：R619AC 仅保留 factory.ubi、sysupgrade.bin、sha256sums 与 version.buildinfo。

[2026-08-21] 修复 | 模块：MOSDNS 与 R619AC | 内容：修复 MOSDNS LuCI 页面资源被误删的问题，并增加 R619AC 刷机镜像结构和设备元数据校验。
