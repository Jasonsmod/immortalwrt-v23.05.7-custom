#!/bin/sh

set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TOPDIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
PACKAGE_DIR="$TOPDIR/package/luci-app-openvpn-server-custom"
DEFAULTS="$PACKAGE_DIR/files/etc/uci-defaults/90-openvpn-server-custom"
MANAGER="$PACKAGE_DIR/files/usr/libexec/openvpn-server-manager"
ERRORS=0

fail_check() {
	printf '错误：%s\n' "$1" >&2
	ERRORS=$((ERRORS + 1))
}

require_file() {
	[ -f "$1" ] || fail_check "缺少文件 $1"
}

require_text() {
	grep -Fq "$2" "$1" || fail_check "$1 缺少：$2"
}

for file in \
	"$PACKAGE_DIR/Makefile" \
	"$PACKAGE_DIR/files/etc/config/openvpn_server" \
	"$PACKAGE_DIR/files/lib/upgrade/keep.d/openvpn-server-custom" \
	"$DEFAULTS" \
	"$MANAGER" \
	"$PACKAGE_DIR/files/usr/lib/lua/luci/controller/openvpn_server_custom.lua" \
	"$PACKAGE_DIR/files/usr/lib/lua/luci/model/cbi/openvpn-server-custom/server.lua" \
	"$PACKAGE_DIR/files/usr/lib/lua/luci/model/cbi/openvpn-server-custom/clients.lua"
do
	require_file "$file"
done

if [ "$ERRORS" -ne 0 ]; then
	exit 1
fi

sh -n "$DEFAULTS" || fail_check 'OpenVPN网络初始化脚本语法无效。'
sh -n "$MANAGER" || fail_check 'OpenVPN证书管理脚本语法无效。'

require_text "$DEFAULTS" "set network.vpn0.device='tun0'"
require_text "$DEFAULTS" "set network.wg0.proto='wireguard'"
require_text "$DEFAULTS" "set firewall.vpn.input='ACCEPT'"
require_text "$DEFAULTS" "set firewall.lan_to_vpn.dest='vpn'"
require_text "$DEFAULTS" "set firewall.vpn_to_lan.dest='lan'"
require_text "$DEFAULTS" "set firewall.vpn_to_wan.dest='wan'"
require_text "$MANAGER" "set openvpn.\$OPENVPN_SECTION.tls_version_min='1.2'"
require_text "$MANAGER" 'valid_client_name'
require_text "$PACKAGE_DIR/Makefile" 'chmod 0700 $(1)/usr/libexec/openvpn-server-manager'
require_text "$PACKAGE_DIR/files/lib/upgrade/keep.d/openvpn-server-custom" '/etc/openvpn/server/'

if grep -Rqs --include='*' '0777' "$PACKAGE_DIR"; then
	fail_check 'OpenVPN Server软件包中不允许使用0777权限。'
fi

if grep -Eqs 'wan_to_(lan|vpn)|src=.wan.*dest=.lan' "$DEFAULTS"; then
	fail_check '检测到未授权的WAN到LAN/VPN转发。'
fi

if find "$PACKAGE_DIR" -type f \( -name '*.key' -o -name '*.crt' -o -name '*.p12' \) -print -quit | grep -q .; then
	fail_check '软件包中不允许携带预生成证书或私钥。'
fi

if command -v luac >/dev/null 2>&1; then
	find "$PACKAGE_DIR/files/usr/lib/lua" -type f -name '*.lua' -exec luac -p {} \; || fail_check 'LuCI Lua语法校验失败。'
fi

if [ "$ERRORS" -ne 0 ]; then
	printf '错误：OpenVPN Server安全校验发现 %s 项问题。\n' "$ERRORS" >&2
	exit 1
fi

printf 'OpenVPN Server GUI、证书权限、VPN接口和防火墙方向校验通过。\n'
