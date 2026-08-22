'use strict';
'require baseclass';
'require rpc';

var callConnectedDevices = rpc.declare({
	object: 'luci.connected-devices',
	method: 'getDevices',
	expect: { devices: [] }
});

function statusText(state) {
	switch (state) {
	case 'associated':
		return _('已连接');
	case 'reachable':
		return _('活跃');
	case 'stale':
		return _('近期可见');
	case 'dhcp':
		return _('DHCP 租约');
	default:
		return state || _('未知');
	}
}

function typeText(type) {
	return type == 'wifi' ? _('WIFI') : _('LAN');
}

return baseclass.extend({
	title: '',

	load: function() {
		return callConnectedDevices();
	},

	render: function(data) {
		var devices = Array.isArray(data) ? data : [];
		var table = E('table', { 'class': 'table connected-devices' }, [
			E('tr', { 'class': 'tr table-titles' }, [
				E('th', { 'class': 'th' }, _('IP 地址')),
				E('th', { 'class': 'th' }, _('MAC 地址')),
				E('th', { 'class': 'th' }, _('接入类型')),
				E('th', { 'class': 'th' }, _('接口')),
				E('th', { 'class': 'th' }, _('状态'))
			])
		]);

		cbi_update_table(table, devices.map(function(device) {
			return [
				device.ip || '-',
				device.mac || '-',
				typeText(device.type),
				device.interface || '-',
				statusText(device.state)
			];
		}), E('em', _('暂无检测到连接设备')));

		return E([
			E('h3', _('连接的设备')),
			table,
			E('p', { 'class': 'cbi-section-descr' }, _('静态 IP 设备需先产生网络通信，才能出现在邻居表中。'))
		]);
	}
});
