module("luci.controller.terminal_limit", package.seeall)

local CONFIG = "terminal_limit"
local MANAGER = "/usr/libexec/terminal-limit-manager"
local MAX_TARGETS = 256

local function valid_kind(kind)
	return kind == "ip" or kind == "mac"
end

local function section_type(kind)
	return kind == "ip" and "ip_rule" or "mac_rule"
end

local function split_words(value)
	local result = {}
	for word in (value or ""):gmatch("[^,%s]+") do
		result[#result + 1] = word
	end
	return result
end

local function join_words(values)
	local result = {}
	for _, value in ipairs(values or {}) do
		if value and #value > 0 then
			result[#result + 1] = value
		end
	end
	return table.concat(result, ", ")
end

local function form_list(http, name)
	local values = http.formvaluetable(name) or {}
	local result = {}
	if type(values) == "table" then
		for _, value in pairs(values) do
			if type(value) == "string" then result[#result + 1] = value end
		end
	end
	if #result == 0 then
		local value = http.formvalue(name)
		if type(value) == "table" then
			for _, item in pairs(value) do
				if type(item) == "string" then result[#result + 1] = item end
			end
		elseif type(value) == "string" then
			result[1] = value
		end
	end
	return result
end

local function valid_uint(value, maximum)
	return type(value) == "string" and value:match("^%d+$") and
		tonumber(value) <= (maximum or 2147483647)
end

local function valid_rate(value)
	return valid_uint(value, 12500000)
end

local function valid_time(value)
	local hour, minute = (value or ""):match("^(%d%d):(%d%d)$")
	return hour and tonumber(hour) <= 23 and tonumber(minute) <= 59
end

local function valid_ports(value)
	if not value or value == "" then
		return true
	end
	for part in value:gmatch("[^,]+") do
		local left, right = part:match("^(%d+)%-(%d+)$")
		if left then
			if tonumber(left) < 1 or tonumber(right) > 65535 or tonumber(left) > tonumber(right) then
				return false
			end
		elseif not part:match("^%d+$") or tonumber(part) < 1 or tonumber(part) > 65535 then
			return false
		end
	end
	return true
end

local function valid_ipv4(value)
	local count = 0
	for part in (value or ""):gmatch("%d+") do
		if tonumber(part) > 255 then
			return false
		end
		count = count + 1
	end
	return count == 4 and value:match("^%d+%.%d+%.%d+%.%d+$") ~= nil
end

local function ipv4_number(value)
	local a, b, c, d = value:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
	return (((tonumber(a) * 256 + tonumber(b)) * 256 + tonumber(c)) * 256 + tonumber(d))
end

local function valid_ip_target(value)
	if value:find("[^%x%.:%/%-]") then
		return false
	end
	if value:find(":") then
		local address, prefix = value:match("^([^/]+)/(%d+)$")
		if address then
			return address:match("^[%x:]+$") ~= nil and tonumber(prefix) <= 128
		end
		return value:match("^[%x:]+$") ~= nil
	end
	local first, last = value:match("^(.-)%-(.-)$")
	if first then
		return valid_ipv4(first) and valid_ipv4(last) and ipv4_number(first) <= ipv4_number(last)
	end
	local address, prefix = value:match("^([^/]+)/(%d+)$")
	if address then
		return valid_ipv4(address) and tonumber(prefix) <= 32
	end
	return valid_ipv4(value)
end

local function valid_mac(value)
	return value and value:match("^[%x][%x]:[%x][%x]:[%x][%x]:[%x][%x]:[%x][%x]:[%x][%x]$") ~= nil
end

local function available_interfaces()
	local uci = require("luci.model.uci").cursor()
	local result = {}
	uci:foreach("network", "interface", function(section)
		local name = section[".name"]
		if name and name ~= "loopback" and not name:match("^%w+_%d+$") then
			result[#result + 1] = name
		end
	end)
	if #result == 0 then
		result = { "wan" }
	end
	table.sort(result)
	return result
end

local function interface_allowed(name)
	for _, interface in ipairs(available_interfaces()) do
		if interface == name then
			return true
		end
	end
	return false
end

local function parse_status(output)
	local status = {}
	for line in (output or ""):gmatch("[^\r\n]+") do
		local key, value = line:match("^([^=]+)=(.*)$")
		if key then
			status[key] = value
		end
	end
	return status
end

local function runtime_status()
	local sys = require "luci.sys"
	return parse_status(sys.exec(MANAGER .. " status 2>/dev/null"))
end

local function apply_rules()
	local sys = require "luci.sys"
	local util = require "luci.util"
	return sys.exec(util.shellquote(MANAGER) .. " apply 2>&1")
end

local function redirect(kind, message)
	local http = require "luci.http"
	local dispatcher = require "luci.dispatcher"
	local url = dispatcher.build_url("admin", "network", "terminal-limit", kind)
	if message and #message > 0 then
		url = url .. "?message=" .. http.urlencode(message)
	end
	http.redirect(url)
end

local function load_rule(kind, id)
	local uci = require("luci.model.uci").cursor()
	local rule = {
		id = "",
		enabled = "1",
		interface = "wan",
		targets = {},
		protocol = "any",
		src_ports = "",
		dst_ports = "",
		family = "4",
		mode = "independent",
		upload_kbyte = "0",
		download_kbyte = "0",
		weekdays = { "1", "2", "3", "4", "5", "6", "7" },
		time_start = "00:00",
		time_end = "23:59",
		comment = ""
	}
	if not id or id == "" then
		return rule
	end
	local found = false
	uci:foreach(CONFIG, section_type(kind), function(section)
		if section[".name"] == id then
			found = true
			rule.id = id
			rule.enabled = section.enabled or rule.enabled
			rule.interface = section.interface or rule.interface
			rule.targets = section.targets or {}
			rule.protocol = section.protocol or rule.protocol
			rule.src_ports = section.src_ports or ""
			rule.dst_ports = section.dst_ports or ""
			rule.family = section.family or rule.family
			rule.mode = section.mode or rule.mode
			rule.upload_kbyte = section.upload_kbyte or rule.upload_kbyte
			rule.download_kbyte = section.download_kbyte or rule.download_kbyte
		rule.weekdays = section.weekdays or rule.weekdays
		rule.time_start = section.time_start or rule.time_start
		rule.time_end = section.time_end or rule.time_end
		rule.comment = section.comment or ""
		end
	end)
	return found and rule or load_rule(kind, "")
end

local function collect_rules(kind)
	local uci = require("luci.model.uci").cursor()
	local rules = {}
	uci:foreach(CONFIG, section_type(kind), function(section)
		rules[#rules + 1] = {
			id = section[".name"],
			enabled = section.enabled == "1",
			interface = section.interface or "",
			targets = join_words(section.targets),
			protocol = section.protocol or "any",
			src_ports = section.src_ports or "",
			dst_ports = section.dst_ports or "",
			family = section.family or "4",
			mode = section.mode or "independent",
			upload_kbyte = section.upload_kbyte or "0",
			download_kbyte = section.download_kbyte or "0",
			weekdays = join_words(section.weekdays),
			time = (section.time_start or "00:00") .. "-" .. (section.time_end or "23:59"),
			comment = section.comment or ""
		}
	end)
	return rules
end

local function list_view(kind)
	local template = require "luci.template"
	local http = require "luci.http"
	local dispatcher = require "luci.dispatcher"
	template.render("terminal-limit/list", {
		kind = kind,
		rules = collect_rules(kind),
		global = (function()
			local uci = require("luci.model.uci").cursor()
			return {
				enabled = uci:get(CONFIG, "main", "enabled") or "0",
				qdisc = uci:get(CONFIG, "main", "qdisc") or "cake"
			}
		end)(),
		status = runtime_status(),
		message = http.formvalue("message") or "",
		urls = {
			list = dispatcher.build_url("admin", "network", "terminal-limit", kind),
			edit = dispatcher.build_url("admin", "network", "terminal-limit", "edit"),
			action = dispatcher.build_url("admin", "network", "terminal-limit", "action"),
			global = dispatcher.build_url("admin", "network", "terminal-limit", "global-save")
		}
	})
end

function ip_list()
	list_view("ip")
end

function mac_list()
	list_view("mac")
end

function rule_edit()
	local http = require "luci.http"
	local template = require "luci.template"
	local kind = http.formvalue("kind") or "ip"
	if not valid_kind(kind) then
		http.status(400, "Bad Request")
		return
	end
	template.render("terminal-limit/edit", {
		kind = kind,
		rule = load_rule(kind, http.formvalue("id") or ""),
		interfaces = available_interfaces(),
		message = http.formvalue("message") or ""
	})
end

function rule_save()
	local http = require "luci.http"
	local uci = require("luci.model.uci").cursor()
	local kind = http.formvalue("kind") or "ip"
	local id = http.formvalue("id") or ""
	local targets = split_words(http.formvalue("targets") or "")
	local time = http.formvalue("time") or "00:00-23:59"
	local start_time, end_time = time:match("^(%d%d:%d%d)%-(%d%d:%d%d)$")
	local protocol = http.formvalue("protocol") or "any"
	local src_ports = http.formvalue("src_ports") or ""
	local dst_ports = http.formvalue("dst_ports") or ""
	local enabled = http.formvalue("enabled") == "1" and "1" or "0"
	local weekdays = form_list(http, "weekdays")
	local mode = http.formvalue("mode") or "independent"
	local upload = http.formvalue("upload_kbyte") or "0"
	local download = http.formvalue("download_kbyte") or "0"
	local interface = http.formvalue("interface") or ""
	local error_message

	if not valid_kind(kind) then error_message = "规则类型无效。" end
	if not error_message and not interface_allowed(interface) then error_message = "线路接口无效。" end
	if not error_message and #targets == 0 then error_message = "至少填写一个IP或MAC目标。" end
	if not error_message and #targets > MAX_TARGETS then error_message = "单条规则最多支持256个目标。" end
	if not error_message and (mode ~= "independent" and mode ~= "shared") then error_message = "限速模式无效。" end
	if not error_message and (not valid_rate(upload) or not valid_rate(download)) then error_message = "速率必须是0到12500000之间的整数。" end
	if not error_message and (not start_time or not end_time or not valid_time(start_time) or not valid_time(end_time)) then error_message = "时间段必须使用HH:MM-HH:MM格式。" end
	if not error_message and #weekdays == 0 then error_message = "至少选择一天。" end
	if not error_message then
		for _, day in ipairs(weekdays) do
			if not day:match("^[1-7]$") then error_message = "星期值无效。" break end
		end
	end
	if not error_message and kind == "ip" then
		if protocol ~= "any" and protocol ~= "tcp" and protocol ~= "udp" and protocol ~= "tcp_udp" then
			error_message = "协议值无效。"
		elseif protocol == "any" and (src_ports ~= "" or dst_ports ~= "") then
			error_message = "任意协议不能填写端口。"
		elseif not valid_ports(src_ports) or not valid_ports(dst_ports) then
			error_message = "端口必须是1到65535的数字、逗号或范围。"
		end
		for _, target in ipairs(targets) do
			if not valid_ip_target(target) then error_message = "IP或IP段格式无效：" .. target break end
		end
	else
		local family = http.formvalue("family") or "4"
		if family ~= "4" and family ~= "6" then error_message = "协议栈无效。" end
		for index, target in ipairs(targets) do
			targets[index] = string.upper(target)
			if not valid_mac(targets[index]) then error_message = "MAC地址格式无效：" .. target break end
		end
	end
	if error_message then
		redirect(kind, "错误：" .. error_message)
		return
	end

	local section
	if id ~= "" and uci:get(CONFIG, id) == section_type(kind) then
		section = id
	end
	if not section then
		section = uci:add(CONFIG, section_type(kind))
	end
	uci:set(CONFIG, section, "enabled", enabled)
	uci:set(CONFIG, section, "interface", interface)
	uci:delete(CONFIG, section, "targets")
	for _, target in ipairs(targets) do uci:add_list(CONFIG, section, "targets", target) end
	uci:set(CONFIG, section, "mode", mode)
	uci:set(CONFIG, section, "upload_kbyte", upload)
	uci:set(CONFIG, section, "download_kbyte", download)
	uci:delete(CONFIG, section, "weekdays")
	for _, day in ipairs(weekdays) do uci:add_list(CONFIG, section, "weekdays", day) end
	uci:set(CONFIG, section, "time_start", start_time)
	uci:set(CONFIG, section, "time_end", end_time)
	uci:set(CONFIG, section, "comment", http.formvalue("comment") or "")
	if kind == "ip" then
		uci:set(CONFIG, section, "protocol", protocol)
		uci:set(CONFIG, section, "src_ports", src_ports)
		uci:set(CONFIG, section, "dst_ports", dst_ports)
	else
		uci:set(CONFIG, section, "family", http.formvalue("family") or "4")
	end
	uci:commit(CONFIG)
	local result = apply_rules()
	if result and #result > 0 and result:match("error|错误|failed|失败") then
		redirect(kind, result:gsub("[\r\n]+", " "))
	else
		redirect(kind, "规则已保存并应用。")
	end
end

function rule_action()
	local http = require "luci.http"
	local uci = require("luci.model.uci").cursor()
	local kind = http.formvalue("kind") or "ip"
	local action = http.formvalue("action") or ""
	if not valid_kind(kind) or (action ~= "enable" and action ~= "disable" and action ~= "delete") then
		redirect(valid_kind(kind) and kind or "ip", "错误：批量操作无效。")
		return
	end
	local changed = 0
	uci:foreach(CONFIG, section_type(kind), function(section)
		local id = section[".name"]
		if http.formvalue("selected." .. id) == "1" then
			if action == "delete" then uci:delete(CONFIG, id) else uci:set(CONFIG, id, "enabled", action == "enable" and "1" or "0") end
			changed = changed + 1
		end
	end)
	if changed == 0 then
		redirect(kind, "请至少选择一条规则。")
		return
	end
	uci:commit(CONFIG)
	local result = apply_rules()
	redirect(kind, (result and #result > 0 and result:match("error|错误|failed|失败")) and result:gsub("[\r\n]+", " ") or ("已处理 " .. changed .. " 条规则。"))
end

function global_save()
	local http = require "luci.http"
	local uci = require("luci.model.uci").cursor()
	local kind = http.formvalue("kind") or "ip"
	if not valid_kind(kind) then kind = "ip" end
	local enabled = http.formvalue("enabled") == "1" and "1" or "0"
	local qdisc = http.formvalue("qdisc") or "cake"
	if qdisc ~= "cake" and qdisc ~= "fq_codel" then
		redirect(kind, "错误：队列只能选择cake或fq_codel。")
		return
	end
	uci:set(CONFIG, "main", "enabled", enabled)
	uci:set(CONFIG, "main", "qdisc", qdisc)
	uci:commit(CONFIG)
	local result = apply_rules()
	redirect(kind, (result and #result > 0 and result:match("error|错误|failed|失败")) and result:gsub("[\r\n]+", " ") or "全局设置已保存并应用。")
end

function index()
	if not nixio.fs.access("/etc/config/terminal_limit") then return end
	entry({"admin", "network", "terminal-limit"}, firstchild(), _("终端限速"), 58).dependent = true
	entry({"admin", "network", "terminal-limit", "ip"}, call("ip_list"), _("IP限速"), 10).leaf = true
	entry({"admin", "network", "terminal-limit", "mac"}, call("mac_list"), _("MAC限速"), 20).leaf = true
	entry({"admin", "network", "terminal-limit", "edit"}, call("rule_edit")).leaf = true
	entry({"admin", "network", "terminal-limit", "save"}, post("rule_save")).leaf = true
	entry({"admin", "network", "terminal-limit", "action"}, post("rule_action")).leaf = true
	entry({"admin", "network", "terminal-limit", "global-save"}, post("global_save")).leaf = true
end
