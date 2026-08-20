#!/bin/sh

set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TOPDIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
target="${1-}"

case "$target" in
	r619ac|x86|x86_64) ;;
	*)
		printf '用法：%s {r619ac|x86|x86_64}\n' "$0" >&2
		exit 1
		;;
esac

cp "$TOPDIR/configs/$target.config" "$TOPDIR/.config"
make -C "$TOPDIR" defconfig
printf '已生成 %s 的完整 .config。\n' "$target"
