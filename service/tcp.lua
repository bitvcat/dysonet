-- tcp gate service

local skynet = require "skynet"
local socket = require "skynet.socket"
local socket_proxy = require "socket_proxy"

require("util")

local connection = {}
local client_number = 0
local client_max = 1024

local function read(fd)
    return skynet.tostring(socket_proxy.read(fd))
end

local handler = {}
function handler.onconnect(fd, addr)
    if client_number >= client_max then
        socket_proxy.close(fd)
        return
    end

    assert(not connection[fd])
    local agent = {
        fd = fd,
        addr = addr
    }
    connection[fd] = agent
    skynet.error(string.format("%s connected as %d", addr, fd))

    -- send to watchdog
    --skynet.send(address, "lua", "client", "onconnect", fd, addr)
end

function handler.onmessage(fd, msg)
    local agent = connection[fd]
    if not agent then
        skynet.error(string.format("Invalid agent, fd = %d", fd or -1))
        return
    end

    skynet.error("recv msg: ", fd, msg)
    -- send to watchdog
    --skynet.send(address, "lua", "client", "onmessage", fd, msg)
end

function handler.onclose(fd)
    if not connection[fd] then
        return
    end

    assert(client_number >= 0, client_number)
    client_number = client_number - 1
    connection[fd] = nil

    --skynet.send(address, "lua", "client", "onclose", fd)
end

local CMD = {}
function CMD.open(conf)
    skynet.error(table.dump(conf))
    local id = assert(socket.listen("127.0.0.1", 8888))
    socket.start(id, function (fd, addr)
        skynet.error(string.format("%s connected as %d" , addr, fd))
        socket_proxy.subscribe(fd)
        handler.onconnect(fd, addr)

        if connection[fd] then
            while true do
                local ok, msg = pcall(read, fd)
                if not ok then
                    handler.onclose(fd)
                    break
                end

                xpcall(handler.onmessage, skynet.error, fd, msg)
            end
        end
    end)

    skynet.retpack()
end

-- 启动 tcp gate 服务，监听节点内部的 lua 消息
skynet.start(function ()
    skynet.dispatch("lua",function (session, source, cmd, ...)
        local func = CMD[cmd]
        func(...)
    end)
end
)