local fs = require "nixio.fs"
local sys = require "luci.sys"

local manager = "/usr/libexec/openvpn-server-manager"
local pki_ready = fs.access("/etc/easy-rsa/pki/ca.crt") and
	fs.access("/etc/easy-rsa/pki/issued/server.crt") and
	fs.access("/etc/easy-rsa/pki/private/server.key")
local running = sys.call("pgrep -f 'openvpn.*custom_server' >/dev/null 2>&1") == 0
local recommended_cipher = sys.exec(manager .. " recommended-cipher 2>/dev/null"):match("([A-Z0-9-]+)") or "AES-128-GCM"
local available_ciphers = sys.exec(manager .. " list-ciphers 2>/dev/null")

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

auth_mode = s:option(DummyValue, "_auth_mode", "认证方式")
auth_mode.default = "证书认证"

proto = s:option(ListValue, "proto", "传输协议")
proto:value("udp", "UDP")
proto:value("tcp-server", "TCP")
proto.default = "udp"
proto.rmempty = false

tunnel_type = s:option(DummyValue, "_tunnel_type", "隧道类型")
tunnel_type.default = "TUN"

topology = s:option(DummyValue, "_topology", "拓扑类型")
topology.default = "SUBNET"

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
data_cipher.description = "仅显示当前 OpenVPN/OpenSSL 实际支持的算法；不安全的旧算法已移除。"

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

max_clients = s:option(Value, "max_clients", "最大客户端数量")
max_clients.datatype = "range(1,1024)"
max_clients.default = "10"
max_clients.rmempty = false

certificate_status = s:option(DummyValue, "_certificate_status", "证书状态")
certificate_status.default = pki_ready and "已初始化" or "未初始化"

function m.on_after_commit()
	m.message = sys.exec(manager .. " apply 2>&1")
end

return m
