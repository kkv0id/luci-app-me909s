'use strict';
'require rpc';
'require form';
'require network';

var callFileList = rpc.declare({
	object: 'file',
	method: 'list',
	params: [ 'path' ],
	expect: { entries: [] },
	filter: function(list, params) {
		var rv = [];
		for (var i = 0; i < list.length; i++)
			if (list[i].name.match(/^ttyUSB/))
				rv.push(params.path + list[i].name);
		return rv.sort();
	}
});

network.registerPatternVirtual(/^ecm-.+$/);
network.registerErrorCode('PIN_FAILED', _('Sim pin failed'));
network.registerErrorCode('SIM_ERROR', _('Sim card status error'));
network.registerErrorCode('SIM_PUK', _('Sim card need unlock by puk'));
network.registerErrorCode('PDPTYPE_ERROR',      _('Set pdptype failed'));
network.registerErrorCode('GET_OPERATOR_ERROR', _('Get operator failed'));
network.registerErrorCode('LOCK_AT_ERROR',  _('Lock at timeout'));
network.registerErrorCode('DISCONNECT_FAILED', _('Disconnection attempt failed'));
network.registerErrorCode('NDISDUP_ERROR',   _('Connection failed'));
network.registerErrorCode('GET_ADDR_TIMEOUT',    _('Get ipaddr timeout'));
network.registerErrorCode('NET_REG_ERROR', _('Net reg failed'));
network.registerErrorCode('UNSUPPORTED_MODEM', _('Unsupported modem'));

return network.registerProtocol('ecm', {
	getI18n: function() {
		return _('ECM');
	},

	getIfname: function() {
		return this._ubus('l3_device') || 'wan';
	},

	getOpkgPackage: function() {
		return null;
	},

	isFloating: function() {
		return true;
	},

	isVirtual: function() {
		return true;
	},

	getDevices: function() {
		return null;
	},

	containsDevice: function(ifname) {
		return (network.getIfnameOf(ifname) == this.getIfname());
	},

	renderFormOptions: function(s) {
		var o;

		o = s.taboption('general', form.Value, 'device', _('Modem device'));
		o.rmempty = false;
		o.load = function(section_id) {
			return callFileList('/dev/').then(L.bind(function(devices) {
				for (var i = 0; i < devices.length; i++)
					this.value(devices[i]);
				return form.Value.prototype.load.apply(this, [section_id]);
			}, this));
		};

		s.taboption('general', form.Value, 'pincode', _('PIN'));

		o = s.taboption('general', form.ListValue, 'pdptype', _('IP Protocol'));
		o.default = 'IPV4V6';
		o.value('IP', _('IPv4'));
		o.value('IPV4V6', _('IPv4+IPv6'));
		o.value('IPV6', _('IPv6'));

		o = s.taboption('general', form.Value, 'apn', _('APN'));
		o.default = 'auto';
		
		o = s.taboption('general', form.ListValue, 'auth', _('Authentication Type'));
		o.default = '0';
		o.value('0', 'NONE');
		o.value('3', 'PAP/CHAP');
		o.value('1', 'PAP');
		o.value('2', 'CHAP');

		o = s.taboption('general', form.Value, 'username', _('PAP/CHAP username'));
		o.depends('auth', '1');
		o.depends('auth', '2');
		o.depends('auth', '3');

		o = s.taboption('general', form.Value, 'password', _('PAP/CHAP password'));
		o.depends('auth', '1');
		o.depends('auth', '2');
		o.depends('auth', '3');
		o.password = true;

		if (L.hasSystemFeature('ipv6')) {
			o = s.taboption('advanced', form.ListValue, 'ipv6', _('Obtain IPv6-Address'));
			o.value('auto', _('Automatic'));
			o.value('0', _('Disabled'));
			o.value('1', _('Manual'));
			o.default = 'auto';
		}

		o = s.taboption('advanced', form.Value, 'delay', _('Modem init timeout'), _('Maximum amount of seconds to wait for the modem to become ready'));
		o.placeholder = '10';
		o.datatype    = 'min(1)';

		o = s.taboption('advanced', form.Flag, 'defaultroute', _('Default gateway'), _('If unchecked, no default route is configured'));
		o.default = o.enabled;

		o = s.taboption('advanced', form.Value, 'metric', _('Use gateway metric'));
		o.placeholder = '0';
		o.datatype    = 'uinteger';
		o.depends('defaultroute', '1');

		o = s.taboption('advanced', form.Flag, 'peerdns', _('Use DNS servers advertised by peer'), _('If unchecked, the advertised DNS server addresses are ignored'));
		o.default = o.enabled;

		o = s.taboption('advanced', form.DynamicList, 'dns', _('Use custom DNS servers'));
		o.depends('peerdns', '0');
		o.datatype = 'ipaddr';
	}
});
