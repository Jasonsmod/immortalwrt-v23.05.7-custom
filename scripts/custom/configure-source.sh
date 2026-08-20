#!/bin/sh

set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TOPDIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
LUCI_COLLECTION="$TOPDIR/feeds/luci/collections/luci/Makefile"

[ -f "$LUCI_COLLECTION" ] || {
	printf '错误：请先执行 feeds update/install。\n' >&2
	exit 1
}

# 旧版 LuCI 集合会声明 Bootstrap 默认主题；新版集合将主题选择交给目标配置。
if grep -q '+luci-theme-bootstrap' "$LUCI_COLLECTION"; then
	sed -i 's/+luci-theme-bootstrap/+luci-theme-argon/g' "$LUCI_COLLECTION"
fi

if grep -q '+luci-theme-argon' "$LUCI_COLLECTION"; then
	printf 'LuCI 默认主题依赖已切换为 Argon。\n'
else
	printf 'LuCI 集合未声明主题依赖，将由目标配置直接选择 Argon。\n'
fi
