local dispatcher = require "luci.dispatcher"
local http = require "luci.http"
local sys = require "luci.sys"
local util = require "luci.util"

local manager = "/usr/libexec/openvpn-server-manager"
local clients = sys.exec(manager .. " list-clients 2>/dev/null"):gsub("%s+$", ""):gsub("\n", "、")

f = SimpleForm("openvpn_clients", "OpenVPN 客户端证书",
	"创建、吊销和下载客户端证书。客户端私钥以 0600 权限保存，下载页面禁止缓存。")
f.reset = false
f.submit = false
f.description = "当前有效客户端：" .. (#clients > 0 and clients or "暂无")

s = f:section(SimpleSection)

name = s:option(Value, "client_name", "客户端名称")
name.description = "仅允许字母、数字、下划线和连字符，最长 32 个字符。"
name.rmempty = false

local function get_client_name(section)
	local value = name:formvalue(section) or ""
	if #value == 0 or #value > 32 or not value:match("^[A-Za-z0-9_-]+$") then
		return nil
	end
	return value
end

create = s:option(Button, "_create", "生成客户端证书")
create.inputstyle = "apply"
function create.write(self, section)
	local client = get_client_name(section)
	if not client then
		f.message = "客户端名称无效。"
		return
	end
	f.message = sys.exec(manager .. " create-client " .. util.shellquote(client) .. " 2>&1")
end

revoke = s:option(Button, "_revoke", "吊销客户端证书")
revoke.inputstyle = "remove"
function revoke.write(self, section)
	local client = get_client_name(section)
	if not client then
		f.message = "客户端名称无效。"
		return
	end
	f.message = sys.exec(manager .. " revoke-client " .. util.shellquote(client) .. " 2>&1")
end

download = s:option(Button, "_download", "下载客户端 .ovpn")
download.inputstyle = "save"
function download.write(self, section)
	local client = get_client_name(section)
	if not client then
		f.message = "客户端名称无效。"
		return
	end
	http.redirect(dispatcher.build_url("admin", "vpn", "openvpn-server-custom", "download") ..
		"?name=" .. http.urlencode(client))
end

return f
