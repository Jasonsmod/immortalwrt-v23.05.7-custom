module("luci.controller.openvpn_server_custom", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/openvpn_server") then
		return
	end

	entry({"admin", "vpn", "openvpn-server-custom"}, firstchild(), _("OpenVPN 服务器"), 65).dependent = true
	entry({"admin", "vpn", "openvpn-server-custom", "settings"}, cbi("openvpn-server-custom/server"), _("服务器设置"), 10).leaf = true
	entry({"admin", "vpn", "openvpn-server-custom", "clients"}, cbi("openvpn-server-custom/clients"), _("客户端证书"), 20).leaf = true
	entry({"admin", "vpn", "openvpn-server-custom", "download"}, call("download_client")).leaf = true
end

function download_client()
	local http = require "luci.http"
	local sys = require "luci.sys"
	local util = require "luci.util"
	local name = http.formvalue("name") or ""

	if #name == 0 or #name > 32 or not name:match("^[A-Za-z0-9_-]+$") then
		http.status(400, "Bad Request")
		http.prepare_content("text/plain; charset=utf-8")
		http.write("客户端名称无效。\n")
		return
	end

	local command = "/usr/libexec/openvpn-server-manager export-client " .. util.shellquote(name) .. " 2>/dev/null"
	local profile = sys.exec(command)
	if not profile:match("^client\n") then
		http.status(404, "Not Found")
		http.prepare_content("text/plain; charset=utf-8")
		http.write("无法生成客户端配置，请检查证书和公网地址。\n")
		return
	end

	http.header("Cache-Control", "no-store")
	http.header("Pragma", "no-cache")
	http.header("Content-Disposition", string.format('attachment; filename="%s.ovpn"', name))
	http.prepare_content("application/x-openvpn-profile")
	http.write(profile)
end
