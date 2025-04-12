local uci = require"uci".cursor(nil, "/var/state")
local sys = require "luci.sys"
local json = require("luci.jsonc")

local target_interface = sys.exec("grep \".model=\" /var/state/network | awk -F'.' '{print $2}'")

local cur_imei
local ctl_device
if target_interface then
    target_interface = string.gsub(target_interface, "%s+", "")
    cur_imei = uci:get("network", target_interface, "imei")
    ctl_device = uci:get("network", target_interface, "ctl_device")
end

m = Map("me909s", translate("高级设置"), translate("如非必要，请勿修改"))
if not ctl_device or ctl_device == '' then
    m:section(SimpleSection, "错误", "未检测到模块")
    return m
end
m:append(Template("me909s/css"))
m:append(Template("me909s/js"))
ss = m:section(SimpleSection, "IMEI", "修改IMEI后重启模块生效")
function ss.parse(self, section, novld)
end

imei = ss:option(Value, "imei", translate("IMEI"))
imei.default = cur_imei
imei.datatype = "rangelength(15,15)"

local set_imei_btn = ss:option(Button, "set_imei", translate("设置IMEI"))
set_imei_btn.inputtitle = translate("应用")
set_imei_btn.inputstyle = "apply"
-- set_imei_btn:depends("imei", cur_imei)

local hex_to_bits = {
    ["0"] = "0000",
    ["1"] = "0001",
    ["2"] = "0010",
    ["3"] = "0011",
    ["4"] = "0100",
    ["5"] = "0101",
    ["6"] = "0110",
    ["7"] = "0111",
    ["8"] = "1000",
    ["9"] = "1001",
    ["a"] = "1010",
    ["b"] = "1011",
    ["c"] = "1100",
    ["d"] = "1101",
    ["e"] = "1110",
    ["f"] = "1111"
}

local bits_to_hex = {}
for k, v in pairs(hex_to_bits) do
    bits_to_hex[v] = k:upper()
end

local function hex_bitwise_op(a, b, op)
    local max_len = math.max(#a, #b)
    -- pad with leading zeros
    a = string.rep("0", max_len - #a) .. a:lower()
    b = string.rep("0", max_len - #b) .. b:lower()

    local result = {}
    for i = 1, max_len do
        local c_a = a:sub(i, i)
        local c_b = b:sub(i, i)
        local bits_a = hex_to_bits[c_a]
        local bits_b = hex_to_bits[c_b]
        if not bits_a or not bits_b then
            return nil, "invalid hex character"
        end
        local res_bits = ""
        for j = 1, 4 do
            local a_bit = bits_a:sub(j, j)
            local b_bit = bits_b:sub(j, j)
            local bit_result
            if op == "AND" then
                bit_result = (a_bit == "1" and b_bit == "1") and "1" or "0"
            elseif op == "OR" then
                bit_result = (a_bit == "1" or b_bit == "1") and "1" or "0"
            else
                return nil, "invalid operation"
            end
            res_bits = res_bits .. bit_result
        end
        local hex_char = bits_to_hex[res_bits]
        if not hex_char then
            return nil, "invalid resulting bits"
        end
        table.insert(result, hex_char)
    end
    -- remove leading zeros
    local result_str = table.concat(result)
    result_str = result_str:gsub("^0+", "")
    if result_str == "" then
        result_str = "0"
    end
    return result_str
end

function hex_and(a, b)
    return hex_bitwise_op(a, b, "AND")
end

function hex_or(a, b)
    return hex_bitwise_op(a, b, "OR")
end

local json_data
if ctl_device then
    local out = sys.exec("/lib/me909s.sh query_modem_config " .. ctl_device)
    if out and #out > 1 then
        json_data = json.parse(out)
    end
end

ss = m:section(SimpleSection, "网络设置", "BAND设置后如断网，请重启接口")
function ss.parse(self, section, novld)
end

local mode = ss:option(ListValue, "mode", translate("网络模式"))
mode:value("030201", translate("preferLTE"))
mode:value("0201", translate("preferUMTS"))
mode:value("03", translate("LTE"))
mode:value("02", translate("UMTS"))
mode:value("01", translate("GSM"))
mode:value("00", translate("AUTO"))
mode.default = "00"
if json_data and json_data.mode then
    mode.default = json_data.mode
end

local roam = ss:option(ListValue, "roam", translate("漫游"))
roam:value("1", translate("支持"))
roam:value("0", translate("不支持"))
roam.widget = "radio"
roam.default = "0"
if json_data and json_data.roam then
    roam.default = json_data.roam
end

local gms_umts_bands = {
    order = {"GSM DCS 1800", "EGSM 900", "PGSM 900", "Band 1", "Band 8"},
    data = {
        ["GSM DCS 1800"] = "80",
        ["EGSM 900"] = "100",
        ["PGSM 900"] = "200",
        ["Band 1"] = "400000",
        ["Band 8"] = "2000000000000"
    }
}

local gms_umts_band = ss:option(MultiValue, "gms_umts_band", translate("GMS/UMTS频段"))
for _, key in ipairs(gms_umts_bands.order) do
    gms_umts_band:value(gms_umts_bands.data[key], key)
end
if json_data and json_data.gms_umts_band then
    local default_bands = {}
    for _, band in pairs(gms_umts_bands.data) do
        local and_ret = hex_and(band, json_data.gms_umts_band)
        if and_ret and and_ret ~= "0" then
            table.insert(default_bands, band)
        end
    end
    gms_umts_band.default = default_bands
end

local lte_bands = {
    order = {"FDD1", "FDD3", "FDD5", "FDD8", "TDD34", "TDD38", "TDD39", "TDD40", "TDD41"},
    data = {
        ["FDD1"] = "1",
        ["FDD3"] = "4",
        ["FDD5"] = "10",
        ["FDD8"] = "80",
        ["TDD34"] = "200000000",
        ["TDD38"] = "2000000000",
        ["TDD39"] = "4000000000",
        ["TDD40"] = "8000000000",
        ["TDD41"] = "10000000000"
    }
}
local lte_band = ss:option(MultiValue, "lte_band", translate("LET频段"))
for _, key in ipairs(lte_bands.order) do
    lte_band:value(lte_bands.data[key], key)
end

if json_data and json_data.lte_band then
    local default_bands = {}
    for _, band in pairs(lte_bands.data) do
        local and_ret = hex_and(band, json_data.lte_band)
        if and_ret and and_ret ~= "0" then
            table.insert(default_bands, band)
        end
    end
    lte_band.default = default_bands
end

local set_band_btn = ss:option(Button, "set_band", translate("设置BAND"))
set_band_btn.inputtitle = translate("应用")
set_band_btn.inputstyle = "apply"

ss = m:section(SimpleSection, "重启", "采用断电重启方式")
function ss.parse(self, section, novld)
end

local set_band_btn = ss:option(Button, "restart")
set_band_btn.inputtitle = translate("执行重启")
set_band_btn.inputstyle = "apply"

function checkIMEI(imei)
    if not imei or not imei:match("^%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d$") then
        return "IMEI必须是15位数字"
    end
    local sum = 0
    for i = 1, 14 do
        local num = tonumber(imei:sub(i, i))
        if i % 2 == 0 then
            local doubled = num * 2
            sum = sum + math.floor(doubled / 10) + (doubled % 10)
        else
            sum = sum + num
        end
    end
    local checksum = (10 - (sum % 10)) % 10
    if checksum ~= tonumber(imei:sub(15, 15)) then
        return "IMEI校验位应为" .. checksum
    end
end

function m.on_save(map)
    if luci.http.formvalue("cbid.me909s.1.set_imei") then
        local new_imei = luci.http.formvalue("cbid.me909s.1.imei")
        local checkMsg = checkIMEI(new_imei)
        if checkMsg then
            luci.http.redirect(luci.dispatcher.build_url("admin", "me909s", "advance") .. "?msg=" .. checkMsg)
            return
        end
        if cur_imei and new_imei ~= cur_imei then
            os.execute("/lib/me909s.sh mrd_imei " .. ctl_device .. " " .. new_imei .."&")
            luci.http.redirect(luci.dispatcher.build_url("admin", "me909s", "advance") .. "?msg=设置成功，重启生效")
        end
    end

    if luci.http.formvalue("cbid.me909s.1.set_band") then

        local mode = luci.http.formvalue("cbid.me909s.1.mode")
        if not mode then
            mode = "00"
        end

        local roam = luci.http.formvalue("cbid.me909s.1.roam")
        if not roam then
            roam = "0"
        end
        local hex_gms_umts_band = "0"
        local gms_umts_band = luci.http.formvalue("cbid.me909s.1.gms_umts_band")
        if gms_umts_band then
            if type(gms_umts_band) == "string" then
                hex_gms_umts_band = gms_umts_band
            else
                for _, band in ipairs(gms_umts_band) do
                    hex_gms_umts_band = hex_or(hex_gms_umts_band, band)
                end
            end
        end
        if hex_gms_umts_band == "0" then
            hex_gms_umts_band = "40000000"
        end
        local hex_lte_band = "0"
        local lte_band = luci.http.formvalue("cbid.me909s.1.lte_band")
        if lte_band then
            if type(lte_band) == "string" then
                hex_lte_band = lte_band
            else
                for _, band in ipairs(lte_band) do
                    hex_lte_band = hex_or(hex_lte_band, band)
                end
            end
        end
        if hex_lte_band == "0" then
            hex_lte_band = "40000000"
        end

        local config = string.format('"%s",%s,%s,2,%s,,', mode, hex_gms_umts_band, roam, hex_lte_band)
        local msg = '设置成功'
        local ret_code = sys.call("/lib/me909s.sh submit_modem_config " .. ctl_device .. " " .. config)
        if ret_code ~= 0 then
            msg = '设置失败'
        end
        luci.http.redirect(luci.dispatcher.build_url("admin", "me909s", "advance") .. "?msg=" .. msg)
    end

    if luci.http.formvalue("cbid.me909s.1.restart") then
        local msg = '重启成功'
        local ret_code = sys.call("/lib/me909s.sh restart_modem " .. ctl_device)
        if ret_code ~= 0 then
            msg = '重启失败'
        end
        luci.http.redirect(luci.dispatcher.build_url("admin", "me909s", "advance") .. "?msg=" .. msg)
    end
end
return m
