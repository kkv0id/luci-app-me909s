local sys = require "luci.sys"

m = Map("me909s", translate("设置"), translate("切换SIM卡模块会重启"))
m.apply_on_parse = true
m.on_apply = function()
    sys.call("/etc/init.d/me909s reload")
end

ts = m:section(TypedSection, "setting")
ts.addremove = false
ts.anonymous = true

local sim_val = sys.exec("cat /sys/class/gpio/sim_select/value")

sim_slot = ts:option(ListValue, "sim_slot", translate("SIM卡切换"))
sim_slot.default = sim_val
sim_slot:value("1", translate("SIM"))
sim_slot:value("0", translate("eSIM"))

local usb_val = sys.exec("cat /sys/class/gpio/usb_power/value")

usb_power = ts:option(ListValue, "usb_power", translate("USB开关"))
usb_power.default = usb_val
usb_power:value("1", translate("开"))
usb_power:value("0", translate("关"))

return m
