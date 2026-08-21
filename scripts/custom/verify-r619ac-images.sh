#!/bin/sh

set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TOPDIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
TARGET_DIR="$TOPDIR/bin/targets/ipq40xx/generic"

fail() {
	printf '错误：%s\n' "$*" >&2
	exit 1
}

find_image() {
	pattern="$1"
	found=""
	for file in "$TARGET_DIR"/$pattern; do
		[ -f "$file" ] || continue
		[ -z "$found" ] || fail "匹配到多个 R619AC 镜像：$pattern"
		found="$file"
	done
	[ -n "$found" ] || fail "缺少 R619AC 镜像：$pattern"
	printf '%s\n' "$found"
}

[ -d "$TARGET_DIR" ] || fail "缺少 R619AC 输出目录：$TARGET_DIR"

factory="$(find_image '*-p2w_r619ac-128m-squashfs-factory.ubi')"
sysupgrade="$(find_image '*-p2w_r619ac-128m-squashfs-sysupgrade.bin')"

factory_size="$(wc -c < "$factory")"
block_size=131072
max_factory_size=134217728
[ "$factory_size" -gt 0 ] || fail "factory.ubi 是空文件"
[ "$factory_size" -lt "$max_factory_size" ] || fail "factory.ubi 大小达到或超过 128 MiB"
[ $((factory_size % block_size)) -eq 0 ] || fail "factory.ubi 未按 128 KiB 擦除块对齐"

ubi_magic="$(od -An -tx1 -N4 "$factory" | tr -d ' \n')"
[ "$ubi_magic" = "55424923" ] || fail "factory.ubi 缺少有效 UBI 头"

tar -tf "$sysupgrade" | grep -qx 'sysupgrade-p2w_r619ac-128m/CONTROL' || \
	fail "sysupgrade.bin 缺少 p2w_r619ac-128m 控制目录"

fwtool="$TOPDIR/staging_dir/host/bin/fwtool"
[ -x "$fwtool" ] || fail "缺少主机端 fwtool：$fwtool"
metadata="$(mktemp)"
trap 'rm -f "$metadata"' EXIT
"$fwtool" -q -i "$metadata" "$sysupgrade" || fail "无法读取 sysupgrade.bin 元数据"
grep -Fq '"p2w,r619ac-128m"' "$metadata" || fail "sysupgrade.bin 不支持 p2w,r619ac-128m"
grep -Eq '"compat_version"[[:space:]]*:[[:space:]]*"1\.1"' "$metadata" || \
	fail "sysupgrade.bin 的兼容版本不是 1.1"

printf 'R619AC 镜像校验通过：\n'
printf '  factory: %s (%s bytes)\n' "$(basename "$factory")" "$factory_size"
printf '  sysupgrade: %s\n' "$(basename "$sysupgrade")"
