local fs = require "nixio.fs"
local sys = require "luci.sys"
local http = require "luci.http"
local uci = require "luci.model.uci".cursor()

local manager = "/usr/libexec/openvpn-server-manager"
local pki_ready = fs.access("/etc/easy-rsa/pki/ca.crt") and
    fs.access("/etc/easy-rsa/pki/issued/server.crt") and
    fs.access("/etc/easy-rsa/pki/private/server.key")
local running = sys.call("pgrep -f 'openvpn.*custom_server' >/dev/null 2>&1") == 0
local configured_cipher = uci:get("openvpn_server", "main", "data_cipher")
local recommended_cipher = configured_cipher or "AES-128-GCM"
local available_ciphers = [[CHACHA20-POLY1305
AES-128-GCM
AES-256-GCM
AES-128-CBC
AES-192-CBC
AES-256-CBC
AES-128-OFB
AES-192-OFB
AES-256-OFB
AES-128-CFB
AES-192-CFB
AES-256-CFB
AES-128-CFB1
AES-192-CFB1
AES-256-CFB1
AES-128-CFB8
AES-192-CFB8
AES-256-CFB8
DES-CFB
DES-CBC
RC2-CBC
RC2-CFB
RC2-OFB
DES-EDE-CBC
DES-EDE3-CBC
DES-OFB
DES-EDE-CFB
DES-EDE3-CFB
DES-EDE-OFB
DES-EDE3-OFB
DESX-CBC
RC2-40-CBC
CAST5-CBC
CAST5-CFB
CAST5-OFB
RC2-64-CBC
DES-CFB1
DES-CFB8
DES-EDE3-CFB1
DES-EDE3-CFB8
SEED-CBC
SEED-OFB
SEED-CFB]]
m = Map("openvpn_server", "OpenVPN 服务器",
	"独立管理 OpenVPN 服务器和证书。服务器只有在 PKI 初始化完成后才会启动。")
m.description = string.format("当前状态：%s；证书状态：%s。",
	running and "运行中" or "未运行",
	pki_ready and "已初始化" or "未初始化")

s = m:section(NamedSection, "main", "settings", "服务器设置")
s.addremove = false

actions = s:option(Button, "_init_pki", "")
actions.template = "openvpn-server-custom/server-actions"
actions.pki_ready = pki_ready
actions.inputtitle = "初始化 CA 和服务器证书"
function actions.write()
	if not pki_ready then
		m.message = sys.exec(manager .. " init-pki 2>&1")
	end
end

enabled = s:option(Flag, "enabled", "启用 OpenVPN 服务")
enabled.rmempty = false

port = s:option(Value, "port", "服务端口")
port.datatype = "port"
port.default = "1194"
port.rmempty = false

vpn_network = s:option(Value, "vpn_network", "VPN 网络")
vpn_network.datatype = "ip4addr"
vpn_network.default = "10.8.0.0"
vpn_network.rmempty = false

vpn_netmask = s:option(Value, "vpn_netmask", "网络掩码")
vpn_netmask.datatype = "ip4addr"
vpn_netmask.default = "255.255.255.0"
vpn_netmask.rmempty = false

auth_mode = s:option(ListValue, "auth_mode", "认证方式")
auth_mode:value("account", "账号认证")
auth_mode:value("cert", "密钥认证")
auth_mode:value("both", "账号+密钥")
auth_mode.default = "cert"
auth_mode.rmempty = false
auth_mode.description = "密钥认证为默认方式；账号认证需要先配置账号。"

proto = s:option(ListValue, "proto", "传输协议")
proto:value("udp", "UDP")
proto:value("tcp-server", "TCP")
proto.default = "udp"
proto.rmempty = false

tunnel_type = s:option(ListValue, "tunnel_type", "隧道类型")
tunnel_type:value("tun", "TUN")
tunnel_type:value("tap", "TAP")
tunnel_type.default = "tun"
tunnel_type.rmempty = false

topology = s:option(DummyValue, "_topology", "拓扑类型")
topology.default = "SUBNET"

lzo = s:option(Flag, "lzo", "LZO压缩")
lzo.default = "0"
lzo.rmempty = false
lzo.description = "开启后使用 comp-lzo yes；客户端必须使用相同设置。"

data_cipher = s:option(ListValue, "data_cipher", "加密算法")
for cipher_name in available_ciphers:gmatch("[^\r\n]+") do
	local label
	if cipher_name == recommended_cipher then
		label = cipher_name .. "（推荐，已按 CPU 自动选择）"
	elseif cipher_name == "CHACHA20-POLY1305" or cipher_name:match("%-GCM$") then
		label = cipher_name .. "（现代 AEAD）"
	elseif cipher_name:match("^AES%-") then
		label = cipher_name .. "（旧客户端兼容）"
	else
		label = cipher_name .. "（旧版兼容，不推荐）"
	end
	data_cipher:value(cipher_name, label)
end
data_cipher.default = recommended_cipher
data_cipher.rmempty = false
data_cipher.description = "页面不再执行外部算法探测；保存时由服务端校验当前 OpenVPN 是否支持。"

remote = s:option(Value, "remote_host", "公网地址或 DDNS")
remote.description = "生成客户端配置时写入的服务器地址。"
remote.rmempty = true

lan_network = s:option(Value, "lan_network", "LAN 网络地址")
lan_network.datatype = "ip4addr"
lan_network.default = "192.168.50.0"
lan_network.rmempty = false

lan_netmask = s:option(Value, "lan_netmask", "LAN 子网掩码")
lan_netmask.datatype = "ip4addr"
lan_netmask.default = "255.255.255.0"
lan_netmask.rmempty = false

client_dns = s:option(Value, "client_dns", "客户端 DNS")
client_dns.datatype = "ip4addr"
client_dns.default = "192.168.50.1"
client_dns.rmempty = false

push_route = s:option(DynamicList, "push_route", "推送路由")
push_route.placeholder = "10.8.0.0/16"
push_route.rmempty = true
push_route.description = "使用 IP/前缀格式，一行一条；例如 10.8.0.0/16。LAN 路由仍会自动推送。"
function push_route.validate(self, value)
    local ip, prefix = value:match("^([0-9]+%.[0-9]+%.[0-9]+%.[0-9]+)/([0-9]+)$")
    if not ip or not prefix or tonumber(prefix) > 32 then
        return nil, "推送路由必须使用 IPv4/前缀格式，例如 10.8.0.0/16。"
    end
    for part in ip:gmatch("[0-9]+") do
        if tonumber(part) > 255 then
            return nil, "推送路由 IPv4 地址无效。"
        end
    end
    return value
end

max_clients = s:option(Value, "max_clients", "最大客户端数量")
max_clients.datatype = "range(1,1024)"
max_clients.default = "10"
max_clients.rmempty = false

extra_config = s:option(TextValue, "extra_config", "附加配置")
extra_config.rows = 8
extra_config.rmempty = true
extra_config.description = "示例：tcp-queue-limit 32；mtu-disc no。脚本、插件、管理接口和核心身份参数会被拒绝。"

accounts = s:option(DummyValue, "_accounts", "账号认证账号")
accounts.template = "openvpn-server-custom/account-list"

certificate_status = s:option(DummyValue, "_certificate_status", "证书状态")
certificate_status.default = pki_ready and "已初始化" or "未初始化"

function m.on_after_commit()
    m.message = sys.exec(manager .. " apply 2>&1")
end

if http.formvalue("message") then
    m.message = http.formvalue("message")
end

return m
