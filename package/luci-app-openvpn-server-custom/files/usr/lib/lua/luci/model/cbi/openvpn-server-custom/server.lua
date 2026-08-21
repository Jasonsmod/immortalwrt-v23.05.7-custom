local fs = require "nixio.fs"
local sys = require "luci.sys"

local manager = "/usr/libexec/openvpn-server-manager"
local pki_ready = fs.access("/etc/easy-rsa/pki/ca.crt") and
	fs.access("/etc/easy-rsa/pki/issued/server.crt") and
	fs.access("/etc/easy-rsa/pki/private/server.key")
local running = sys.call("pgrep -f 'openvpn.*custom_server' >/dev/null 2>&1") == 0

m = Map("openvpn_server", "OpenVPN 服务器",
	"独立管理 OpenVPN 服务器、证书和客户端配置。服务器只有在 PKI 初始化完成后才会启动。")
m.description = string.format("当前状态：%s；证书状态：%s。",
	running and "运行中" or "未运行",
	pki_ready and "已初始化" or "未初始化")

s = m:section(NamedSection, "main", "settings", "服务器设置")
s.addremove = false

 enabled = s:option(Flag, "enabled", "启用服务器")
 enabled.rmempty = false

proto = s:option(ListValue, "proto", "传输协议")
proto:value("udp", "UDP")
proto:value("tcp-server", "TCP")
proto.default = "udp"
proto.rmempty = false

port = s:option(Value, "port", "监听端口")
port.datatype = "port"
port.default = "1194"
port.rmempty = false

remote = s:option(Value, "remote_host", "公网地址或 DDNS")
remote.description = "生成客户端 .ovpn 时写入的服务器地址。"
remote.rmempty = true

vpn_network = s:option(Value, "vpn_network", "VPN 网络地址")
vpn_network.datatype = "ip4addr"
vpn_network.default = "10.8.0.0"
vpn_network.rmempty = false

vpn_netmask = s:option(Value, "vpn_netmask", "VPN 子网掩码")
vpn_netmask.datatype = "ip4addr"
vpn_netmask.default = "255.255.255.0"
vpn_netmask.rmempty = false

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

init_pki = s:option(Button, "_init_pki", "初始化 CA 和服务器证书")
init_pki.inputstyle = "apply"
init_pki.description = "只允许初始化一次，不会覆盖已经存在的 CA 或私钥。"
function init_pki.write()
	m.message = sys.exec(manager .. " init-pki 2>&1")
end

function m.on_after_commit()
	m.message = sys.exec(manager .. " apply 2>&1")
end

return m
