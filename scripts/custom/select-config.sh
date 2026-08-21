#!/bin/sh

set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TOPDIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
target="${1-}"
build_date="${BUILD_DATE:-$(TZ="${TZ:-Asia/Shanghai}" date '+%Y-%m-%d')}"
config_tmp="$TOPDIR/.config.custom.$$"

case "$target" in
	r619ac|x86|x86_64) ;;
	*)
		printf '用法：%s {r619ac|x86|x86_64}\n' "$0" >&2
		exit 1
		;;
esac

trap 'rm -f "$config_tmp"' EXIT INT TERM

cp "$TOPDIR/configs/$target.config" "$TOPDIR/.config"

sed \
	-e '/^CONFIG_IMAGEOPT=/d' \
	-e '/^# CONFIG_IMAGEOPT is not set$/d' \
	-e '/^CONFIG_VERSIONOPT=/d' \
	-e '/^# CONFIG_VERSIONOPT is not set$/d' \
	-e '/^CONFIG_VERSION_CODE=/d' \
	"$TOPDIR/.config" > "$config_tmp"
printf 'CONFIG_IMAGEOPT=y\nCONFIG_VERSIONOPT=y\nCONFIG_VERSION_CODE="r28359-1db8d96e4866 / Build %s"\n' "$build_date" >> "$config_tmp"
mv "$config_tmp" "$TOPDIR/.config"

make -C "$TOPDIR" defconfig
printf '已生成 %s 的完整 .config，首页编译日期：%s。\n' "$target" "$build_date"
