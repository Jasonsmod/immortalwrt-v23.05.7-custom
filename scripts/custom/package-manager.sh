#!/bin/sh

set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TOPDIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
CUSTOM_PACKAGE_DIR="${CUSTOM_PACKAGE_DIR:-$TOPDIR/package/custom-sources}"
PACKAGE_TMP_DIR="${PACKAGE_TMP_DIR:-$TOPDIR/tmp/custom-packages}"

fail() {
	printf '错误：%s\n' "$*" >&2
	exit 1
}

validate_name() {
	case "$1" in
		''|*[!A-Za-z0-9._-]*) fail "非法包组名称：$1" ;;
	esac
}

validate_repository() {
	repository="$1"
	owner="${repository%%/*}"
	project="${repository#*/}"
	[ "$owner" != "$repository" ] || fail "仓库必须使用 owner/repo 格式：$repository"
	[ "${project#*/}" = "$project" ] || fail "仓库路径层级不正确：$repository"
	validate_name "$owner"
	validate_name "$project"
}

validate_subdirectory() {
	case "$1" in
		'' ) return 0 ;;
		/*|*'..'*|*[!A-Za-z0-9._/-]*) fail "非法仓库子目录：$1" ;;
	esac
}

safe_remove_tree() {
	target="$1"
	case "$target" in
		"$CUSTOM_PACKAGE_DIR"/*|"$PACKAGE_TMP_DIR"/*) rm -rf -- "$target" ;;
		*) fail "拒绝删除非定制目录：$target" ;;
	esac
}

RESET_CUSTOM_PACKAGES() {
	if [ -d "$CUSTOM_PACKAGE_DIR" ]; then
		case "$CUSTOM_PACKAGE_DIR" in
			"$TOPDIR"/package/custom-sources) rm -rf -- "$CUSTOM_PACKAGE_DIR" ;;
			*) fail "定制包目录不在允许位置：$CUSTOM_PACKAGE_DIR" ;;
		esac
	fi
	mkdir -p "$CUSTOM_PACKAGE_DIR" "$PACKAGE_TMP_DIR"
}

UPDATE_PACKAGE() {
	name="$1"
	repository="$2"
	branch="$3"
	subdirectory="${4-}"
	excludes="${5-}"

	validate_name "$name"
	validate_repository "$repository"
	validate_name "$branch"
	validate_subdirectory "$subdirectory"

	clone_dir="$PACKAGE_TMP_DIR/$name"
	destination="$CUSTOM_PACKAGE_DIR/$name"
	safe_remove_tree "$clone_dir"
	safe_remove_tree "$destination"

	printf '同步 %-18s %s@%s\n' "$name" "$repository" "$branch"
	git clone --quiet --depth 1 --single-branch --branch "$branch" \
		"https://github.com/$repository.git" "$clone_dir" || \
		fail "无法克隆 $repository 的 $branch 分支"

	source_dir="$clone_dir"
	if [ -n "$subdirectory" ]; then
		source_dir="$clone_dir/$subdirectory"
		[ -d "$source_dir" ] || fail "$repository 中不存在子目录 $subdirectory"
	fi

	for excluded in $excludes; do
		validate_name "$excluded"
		find "$source_dir" -type d -name "$excluded" -prune -exec rm -rf -- {} \;
	done

	# 不把第三方仓库的 Git 元数据嵌套进当前源码仓库。
	safe_remove_tree "$clone_dir/.git"
	mkdir -p "$destination"
	cp -a "$source_dir/." "$destination/"
	safe_remove_tree "$clone_dir"
}
