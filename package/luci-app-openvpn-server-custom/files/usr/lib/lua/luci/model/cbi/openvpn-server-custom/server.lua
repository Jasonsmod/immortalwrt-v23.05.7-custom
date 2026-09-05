local fs = require "nixio.fs"
local sys = require "luci.sys"
local jsonc = require "luci.jsonc"
local http = require "luci.http"
local uci = require "luci.model.uci".cursor()

local manager = "/usr/libexec/openvpn-server-manager"
local pki_ready = fs.access("/etc/easy-rsa/pki/ca.crt") and
    fs.access("/etc/easy-rsa/pki/issued/server.crt") and
    fs.access("/etc/easy-rsa/pki/private/server.key")
local running = sys.call("pgrep -f 'openvpn.*custom_server' >/dev/null 2>&1") == 0
local configured_cipher = uci:get("openvpn_server", "main", "data_cipher")
local cpuinfo = string.lower(fs.readfile("/proc/cpuinfo") or "")
local cpu_supports_aes = cpuinfo:match("%f[%a]aes%f[%A]") ~= nil
local recommended_cipher = cpu_supports_aes and "AES-128-GCM" or "CHACHA20-POLY1305"
local selected_cipher = configured_cipher or recommended_cipher
local available_ciphers = [[CHACHA20-POLY1305
AES-128-GCM
AES-256-GCM
AES-128-CBC
AES-192-CBC
AES-256-CBC
AES-128-CFB
AES-192-CFB
AES-256-CFB
AES-128-OFB
AES-192-OFB
AES-256-OFB]]
local public_interfaces = { "lan", "vpn0", "wan", "wan6", "wg0" }
local network_interfaces = {}
local network_dump = sys.exec("ubus call network.interface dump 2>/dev/null") or ""
local network_ok, network_status = pcall(jsonc.parse, network_dump)
if network_ok and type(network_status) == "table" and type(network_status.interface) == "table" then
    for _, network_interface in ipairs(network_status.interface) do
        if network_interface.interface then
            network_interfaces[network_interface.interface] = network_interface
        end
    end
end

local function interface_address(interface)
    local field = interface == "wan6" and "ipv6-address" or "ipv4-address"
    local network_interface = network_interfaces[interface]
    local addresses = network_interface and network_interface[field]
    local address = type(addresses) == "table" and addresses[1]
    return type(address) == "table" and address.address or ""
end

local function load_client_users()
    local users = {}
    local client_output = sys.exec(manager .. " list-clients 2>/dev/null") or ""
    for line in client_output:gmatch("[^\r\n]+") do
        local name, enabled = line:match("^([A-Za-z0-9_-]+)|([01])$")
        if name then
            users[#users + 1] = {
                name = name,
                enabled = enabled == "1"
            }
        end
    end
    return users
end

local function final_command_result(output)
    local result = ""
    for line in (output or ""):gmatch("[^\r\n]+") do
        line = line:gsub("^%s+", ""):gsub("%s+$", "")
        if #line > 0 then
            result = line
        end
    end
    return result
end

local client_users = pki_ready and load_client_users() or {}
m = Map("openvpn_server", "OpenVPN 服务器",
	"独立管理 OpenVPN 服务器和证书。服务器只有在 PKI 初始化完成后才会启动。")
m.description = string.format("当前状态：%s；证书状态：%s。",
	running and "运行中" or "未运行",
	pki_ready and "已初始化" or "未初始化")

s = m:section(NamedSection, "main", "settings", "服务器设置")
s.addremove = false

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

accounts = s:option(DummyValue, "_accounts", "账号认证账号")
accounts.template = "openvpn-server-custom/account-list"
accounts:depends("auth_mode", "account")
accounts:depends("auth_mode", "both")

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

client_isolation = s:option(Flag, "client_isolation", "客户端通信隔离")
client_isolation.default = "0"
client_isolation.rmempty = false
redirect_gateway = s:option(Flag, "redirect_gateway", "客户端所有流量走远程网关")
redirect_gateway.default = "0"
redirect_gateway.rmempty = false
lzo = s:option(Flag, "lzo", "LZO压缩")
lzo.default = "1"
lzo.rmempty = false

data_cipher = s:option(ListValue, "data_cipher", "加密算法")
for cipher_name in available_ciphers:gmatch("[^\r\n]+") do
	local label
	if cipher_name == recommended_cipher then
		label = cipher_name .. "（推荐，已按 CPU 自动选择）"
	else
		label = cipher_name
	end
	data_cipher:value(cipher_name, label)
end
data_cipher.default = selected_cipher
data_cipher.rmempty = false

bind_interface = s:option(ListValue, "bind_interface", "线路")
for _, interface in ipairs(public_interfaces) do
    local address = interface_address(interface)
    local label = interface
    if address ~= "" then
        label = label .. "（" .. address .. "）"
    end
    bind_interface:value(interface, label)
end
bind_interface.default = "wan"
bind_interface.rmempty = false

remote = s:option(Value, "remote_host", "自定义 DDNS 地址")
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

client_add = s:option(DummyValue, "_client_add", "用户名")
client_add.template = "openvpn-server-custom/server-client-add"
client_add.pki_ready = pki_ready

actions = s:option(Button, "_init_pki", "")
actions.template = "openvpn-server-custom/server-actions"
actions.pki_ready = pki_ready
actions.inputtitle = "初始化 CA 和服务器证书"
actions.client_users = client_users
actions.remote_host_error = http.formvalue("remote_host_error") == "1"
function actions.write()
	if not pki_ready then
		m.message = final_command_result(sys.exec(manager .. " init-pki 2>&1"))
		pki_ready = fs.access("/etc/easy-rsa/pki/ca.crt") and
			fs.access("/etc/easy-rsa/pki/issued/server.crt") and
			fs.access("/etc/easy-rsa/pki/private/server.key")
		client_add.pki_ready = pki_ready
		actions.pki_ready = pki_ready
		actions.client_users = actions.pki_ready and load_client_users() or {}
		m.description = string.format("当前状态：%s；证书状态：%s。",
			running and "运行中" or "未运行",
			pki_ready and "已初始化" or "未初始化")
	end
end

function m.on_after_commit()
    m.message = final_command_result(sys.exec(manager .. " apply 2>&1"))
end

if http.formvalue("message") then
    m.message = http.formvalue("message")
end

return m
