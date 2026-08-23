#!/bin/sh

set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TOPDIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
LUCI_COLLECTIONS="$TOPDIR/feeds/luci/collections"

[ -d "$LUCI_COLLECTIONS" ] || {
	printf '错误：请先执行 feeds update/install。\n' >&2
	exit 1
}

sed -i 's/192.168.1.1/192.168.50.1/g' "$TOPDIR/package/base-files/files/bin/config_generate"

# Bootstrap 可能由 luci-light 等间接集合引入，需要检查所有 LuCI collections。
find "$LUCI_COLLECTIONS" -type f -name Makefile \
	-exec sed -i 's/+luci-theme-bootstrap/+luci-theme-argon/g' {} +

if grep -Rqs --include=Makefile '+luci-theme-bootstrap' "$LUCI_COLLECTIONS"; then
	printf '错误：LuCI collections 中仍存在 Bootstrap 主题依赖。\n' >&2
	exit 1
fi

printf 'LuCI collections 的默认主题依赖已切换为 Argon。\n'
