'use strict';
'require baseclass';
'require rpc';

var callConnectedDevices = rpc.declare({
	object: 'luci.connected-devices',
	method: 'getDevices',
	expect: { '': {} }
});

var connectedDevicesTimeout = 3000;

function statusText(state) {
	switch (state) {
	case 'associated':
		return _('已连接');
	case 'reachable':
	case 'delay':
	case 'probe':
		return _('在线');
	case 'permanent':
		return _('固定邻居');
	case 'stale':
		return _('最近在线');
	case 'dhcp':
		return _('DHCP 租约');
	case 'static':
		return _('固定地址');
	default:
		return state || _('未知');
	}
}

function typeText(type) {
	return type == 'wifi' ? _('Wi-Fi') : _('LAN');
}

function renderAddress(device) {
	var type = typeText(device.type);
	var icon = device.type == 'wifi' ? 'icons/wifi.png' : 'icons/ethernet.png';

	return E('span', {
		'class': 'ifacebadge',
		'title': type
	}, [
		E('img', {
			'src': L.resource(icon),
			'alt': type
		}),
		E('span', {}, [ ' ', device.ip || '-' ])
	]);
}

return baseclass.extend({
	title: _('连接设备'),

	load: function() {
		var request = callConnectedDevices().catch(function(error) {
			return {
				devices: [],
				error: error && error.message ? error.message : String(error)
			};
		});
		var timeout = new Promise(function(resolve) {
			setTimeout(function() {
				resolve({
					devices: [],
					error: _("读取连接设备超时")
				});
			}, connectedDevicesTimeout);
		});
		return Promise.race([ request, timeout ]);
	},

	render: function(data) {
		data = data || {};
		var devices = Array.isArray(data.devices) ? data.devices : [];
		var table = E('table', { 'class': 'table connected-devices' }, [
			E('tr', { 'class': 'tr table-titles' }, [
				E('th', { 'class': 'th' }, _('设备名称')),
				E('th', { 'class': 'th' }, _('IP 地址')),
				E('th', { 'class': 'th' }, _('MAC 地址')),
				E('th', { 'class': 'th' }, _('连接方式')),
				E('th', { 'class': 'th' }, _('接口')),
				E('th', { 'class': 'th' }, _('状态'))
			])
		]);

		cbi_update_table(table, devices.map(function(device) {
			return [
				device.hostname || '-',
				renderAddress(device),
				device.mac || '-',
				typeText(device.type),
				device.interface || '-',
				statusText(device.state)
			];
		}), E('em', _('当前未检测到连接设备')));

		return E([
			data.error ? E('div', { 'class': 'alert-message warning' }, [
				_('连接设备后端暂时不可用：%s').format(data.error)
			]) : E([]),
			table,
			E('p', { 'class': 'cbi-section-descr' }, [
				_('固定 DHCP 地址会直接列出；手动静态 IP 设备需要曾与路由器通信，才能从邻居表中识别。')
			])
		]);
	}
});
