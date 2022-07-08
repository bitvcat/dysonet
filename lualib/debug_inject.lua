-- debug_console 注入
local source = [[
local function getupvaluetable(u, func, unique)
    unique = unique or {}
    local i = 1
    while true do
        local name, value = debug.getupvalue(func, i)
        if name == nil then
            return
        end
        local t = type(value)
        if t == "table" then
            u[name] = value
        elseif t == "function" then
            if not unique[value] then
                unique[value] = true
                getupvaluetable(u, value, unique)
            end
        end
        i=i+1
    end
end
local skynet = require "skynet"
local TIMEOUT = 300 -- 3 sec
local function timeout(ti)
    if ti then
        ti = tonumber(ti)
        if ti <= 0 then
            ti = nil
        end
    else
        ti = TIMEOUT
    end
    return ti
end
local function adjust_address(address)
	local prefix = address:sub(1, 1)
	if prefix == '.' then
		return assert(skynet.localname(address), "Not a valid name")
	elseif prefix ~= ':' then
		address = assert(tonumber("0x" .. address), "Need an address") | (skynet.harbor(skynet.self()) << 24)
	end
	return address
end
local function stat(ti)
    local statlist = skynet.call(".launcher", "lua", "STAT", timeout(ti))
    local memlist = skynet.call(".launcher", "lua", "MEM", timeout(ti))
    for k,v in pairs(statlist) do
        v.xmem=memlist[k]
    end
    return statlist
end
local function echo(cmd)
    local address = adjust_address(cmd[2])
    local codestr = assert(cmd[1]:match("%S+%s+%S+%s(.+)") , "need arguments")
    local luacode, deepth = string.match(codestr, "(.+)%s+(%d+)%c$")
    if not deepth then
        luacode = codestr
    else
        deepth = tonumber(deepth)
    end
    return skynet.call(address, "debug", "PRINT", luacode, deepth)
end
local function exec(cmd)
    local address = adjust_address(cmd[2])
    local luacode = assert(cmd[1]:match("%S+%s+%S+%s(.+)") , "need arguments")
    return skynet.call(address, "debug", "EXEC", luacode)
end

local socket = require "skynet.socket"
local u1 = {}
getupvaluetable(u1, _P.socket.socket_message[1])
for k,v in pairs(u1.socket_pool) do
    if v.callback then
        local u2 = {}
        getupvaluetable(u2, v.callback)
        if u2.COMMAND then
            u2.COMMAND.stat = stat
        end
        if u2.COMMANDX then
            u2.COMMANDX.print = echo
            u2.COMMANDX.exec = exec
        end
    end
end
]]

local skynet = require "skynet"
local skynet_debug = require "skynet.debug"
skynet_debug.reg_debugcmd("PRINT", function(luacode, deepth)
    skynet.error(string.format("[PRINT]Lua code string: %s", luacode))
    local errmsg
    local ok, result = xpcall(
        function() return { load("return " .. luacode)() } end,
        function(e) errmsg = tostring(e) .. "\n" .. debug.traceback() end
    )
    if ok then
        if table.dump then
            skynet.retpack(tostring(table.dump(result, deepth)))
        else
            skynet.retpack(tostring(result))
        end
    else
        skynet.retpack(errmsg)
    end
end)

skynet_debug.reg_debugcmd("EXEC", function(luacode, deepth)
    skynet.error(string.format("[EXEC]Lua code string: %s", luacode))
    local errmsg
    local ok, result = xpcall(
        function() return load(luacode)() end,
        function(e) errmsg = tostring(e) .. "\n" .. debug.traceback() end
    )
    if ok then
        if table.dump then
            skynet.retpack(tostring(table.dump(result, deepth)))
        else
            skynet.retpack(tostring(result))
        end
    else
        skynet.retpack(errmsg)
    end
end)

return function(address)
    skynet.call(address, "debug", "RUN", source)
end
