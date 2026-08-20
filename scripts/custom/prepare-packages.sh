#!/bin/sh

set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

. "$SCRIPT_DIR/package-manager.sh"
RESET_CUSTOM_PACKAGES
. "$SCRIPT_DIR/package-sources.sh"

printf '第三方源码已同步到 %s\n' "$CUSTOM_PACKAGE_DIR"
