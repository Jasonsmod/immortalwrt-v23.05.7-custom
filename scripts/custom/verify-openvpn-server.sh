#!/bin/sh

set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TOPDIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
PACKAGE_DIR="$TOPDIR/package/luci-app-openvpn-server-custom"
DEFAULTS="$PACKAGE_DIR/files/etc/uci-defaults/90-openvpn-server-custom"
FIRMWARE_DEFAULTS="$TOPDIR/package/custom-firmware-defaults/files/etc/uci-defaults/99-custom-firmware"
MANAGER="$PACKAGE_DIR/files/usr/libexec/openvpn-server-manager"
AUTH_SCRIPT="$PACKAGE_DIR/files/usr/libexec/openvpn-server-auth"
CLIENT_CHECK="$PACKAGE_DIR/files/usr/libexec/openvpn-server-client-check"
CLIENT_MANAGER="$PACKAGE_DIR/files/usr/libexec/openvpn-client-manager"
CONTROLLER="$PACKAGE_DIR/files/usr/lib/lua/luci/controller/openvpn_server_custom.lua"
SERVER_MODEL="$PACKAGE_DIR/files/usr/lib/lua/luci/model/cbi/openvpn-server-custom/server.lua"
ACTIONS_TEMPLATE="$PACKAGE_DIR/files/usr/lib/lua/luci/view/openvpn-server-custom/server-actions.htm"
CLIENT_EXTRA_TEMPLATE="$PACKAGE_DIR/files/usr/lib/lua/luci/view/openvpn-server-custom/server-client-extra.htm"
CLIENT_LIST_TEMPLATE="$PACKAGE_DIR/files/usr/lib/lua/luci/view/openvpn-server-custom/client-list.htm"
CLIENT_EDIT_TEMPLATE="$PACKAGE_DIR/files/usr/lib/lua/luci/view/openvpn-server-custom/client-edit.htm"
ACCOUNT_TEMPLATE="$PACKAGE_DIR/files/usr/lib/lua/luci/view/openvpn-server-custom/account-list.htm"
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
	"$PACKAGE_DIR/files/etc/config/openvpn_client_custom" \
	"$PACKAGE_DIR/files/lib/upgrade/keep.d/openvpn-server-custom" \
	"$DEFAULTS" \
	"$FIRMWARE_DEFAULTS" \
	"$MANAGER" \
	"$AUTH_SCRIPT" \
	"$CLIENT_CHECK" \
	"$CLIENT_MANAGER" \
	"$CONTROLLER" \
	"$SERVER_MODEL" \
	"$ACTIONS_TEMPLATE" \
	"$CLIENT_EXTRA_TEMPLATE" \
	"$CLIENT_LIST_TEMPLATE" \
	"$CLIENT_EDIT_TEMPLATE" \
	"$ACCOUNT_TEMPLATE"
do
	require_file "$file"
done

if [ "$ERRORS" -ne 0 ]; then
	exit 1
fi

sh -n "$DEFAULTS" || fail_check 'OpenVPN网络初始化脚本语法无效。'
sh -n "$FIRMWARE_DEFAULTS" || fail_check '自定义固件初始化脚本语法无效。'
sh -n "$MANAGER" || fail_check 'OpenVPN证书管理脚本语法无效。'
sh -n "$AUTH_SCRIPT" || fail_check 'OpenVPN账号认证脚本语法无效。'
sh -n "$CLIENT_CHECK" || fail_check 'OpenVPN证书用户校验脚本语法无效。'
sh -n "$CLIENT_MANAGER" || fail_check 'OpenVPN客户端管理脚本语法无效。'

require_text "$DEFAULTS" "set network.vpn0.device='tun0'"
require_text "$DEFAULTS" "set network.wg0.proto='wireguard'"
require_text "$DEFAULTS" "set firewall.vpn.input='ACCEPT'"
require_text "$DEFAULTS" "set firewall.lan_to_vpn.dest='vpn'"
require_text "$DEFAULTS" "set firewall.vpn_to_lan.dest='lan'"
require_text "$DEFAULTS" "set firewall.vpn_to_wan.dest='wan'"
require_text "$MANAGER" "set_openvpn_default tls_version_min '1.2'"
require_text "$MANAGER" 'valid_client_name'
require_text "$MANAGER" 'recommended_data_cipher'
require_text "$MANAGER" 'CHACHA20-POLY1305'
require_text "$MANAGER" 'AES-128-GCM'
require_text "$MANAGER" 'set_openvpn_default'
require_text "$MANAGER" 'replace_managed_push'
require_text "$MANAGER" 'render_server_config'
require_text "$MANAGER" 'CCD_DIR='
require_text "$MANAGER" 'client-config-dir %s'
require_text "$MANAGER" 'save_client_extra'
require_text "$MANAGER" 'read_client_extra'
require_text "$MANAGER" 'client_config_dir=$CCD_DIR'
require_text "$MANAGER" 'client_to_client=1'
require_text "$MANAGER" "printf 'client-to-client\\n'"
require_text "$MANAGER" "printf 'push \"redirect-gateway def1 bypass-dhcp\"\\n'"
require_text "$MANAGER" 'client_isolation'
require_text "$MANAGER" 'redirect_gateway'
require_text "$MANAGER" 'auth-user-pass-verify'
require_text "$MANAGER" 'save_account'
require_text "$AUTH_SCRIPT" 'server-accounts'
require_text "$MANAGER" 'data_ciphers_fallback'
require_text "$MANAGER" 'delete "openvpn.$OPENVPN_SECTION.tls_crypt"'
require_text "$MANAGER" 'delete "openvpn.$OPENVPN_SECTION.tls_auth"'
require_text "$DEFAULTS" 'grep -Eiq'
require_text "$FIRMWARE_DEFAULTS" 'mkdir -p /etc/openvpn/ccd'
require_text "$FIRMWARE_DEFAULTS" 'chmod 0755 /etc/openvpn/ccd'
require_text "$DEFAULTS" "data_cipher='AES-128-GCM'"
require_text "$DEFAULTS" "data_cipher='CHACHA20-POLY1305'"
require_text "$SERVER_MODEL" 'if not pki_ready then'
require_text "$SERVER_MODEL" 'available_ciphers'
require_text "$SERVER_MODEL" 'DynamicList'
require_text "$SERVER_MODEL" 'auth_mode'
require_text "$SERVER_MODEL" 'tunnel_type'
require_text "$SERVER_MODEL" 'extra_config'
require_text "$SERVER_MODEL" 'actions.remote_host_error'
require_text "$SERVER_MODEL" 'accounts:depends("auth_mode", "account")'
require_text "$SERVER_MODEL" 'accounts:depends("auth_mode", "both")'
require_text "$SERVER_MODEL" 'client_isolation.default = "0"'
require_text "$SERVER_MODEL" 'redirect_gateway.default = "0"'
require_text "$SERVER_MODEL" 'lzo.default = "1"'
require_text "$SERVER_MODEL" 'cpu_supports_aes'
require_text "$SERVER_MODEL" 'data_cipher.default = selected_cipher'
require_text "$SERVER_MODEL" 'local jsonc = require "luci.jsonc"'
require_text "$SERVER_MODEL" 'bind_interface = s:option(ListValue, "bind_interface", "线路")'
require_text "$SERVER_MODEL" 'remote = s:option(Value, "remote_host", "自定义 DDNS 地址")'
require_text "$MANAGER" 'valid_remote_interface'
require_text "$MANAGER" 'interface_address'
require_text "$MANAGER" 'ensure_client_record'
require_text "$MANAGER" 'enable-client) set_client_state 1 ;;'
require_text "$MANAGER" 'delete-client) delete_client ;;'
require_text "$MANAGER" '不能删除服务器证书'
require_text "$MANAGER" 'client-connect %s'
require_text "$CLIENT_CHECK" 'common_name'
require_text "$CLIENT_CHECK" 'auth_mode="$(uci -q get openvpn_server.main.auth_mode'
require_text "$CLIENT_CHECK" 'auth_mode='
require_text "$CLIENT_CHECK" 'openvpn_server.$section.enabled'
require_text "$CONTROLLER" 'post("server_client_add")'
require_text "$CONTROLLER" 'post("server_client_download")'
require_text "$CONTROLLER" 'post("server_client_action")'
require_text "$CONTROLLER" 'server_interface_has_address'
require_text "$CONTROLLER" 'remote_host_error=1'
require_text "$CONTROLLER" '请选择有效的线路或输入自定义 DDNS 地址。'
require_text "$CONTROLLER" 'call("server_client_extra")'
require_text "$CONTROLLER" 'post("server_client_extra_save")'
require_text "$CONTROLLER" 'save-client-extra'
require_text "$CONTROLLER" 'name ~= "server"'
require_text "$ACTIONS_TEMPLATE" '新增用户'
require_text "$ACTIONS_TEMPLATE" '下载 OVPN'
require_text "$ACTIONS_TEMPLATE" '删除'
require_text "$ACTIONS_TEMPLATE" '附加配置'
require_text "$ACTIONS_TEMPLATE" '独立附加配置'
require_text "$ACTIONS_TEMPLATE" 'openvpn-server-client-table'
require_text "$ACTIONS_TEMPLATE" '独立附加配置'
require_text "$ACTIONS_TEMPLATE" 'validateServerClientAdd'
require_text "$ACTIONS_TEMPLATE" 'data-generating'
require_text "$ACTIONS_TEMPLATE" '生成中...'
require_text "$ACTIONS_TEMPLATE" 'openvpn-server-init-action'
require_text "$ACTIONS_TEMPLATE" 'openvpn-remote-host-error'
require_text "$CLIENT_EXTRA_TEMPLATE" 'name="client_extra"'
require_text "$CLIENT_EXTRA_TEMPLATE" 'value="保存"'
require_text "$MANAGER" "create_client 'default'"
require_text "$PACKAGE_DIR/Makefile" 'openvpn-server-client-check'
require_text "$CONTROLLER" 'if profile:match("^错误：") then'
require_text "$MANAGER" 'remote $remote_host $port'
require_text "$PACKAGE_DIR/files/etc/config/openvpn_server" "option bind_interface 'wan'"
require_text "$DEFAULTS" "main.bind_interface=wan"
require_text "$ACTIONS_TEMPLATE" 'if not self.pki_ready then'
require_text "$PACKAGE_DIR/Makefile" 'chmod 0700 $(1)/usr/libexec/openvpn-server-manager'
require_text "$PACKAGE_DIR/Makefile" 'chmod 0700 $(1)/usr/libexec/openvpn-client-manager'
require_text "$PACKAGE_DIR/Makefile" 'openvpn_client_custom'
require_text "$PACKAGE_DIR/Makefile" 'client-list.htm'
require_text "$PACKAGE_DIR/Makefile" 'client-edit.htm'
require_text "$PACKAGE_DIR/Makefile" 'server-actions.htm'
require_text "$PACKAGE_DIR/Makefile" 'server-client-extra.htm'
require_text "$PACKAGE_DIR/Makefile" 'openvpn-server-auth'
require_text "$PACKAGE_DIR/Makefile" 'account-list.htm'
require_text "$PACKAGE_DIR/files/lib/upgrade/keep.d/openvpn-server-custom" '/etc/openvpn/server/'
require_text "$PACKAGE_DIR/files/lib/upgrade/keep.d/openvpn-server-custom" '/etc/openvpn/client-custom/'
require_text "$PACKAGE_DIR/files/lib/upgrade/keep.d/openvpn-server-custom" '/etc/openvpn/ccd/'
require_text "$CONTROLLER" 'post("client_save")'
require_text "$CONTROLLER" 'post("client_action")'
require_text "$CONTROLLER" 'CLIENT_CIPHERS'
require_text "$CONTROLLER" 'dispatcher.test_post_security()'
require_text "$CONTROLLER" 'http.setfilehandler'

require_text "$CLIENT_LIST_TEMPLATE" '添加'
require_text "$CLIENT_LIST_TEMPLATE" 'value="导入ovpn文件"'
require_text "$CLIENT_LIST_TEMPLATE" "submitClientAction('enable')"
require_text "$CLIENT_LIST_TEMPLATE" "submitClientAction('disable')"
require_text "$CLIENT_LIST_TEMPLATE" "submitClientAction('delete')"
require_text "$CLIENT_EDIT_TEMPLATE" '附加配置'
require_text "$CLIENT_EDIT_TEMPLATE" '服务器路由推送'
require_text "$CLIENT_EDIT_TEMPLATE" 'name="tunnel_type"'
require_text "$CLIENT_EDIT_TEMPLATE" 'value="tap"'
require_text "$CONTROLLER" 'tunnel_type = http.formvalue("tunnel_type")'
require_text "$CLIENT_MANAGER" 'valid_tunnel_type'
require_text "$CLIENT_MANAGER" 'dev-type %s'
require_text "$CLIENT_MANAGER" 'tunnel_type=$tunnel_type'
require_text "$CLIENT_MANAGER" 'dangerous_config'
require_text "$CLIENT_MANAGER" 'MAX_IMPORT_SIZE=1048576'
require_text "$CLIENT_MANAGER" 'chmod 0600'
require_text "$CLIENT_MANAGER" 'enable|disable|delete'
require_text "$CLIENT_MANAGER" 'openvpn.client_$id.config'
require_text "$CLIENT_MANAGER" 'bind-dev'
require_text "$CLIENT_MANAGER" 'BF-*'
require_text "$CLIENT_MANAGER" "printf '%s\n' '0' > \"\$staging/lzo\""
require_text "$CLIENT_MANAGER" "openvpn --version 2>/dev/null | grep -Fq '[LZO]'"
require_text "$CLIENT_EDIT_TEMPLATE" '配置名称'
require_text "$CLIENT_MANAGER" 'if [ -n "$mtu" ]; then'
require_text "$CLIENT_MANAGER" 'mtu="$(uci -q get "$CONFIG.$id.tun_mtu" || true)"'
require_text "$CLIENT_MANAGER" '[ -z "$mtu" ]'
require_text "$CLIENT_MANAGER" ': > "$staging/tun_mtu"'
require_text "$CONTROLLER" 'tun_mtu = ""'

if grep -Eq 'sys\.exec\(manager.*(list-ciphers|recommended-cipher)' "$SERVER_MODEL"; then
	fail_check '服务端页面不应在加载时执行算法探测。'
fi

if grep -Fq 'manager_command("list-ciphers")' "$CONTROLLER"; then
	fail_check '客户端编辑页面不应在加载时执行算法探测。'
fi

if sed -n '/^supported_lzo()/,/^}/p' "$CLIENT_MANAGER" | grep -Fq 'openvpn --help'; then
	fail_check 'LZO编译能力不应通过OpenVPN精简帮助信息判断。'
fi

if grep -Fq 'jsonfilter -e "@.$field[0].address"' "$MANAGER"; then
	fail_check '服务器线路 IP 解析仍使用未转义的连字符字段路径。'
fi
render_block="$(sed -n '/^render_server_config()/,/^}/p' "$MANAGER")"
if ! printf '%s\n' "$render_block" | grep -Fq 'client_isolation'; then
	fail_check '服务端配置生成应根据客户端通信隔离选项处理 client-to-client。'
fi
if printf '%s' "$render_block" | grep -Eq '^ {8}printf .*redirect-gateway'; then
	fail_check 'redirect-gateway 不应在服务端配置生成中无条件保留。'
fi
export_block="$(sed -n '/^export_client()/,/^}/p' "$MANAGER")"
if printf '%s\n' "$export_block" | grep -Fq 'client-to-client'; then
	fail_check '下载 OVPN 不应包含 client-to-client。'
fi
if grep -Fq 'mkdir -p "$CCD_DIR"' "$MANAGER" || grep -Fq 'chmod 0755 "$CCD_DIR"' "$MANAGER"; then
	fail_check 'CCD目录只能由99-custom-firmware创建。'
fi
if grep -Eq 'server-export|server_export|导出 Windows 客户端配置' "$CONTROLLER" "$ACTIONS_TEMPLATE"; then
	fail_check '旧的 Windows 客户端配置导出入口仍存在。'
fi
if grep -Fq '请先在服务器设置中填写公网地址或DDNS。' "$CONTROLLER"; then
	fail_check '客户端导出不应强制要求填写自定义 DDNS。'
fi

if grep -Fq '拨号名称' "$CLIENT_EDIT_TEMPLATE" || grep -Fq '拨号名称' "$CLIENT_LIST_TEMPLATE" || grep -Fq '拨号名称' "$CLIENT_MANAGER"; then
	fail_check '客户端页面仍使用旧的“拨号名称”文案。'
fi
if grep -Eq 'BF 系列算法不允许使用|压缩可能带来安全风险|>TUN</div>' "$CLIENT_EDIT_TEMPLATE"; then
	fail_check '客户端添加页仍包含已移除的提示或固定 TUN 控件。'
fi

if grep -Eq 'DES-|RC2-|SEED-|CAST5-|CFB1|CFB8|certificate_status|auth_mode\.description|lzo\.description|extra_config\.description|生成客户端配置时写入的服务器地址' "$SERVER_MODEL"; then
	fail_check '服务端设置页仍包含已移除的算法或冗余提示。'
fi
require_text "$PACKAGE_DIR/files/etc/config/openvpn_server" "option lzo '1'"
require_text "$PACKAGE_DIR/files/etc/config/openvpn_server" "option client_isolation '0'"
require_text "$PACKAGE_DIR/files/etc/config/openvpn_server" "option redirect_gateway '0'"
require_text "$DEFAULTS" "main.lzo=1"
require_text "$DEFAULTS" "main.client_isolation=0"
require_text "$DEFAULTS" "main.redirect_gateway=0"

if ! awk '
/^extra_config = s:option/ { extra = NR }
/^actions = s:option/ && extra > 0 && NR > extra { found = 1 }
END { exit found ? 0 : 1 }
' "$SERVER_MODEL"; then
	fail_check '用户管理区必须位于服务端附加配置之后。'
fi
if grep -Fq 'clients.lua' "$PACKAGE_DIR/Makefile"; then
	fail_check '旧客户端证书页面不应继续安装。'
fi

if grep -Fq 'delete "openvpn.$OPENVPN_SECTION"' "$MANAGER"; then
	fail_check '保存服务端配置时不允许删除整个OpenVPN配置段。'
fi

if grep -ERqs 'BF-(CBC|CFB|OFB)' "$PACKAGE_DIR"; then
	fail_check 'OpenVPN Server软件包中不允许提供BF加密算法。'
fi

if grep -Eqs 'TLS_CRYPT_KEY|--genkey|<tls-crypt>|<tls-auth>' "$MANAGER"; then
	fail_check 'OpenVPN Server不应生成或下发tls-auth/tls-crypt静态密钥。'
fi

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

printf 'OpenVPN服务端、多客户端GUI、OVPN导入、令牌和权限校验通过。\n'
