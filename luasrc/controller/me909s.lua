module("luci.controller.me909s", package.seeall)
local http = require("luci.http")
local sys = require "luci.sys"
function index()
    entry({"admin", "me909s"}, firstchild(), _("鼎桥"), 25).dependent = true
    entry({"admin", "me909s", "status"}, template("me909s/status", {
        hideapplybtn = true,
        hidesavebtn = true,
        hideresetbtn = true
    }), _("状态"), 10)
    entry({"admin", "me909s", "setting"}, cbi("me909s/setting"), _("设置"), 20)
    entry({"admin", "me909s", "advance"}, cbi("me909s/advance", {
        hideapplybtn = true,
        hidesavebtn = true,
        hideresetbtn = true
    }), _("高级"), 30)
    entry({"admin", "me909s", "at"}, template("me909s/at", {
        hideapplybtn = true,
        hidesavebtn = true,
        hideresetbtn = true
    }), _("AT"), 40)
    entry({"admin", "me909s", "status", "data"}, call("status_data")).leaf = true
    entry({"admin", "me909s", "at", "cmd"}, call("send_at"))
end

function status_data(interface)
    local uci = require "uci".cursor(nil, "/var/state")

    local sim_val = sys.exec("cat /sys/class/gpio/sim_select/value 2>/dev/null")
    if sim_val then
        sim_val = string.gsub(sim_val, "%s+", "")
    end
    local status
    if interface ~= nil then
        status = {
            manufacturer = uci:get("network", interface, "manufacturer"),
            model = uci:get("network", interface, "model"),
            revision = uci:get("network", interface, "revision"),
            simslot = sim_val or "1",
            imei = uci:get("network", interface, "imei"),
            imsi = uci:get("network", interface, "imsi"),
            iccid = uci:get("network", interface, "iccid"),
            operator = uci:get("network", interface, "operator"),
            rxlev = uci:get("network", interface, "rxlev"),
            temp = uci:get("network", interface, "temp"),
            mode = uci:get("network", interface, "mode"),
            lac = uci:get("network", interface, "lac"),
            sim_state = uci:get("network", interface, "sim_state"),
            band = uci:get("network", interface, "band"),
            arfcn = uci:get("network", interface, "arfcn"),
            cellid = uci:get("network", interface, "cellid"),
            pci = uci:get("network", interface, "pci"),
            tac = uci:get("network", interface, "tac"),
            rsrp = uci:get("network", interface, "rsrp"),
            rsrq = uci:get("network", interface, "rsrq")
        }
    end
    luci.http.prepare_content("application/json")
    luci.http.write_json(status or {})
end

function send_at()
    local ctl_device = http.formvalue("ctl_device")
	local atcmd = http.formvalue("atcmd")
    local timeout = http.formvalue("timeout")

    local _cmd=string.format('/lib/me909s.sh atcmd "%s" "%s" %d', ctl_device, atcmd, timeout)
    local result = sys.exec(_cmd) 

    http.prepare_content("text/plain")
    http.write(result)
end