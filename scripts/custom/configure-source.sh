#!/bin/sh

set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TOPDIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
LUCI_COLLECTION="$TOPDIR/feeds/luci/collections/luci/Makefile"

[ -f "$LUCI_COLLECTION" ] || {
	printf '错误：请先执行 feeds update/install。\n' >&2
	exit 1
}

# 保留 LuCI 完整集合，但将其默认 Bootstrap 依赖替换为 Argon。
if grep -q '+luci-theme-bootstrap' "$LUCI_COLLECTION"; then
	sed -i 's/+luci-theme-bootstrap/+luci-theme-argon/g' "$LUCI_COLLECTION"
fi

grep -q '+luci-theme-argon' "$LUCI_COLLECTION" || {
	printf '错误：无法将 LuCI 默认主题切换为 Argon。\n' >&2
	exit 1
}

printf 'LuCI 默认主题依赖已切换为 Argon。\n'
