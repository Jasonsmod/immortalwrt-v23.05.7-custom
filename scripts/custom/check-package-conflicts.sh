#!/bin/sh

set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TOPDIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
REPORT_DIR="$TOPDIR/tmp"
DEFINITIONS="$REPORT_DIR/package-definitions.tsv"
CONFLICTS="$REPORT_DIR/package-conflicts.txt"

mkdir -p "$REPORT_DIR"
: >"$DEFINITIONS"

scan_makefile() {
	awk '
		/^define Package\/[A-Za-z0-9_.+@-]+$/ {
			name = $0
			sub(/^define Package\//, "", name)
			printf "%s\t%s\n", name, FILENAME
		}
	' "$1" >>"$DEFINITIONS"
}

find "$TOPDIR/package" \
	-path "$TOPDIR/package/feeds" -prune -o \
	-type f -name Makefile -print |
while IFS= read -r makefile; do
	scan_makefile "$makefile"
done

if [ -d "$TOPDIR/feeds" ]; then
	find "$TOPDIR/feeds" -type f -name Makefile -print |
	while IFS= read -r makefile; do
		scan_makefile "$makefile"
	done
fi

sort -u "$DEFINITIONS" -o "$DEFINITIONS"
awk -F '\t' '
	BEGIN { previous = ""; files = ""; count = 0 }
	function flush() {
		if (count > 1) {
			print previous ":"
			print files
			print ""
		}
	}
	{
		if ($1 != previous) {
			flush()
			previous = $1
			files = "  - " $2
			count = 1
		} else {
			files = files "\n  - " $2
			count++
		}
	}
	END { flush() }
' "$DEFINITIONS" >"$CONFLICTS"

if [ -s "$CONFLICTS" ]; then
	printf '错误：发现重复软件包定义：\n' >&2
	cat "$CONFLICTS" >&2
	exit 1
fi

printf '未发现重复软件包定义。\n'
