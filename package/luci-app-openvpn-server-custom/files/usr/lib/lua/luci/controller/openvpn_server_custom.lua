module("luci.controller.openvpn_server_custom", package.seeall)

local CLIENT_MANAGER = "/usr/libexec/openvpn-client-manager"
local SERVER_MANAGER = "/usr/libexec/openvpn-server-manager"
local CLIENT_BASE = "/etc/openvpn/client-custom"
local MAX_UPLOAD_SIZE = 1048576
local CLIENT_CIPHERS = {
	"CHACHA20-POLY1305",
	"AES-128-GCM",
	"AES-256-GCM",
	"AES-128-CBC",
	"AES-192-CBC",
	"AES-256-CBC",
	"AES-128-CFB",
	"AES-192-CFB",
	"AES-256-CFB",
	"AES-128-OFB",
	"AES-192-OFB",
	"AES-256-OFB"
}
function index()
	if not nixio.fs.access("/etc/config/openvpn_server") then
		return
	end

	entry({"admin", "vpn", "openvpn-server-custom"}, firstchild(), _("OpenVPN 服务器"), 65).dependent = true
	entry({"admin", "vpn", "openvpn-server-custom", "settings"}, cbi("openvpn-server-custom/server"), _("服务器设置"), 10).leaf = true
	entry({"admin", "vpn", "openvpn-server-custom", "server-client-add"}, post("server_client_add")).leaf = true
	entry({"admin", "vpn", "openvpn-server-custom", "server-client-download"}, post("server_client_download")).leaf = true
	entry({"admin", "vpn", "openvpn-server-custom", "server-client-action"}, post("server_client_action")).leaf = true
	entry({"admin", "vpn", "openvpn-server-custom", "clients"}, call("client_list"), _("客户端配置"), 20).leaf = true
	entry({"admin", "vpn", "openvpn-server-custom", "client-edit"}, call("client_edit")).leaf = true
	entry({"admin", "vpn", "openvpn-server-custom", "client-save"}, post("client_save")).leaf = true
	entry({"admin", "vpn", "openvpn-server-custom", "client-action"}, post("client_action")).leaf = true
	entry({"admin", "vpn", "openvpn-server-custom", "client-import"}, call("client_import")).leaf = true
	entry({"admin", "vpn", "openvpn-server-custom", "account-save"}, post("account_save")).leaf = true
	entry({"admin", "vpn", "openvpn-server-custom", "account-delete"}, post("account_delete")).leaf = true
end

local function valid_id(id)
	return type(id) == "string" and id:match("^c[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]$") ~= nil
end

local function manager_command(action, argument, extra)
	local util = require "luci.util"
	local command = CLIENT_MANAGER .. " " .. util.shellquote(action)
	if argument then
		command = command .. " " .. util.shellquote(argument)
	end
	if extra then
		command = command .. " " .. util.shellquote(extra)
	end
	return command
end

local function redirect_clients(message)
	local dispatcher = require "luci.dispatcher"
	local http = require "luci.http"
	local url = dispatcher.build_url("admin", "vpn", "openvpn-server-custom", "clients")
	if message and #message > 0 then
		url = url .. "?message=" .. http.urlencode(message)
	end
	http.redirect(url)
end

local function parse_profiles(output)
	local profiles = {}
	for line in (output or ""):gmatch("[^\r\n]+") do
		local id, name, host, port, proto, device, local_ip, state, err =
			line:match("^([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|(.*)$")
		if valid_id(id) then
			profiles[#profiles + 1] = {
				id = id,
				name = name,
				host = host,
				port = port,
				proto = proto,
				device = device,
				local_ip = local_ip,
				state = state,
				error = err
			}
		end
	end
	return profiles
end

function client_list()
	local http = require "luci.http"
	local sys = require "luci.sys"
	local template = require "luci.template"
	local profiles = parse_profiles(sys.exec(manager_command("list") .. " 2>/dev/null"))
	template.render("openvpn-server-custom/client-list", {
		profiles = profiles,
		message = http.formvalue("message") or ""
	})
end

local function file_contents(path)
	local fs = require "nixio.fs"
	if fs.access(path) then
		return fs.readfile(path) or ""
	end
	return ""
end

local function profile_data(id)
	local uci = require("luci.model.uci").cursor()
	local profile = {
		id = "",
		name = "",
		remote_host = "",
		remote_port = "1194",
		proto = "udp",
		auth_mode = "cert",
		tunnel_type = "tun",
		bind_interface = "auto",
		data_cipher = "auto",
		lzo = "1",
		tun_mtu = "",
		accept_routes = "1",
		enabled = "0",
		username = "",
		password = "",
		routes = "",
		ca = "",
		cert = "",
		key = "",
		extra = ""
	}
	if not valid_id(id) or not uci:get("openvpn_client_custom", id) then
		return profile
	end

	profile.id = id
	for _, option in ipairs({
		"name", "remote_host", "remote_port", "proto", "auth_mode", "tunnel_type",
		"bind_interface", "data_cipher", "lzo", "tun_mtu",
		"accept_routes", "enabled"
	}) do
		profile[option] = uci:get("openvpn_client_custom", id, option) or profile[option]
	end

	local dir = CLIENT_BASE .. "/" .. id
	local auth = file_contents(dir .. "/auth.txt")
	profile.username = auth:match("^([^\r\n]*)") or ""
	profile.routes = file_contents(dir .. "/routes")
	profile.ca = file_contents(dir .. "/ca.crt")
	profile.cert = file_contents(dir .. "/client.crt")
	profile.key = file_contents(dir .. "/client.key")
	profile.extra = file_contents(dir .. "/extra.conf")
	profile.has_password = #auth > 0
	return profile
end

local function available_interfaces()
	local uci = require("luci.model.uci").cursor()
	local interfaces = { "auto" }
	uci:foreach("network", "interface", function(section)
		local name = section[".name"]
		if name and name ~= "loopback" and not name:match("^ovpnc_") then
			interfaces[#interfaces + 1] = name
		end
	end)
	table.sort(interfaces, function(a, b)
		if a == "auto" then return true end
		if b == "auto" then return false end
		return a < b
	end)
	return interfaces
end

local function available_ciphers()
	local ciphers = { "auto" }
	for _, cipher in ipairs(CLIENT_CIPHERS) do
		ciphers[#ciphers + 1] = cipher
	end
	return ciphers
end

function client_edit()
	local http = require "luci.http"
	local template = require "luci.template"
	local id = http.formvalue("id") or ""
	if #id > 0 and not valid_id(id) then
		http.status(400, "Bad Request")
		return
	end
	template.render("openvpn-server-custom/client-edit", {
		profile = profile_data(id),
		interfaces = available_interfaces(),
		ciphers = available_ciphers(),
		message = http.formvalue("message") or ""
	})
end

local function create_staging()
	local sys = require "luci.sys"
	local path = sys.exec("mktemp -d /tmp/openvpn-client.XXXXXX 2>/dev/null"):gsub("%s+$", "")
	if not path:match("^/tmp/openvpn%-client%.[A-Za-z0-9]+$") then
		return nil
	end
	sys.call("chmod 0700 " .. require("luci.util").shellquote(path))
	return path
end

local function write_stage(path, name, value)
	local fs = require "nixio.fs"
	value = value or ""
	if #value > MAX_UPLOAD_SIZE then
		return false
	end
	return fs.writefile(path .. "/" .. name, value)
end

local function remove_staging(path)
	if path and path:match("^/tmp/openvpn%-client%.[A-Za-z0-9]+$") then
		require("luci.sys").call("rm -rf -- " .. require("luci.util").shellquote(path))
	end
end

function client_save()
	local http = require "luci.http"
	local sys = require "luci.sys"
	local id = http.formvalue("id") or ""
	local staging = create_staging()
	if not staging then
		redirect_clients("错误：无法创建安全临时目录。")
		return
	end
	if #id > 0 and not valid_id(id) then
		remove_staging(staging)
		redirect_clients("错误：客户端配置ID无效。")
		return
	end

	local fields = {
		id = id,
		name = http.formvalue("name"),
		remote_host = http.formvalue("remote_host"),
		remote_port = http.formvalue("remote_port"),
		proto = http.formvalue("proto"),
		auth_mode = http.formvalue("auth_mode"),
		tunnel_type = http.formvalue("tunnel_type"),
		bind_interface = http.formvalue("bind_interface"),
		data_cipher = http.formvalue("data_cipher"),
		lzo = http.formvalue("lzo") and "1" or "0",
		tun_mtu = http.formvalue("tun_mtu"),
		accept_routes = http.formvalue("accept_routes") and "1" or "0",
		enabled = http.formvalue("enabled") and "1" or "0",
		routes = http.formvalue("routes"),
		["ca.crt"] = http.formvalue("ca"),
		["client.crt"] = http.formvalue("cert"),
		["client.key"] = http.formvalue("key"),
		["extra.conf"] = http.formvalue("extra")
	}
	for name, value in pairs(fields) do
		if not write_stage(staging, name, value) then
			remove_staging(staging)
			redirect_clients("错误：表单字段过大。")
			return
		end
	end

	write_stage(staging, "username", http.formvalue("username") or "")
	local password = http.formvalue("password") or ""
	if #password > 0 then
		write_stage(staging, "password", password)
	end

	local result = sys.exec(manager_command("save", staging) .. " 2>&1"):gsub("%s+$", "")
	remove_staging(staging)
	if result:match("^c%x%x%x%x%x%x%x%x|1$") then
		redirect_clients("客户端配置已保存。")
	elseif result:match("^c%x%x%x%x%x%x%x%x|0$") then
		redirect_clients("配置已保存，但证书或账号信息尚未完善，已保持停用。")
	else
		local dispatcher = require "luci.dispatcher"
		http.redirect(dispatcher.build_url("admin", "vpn", "openvpn-server-custom", "client-edit") ..
			(#id > 0 and ("?id=" .. http.urlencode(id) .. "&") or "?") ..
			"message=" .. http.urlencode(result))
	end
end

function client_action()
	local http = require "luci.http"
	local sys = require "luci.sys"
	local selected = http.formvaluetable("selected") or {}
	local ids = {}
	local action = http.formvalue("action") or ""
	if action ~= "enable" and action ~= "disable" and action ~= "delete" then
		redirect_clients("错误：操作类型无效。")
		return
	end
	for id in pairs(selected) do
		if valid_id(id) then
			ids[#ids + 1] = id
		end
	end
	table.sort(ids)
	if #ids == 0 then
		redirect_clients("错误：请至少选择一个客户端配置。")
		return
	end
	local result = sys.exec(manager_command(action, table.concat(ids, ",")) .. " 2>&1"):gsub("%s+$", "")
	redirect_clients(result)
end

function client_import()
	local dispatcher = require "luci.dispatcher"
	local http = require "luci.http"
	local fs = require "nixio.fs"
	local sys = require "luci.sys"
	local util = require "luci.util"
	local upload = sys.exec("mktemp /tmp/openvpn-client-upload.XXXXXX 2>/dev/null"):gsub("%s+$", "")
	local output
	local size = 0
	local too_large = false
	local filename = "Imported OpenVPN"

	if not upload:match("^/tmp/openvpn%-client%-upload%.[A-Za-z0-9]+$") then
		redirect_clients("错误：无法创建上传临时文件。")
		return
	end
	sys.call("chmod 0600 " .. util.shellquote(upload))

	http.setfilehandler(function(meta, chunk, eof)
		if not meta or meta.name ~= "ovpn" then
			return
		end
		if meta.file and #meta.file > 0 then
			filename = meta.file:gsub("^.*[/\\]", ""):gsub("%.ovpn$", "")
			filename = filename:gsub("[%c|]", "_"):sub(1, 64)
			if #filename == 0 then filename = "Imported OpenVPN" end
		end
		if chunk and #chunk > 0 and not too_large then
			size = size + #chunk
			if size > MAX_UPLOAD_SIZE then
				too_large = true
			else
				local file = io.open(upload, "ab")
				if file then
					file:write(chunk)
					file:close()
				end
			end
		end
	end)

	if not dispatcher.test_post_security() then
		fs.unlink(upload)
		return
	end
	http.formvalue("ovpn")
	if too_large then
		fs.unlink(upload)
		redirect_clients("错误：OVPN文件超过1MiB限制。")
		return
	end

	output = sys.exec(manager_command("import", upload, filename) .. " 2>&1"):gsub("%s+$", "")
	fs.unlink(upload)
	if output:match("^c%x%x%x%x%x%x%x%x|1$") then
		redirect_clients("OVPN配置导入成功。")
	elseif output:match("^c%x%x%x%x%x%x%x%x|0$") then
		redirect_clients("OVPN已导入，但外部证书或账号信息需要补充。")
	else
		redirect_clients(output)
	end
end

local function redirect_server_settings(message)
    local dispatcher = require "luci.dispatcher"
    local http = require "luci.http"
    local url = dispatcher.build_url("admin", "vpn", "openvpn-server-custom", "settings")
    if message and #message > 0 then
        url = url .. "?message=" .. http.urlencode(message)
    end
    http.redirect(url)
end

local function valid_server_client_name(name)
    return type(name) == "string" and name ~= "server" and name:match("^[A-Za-z0-9_-]+$") ~= nil and #name <= 32
end

function server_client_add()
    local dispatcher = require "luci.dispatcher"
    local http = require "luci.http"
    local sys = require "luci.sys"
    local fs = require "nixio.fs"
    local util = require "luci.util"
    local name = http.formvalue("server_client_name") or ""
    if not dispatcher.test_post_security() then
        return
    end
    if not valid_server_client_name(name) then
        redirect_server_settings("错误：客户端用户名只能包含字母、数字、下划线和连字符，最长32个字符。")
        return
    end
    if not fs.access("/etc/easy-rsa/pki/ca.crt") then
        redirect_server_settings("错误：请先初始化CA和服务器证书。")
        return
    end
    local result = sys.exec(SERVER_MANAGER .. " create-client " .. util.shellquote(name) .. " 2>&1"):gsub("%s+$", "")
    redirect_server_settings(result)
end

function server_client_download()
    local dispatcher = require "luci.dispatcher"
    local http = require "luci.http"
    local sys = require "luci.sys"
    local util = require "luci.util"
    local name = http.formvalue("server_client_name") or ""
    if not dispatcher.test_post_security() then
        return
    end
    if not valid_server_client_name(name) then
        http.status(400, "Bad Request")
        http.prepare_content("text/plain; charset=utf-8")
        http.write("客户端用户名格式无效。\n")
        return
    end
    local profile = sys.exec(SERVER_MANAGER .. " export-client " .. util.shellquote(name) .. " 2>&1")
    if not profile:match("^client\n") then
        http.status(409, "Conflict")
        http.prepare_content("text/plain; charset=utf-8")
        if profile:match("^错误：") then
            http.write(profile)
        else
            http.write("无法生成客户端配置。\n")
        end
        return
    end
    http.header("Cache-Control", "no-store")
    http.header("Pragma", "no-cache")
    http.header("Content-Disposition", string.format('attachment; filename="%s.ovpn"', name))
    http.prepare_content("application/x-openvpn-profile")
    http.write(profile)
end

function server_client_action()
    local dispatcher = require "luci.dispatcher"
    local http = require "luci.http"
    local sys = require "luci.sys"
    local util = require "luci.util"
    local name = http.formvalue("server_client_name") or ""
    local action = http.formvalue("server_client_action") or ""
    local commands = {
        enable = "enable-client",
        disable = "disable-client",
        delete = "delete-client"
    }
    if not dispatcher.test_post_security() then
        return
    end
    if not valid_server_client_name(name) or not commands[action] then
        redirect_server_settings("错误：客户端用户操作无效。")
        return
    end
    local result = sys.exec(SERVER_MANAGER .. " " .. commands[action] .. " " .. util.shellquote(name) .. " 2>&1"):gsub("%s+$", "")
    redirect_server_settings(result)
end
function account_save()
    local dispatcher = require "luci.dispatcher"
    local http = require "luci.http"
    local sys = require "luci.sys"
    local fs = require "nixio.fs"
    local util = require "luci.util"
    local username = http.formvalue("account_username") or ""
    local password = http.formvalue("account_password") or ""
    if not dispatcher.test_post_security() then
        return
    end
    if username:match("[^A-Za-z0-9_.-]") or #username == 0 or #username > 32 or
        username:find("[\r\n]") or password:find("[\r\n]") or #password > 256 then
        redirect_server_settings("错误：账号或密码格式无效。")
        return
    end
    local stage = sys.exec("mktemp /tmp/openvpn-account.XXXXXX 2>/dev/null"):gsub("%s+$", "")
    if not stage:match("^/tmp/openvpn%-account%.[A-Za-z0-9]+$") then
        redirect_server_settings("错误：无法创建账号临时文件。")
        return
    end
    sys.call("chmod 0600 " .. util.shellquote(stage))
    if not fs.writefile(stage, username .. "\n" .. password .. "\n") then
        fs.unlink(stage)
        redirect_server_settings("错误：无法写入账号临时文件。")
        return
    end
    local result = sys.exec(SERVER_MANAGER .. " save-account " .. util.shellquote(stage) .. " 2>&1"):gsub("%s+$", "")
    fs.unlink(stage)
    redirect_server_settings(result)
end

function account_delete()
    local dispatcher = require "luci.dispatcher"
    local http = require "luci.http"
    local sys = require "luci.sys"
    local util = require "luci.util"
    local username = http.formvalue("account_delete") or ""
    if not dispatcher.test_post_security() then
        return
    end
    if not username:match("^[A-Za-z0-9_.-]+$") or #username > 32 then
        redirect_server_settings("错误：用户名格式无效。")
        return
    end
    local result = sys.exec(SERVER_MANAGER .. " delete-account " .. util.shellquote(username) .. " 2>&1"):gsub("%s+$", "")
    redirect_server_settings(result)
end
