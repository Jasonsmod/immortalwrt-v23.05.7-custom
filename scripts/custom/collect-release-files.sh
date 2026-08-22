#!/bin/sh

set -eu

target="${1-}"
source_dir="${2-}"
destination_dir="${3-}"

fail() {
	printf '错误：%s\n' "$1" >&2
	exit 1
}

case "$target" in
	r619ac|x86|x86_64) ;;
	*) fail "未知固件目标 $target" ;;
esac

[ -d "$source_dir" ] || fail "固件源目录不存在：$source_dir"

if [ -d "$destination_dir" ] && find "$destination_dir" -mindepth 1 -print -quit | grep -q .; then
	fail "目标目录不是空目录：$destination_dir"
fi
mkdir -p "$destination_dir"

match_list="$(mktemp)"
trap 'rm -f "$match_list"' EXIT INT TERM

copy_one() {
	label="$1"
	pattern="$2"
	: > "$match_list"
	find "$source_dir" -type f -name "$pattern" -print > "$match_list"
	count="$(wc -l < "$match_list" | tr -d '[:space:]')"
	[ "$count" -eq 1 ] || fail "$target 的 $label 应恰好有 1 个，实际找到 $count 个"
	file="$(sed -n '1p' "$match_list")"
	destination="$destination_dir/$(basename "$file")"
	[ ! -e "$destination" ] || fail "发布文件重名：$(basename "$file")"
	cp "$file" "$destination"
}

case "$target" in
	r619ac)
		copy_one 'factory.ubi' '*-factory.ubi'
		copy_one 'sysupgrade.bin' '*-sysupgrade.bin'
		copy_one 'sha256sums' 'sha256sums'
		copy_one 'version.buildinfo' '*version.buildinfo'
		expected=4
		;;
	x86|x86_64)
		copy_one 'squashfs-combined.img' '*-squashfs-combined.img'
		copy_one 'squashfs-combined.img.gz' '*-squashfs-combined.img.gz'
		copy_one 'squashfs-combined-efi.img.gz' '*-squashfs-combined-efi.img.gz'
		copy_one 'sha256sums' 'sha256sums'
		copy_one 'version.buildinfo' '*version.buildinfo'
		expected=5
		;;
esac

actual="$(find "$destination_dir" -maxdepth 1 -type f | wc -l | tr -d '[:space:]')"
[ "$actual" -eq "$expected" ] || fail "$target 应整理出 $expected 个文件，实际得到 $actual 个"

printf '%s Release 文件整理完成，共 %s 个。\n' "$target" "$actual"