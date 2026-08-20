#!/bin/sh

set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TOPDIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"

restore_link() {
	path="$TOPDIR/$1"
	target="$2"

	if [ -L "$path" ] && [ "$(readlink "$path")" = "$target" ]; then
		return 0
	fi

	rm -f -- "$path"
	mkdir -p "$(dirname -- "$path")"
	ln -s "$target" "$path"
}

# GitHub 源码 ZIP 在 Windows 解压时无法创建的三个上游符号链接。
restore_link "package/base-files/files/etc/os-release" "../usr/lib/os-release"
restore_link "package/network/config/netifd/files/sbin/ifdown" "ifup"
restore_link "target/linux/sunxi/base-files/lib/firmware/brcm/brcmfmac43430a0-sdio.txt" "brcmfmac43430-sdio.txt"

printf '上游符号链接已恢复。\n'
