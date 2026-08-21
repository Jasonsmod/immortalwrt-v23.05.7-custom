#!/bin/sh

set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TOPDIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
CONFIG="$TOPDIR/.config"
target="${1-}"
CONFIG_ERRORS=0

[ -f "$CONFIG" ] || {
	printf '错误：缺少 .config。\n' >&2
	exit 1
}

require_symbol() {
	if ! grep -qx "$1=y" "$CONFIG"; then
		printf '错误：配置未启用 %s。\n' "$1" >&2
		CONFIG_ERRORS=$((CONFIG_ERRORS + 1))
	fi
}

reject_symbol() {
	if grep -qx "$1=y" "$CONFIG"; then
		printf '错误：配置不应启用 %s。\n' "$1" >&2
		CONFIG_ERRORS=$((CONFIG_ERRORS + 1))
	fi
}

case "$target" in
	r619ac) require_symbol CONFIG_TARGET_ipq40xx_generic_DEVICE_p2w_r619ac-128m ;;
	x86) require_symbol CONFIG_TARGET_x86_generic_DEVICE_generic ;;
	x86_64) require_symbol CONFIG_TARGET_x86_64_DEVICE_generic ;;
	*) printf '错误：未知目标 %s。\n' "$target" >&2; exit 1 ;;
esac

for symbol in \
	CONFIG_PACKAGE_custom-firmware-defaults \
	CONFIG_PACKAGE_dnsmasq-full \
	CONFIG_PACKAGE_luci-theme-argon \
	CONFIG_PACKAGE_luci-app-passwall \
	CONFIG_PACKAGE_luci-app-openclash \
	CONFIG_PACKAGE_luci-app-mosdns \
	CONFIG_PACKAGE_luci-proto-wireguard \
	CONFIG_PACKAGE_luci-app-openvpn \
	CONFIG_PACKAGE_openvpn-openssl \
	CONFIG_PACKAGE_openvpn-easy-rsa \
	CONFIG_PACKAGE_kmod-tun \
	CONFIG_PACKAGE_luci-app-mwan3 \
	CONFIG_PACKAGE_luci-app-wol \
	CONFIG_PACKAGE_luci-app-vlmcsd \
	CONFIG_PACKAGE_luci-app-ddns \
	CONFIG_PACKAGE_ddns-scripts-aliyun \
	CONFIG_PACKAGE_kmod-tcp-bbr \
	CONFIG_PREINITOPT \
	CONFIG_TARGET_DEFAULT_LAN_IP_FROM_PREINIT
do
	require_symbol "$symbol"
done

for symbol in \
	CONFIG_PACKAGE_dnsmasq \
	CONFIG_PACKAGE_luci-theme-bootstrap \
	CONFIG_PACKAGE_luci-theme-aurora \
	CONFIG_PACKAGE_luci-theme-kucat \
	CONFIG_PACKAGE_luci-theme-noobwrt \
	CONFIG_PACKAGE_luci-theme-shadcn \
	CONFIG_PACKAGE_luci-theme-fluent \
	CONFIG_PACKAGE_luci-app-qbittorrent \
	CONFIG_PACKAGE_luci-app-partexp \
	CONFIG_PACKAGE_luci-app-diskman \
	CONFIG_PACKAGE_luci-app-netspeedtest
do
	reject_symbol "$symbol"
done

if ! grep -qx 'CONFIG_TARGET_PREINIT_IP="192.168.50.1"' "$CONFIG"; then
	printf '错误：默认管理地址不是 192.168.50.1。\n' >&2
	CONFIG_ERRORS=$((CONFIG_ERRORS + 1))
fi

if [ "$CONFIG_ERRORS" -ne 0 ]; then
	printf '错误：%s 配置校验发现 %s 项问题。\n' "$target" "$CONFIG_ERRORS" >&2
	exit 1
fi

printf '%s 配置校验通过。\n' "$target"
