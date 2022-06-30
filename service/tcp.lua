-- tcp gate service

local skynet = require "skynet"
local socket = require "skynet.socket"
local socket_proxy = require "socket_proxy"
local crypt = require "skynet.crypt"
require("util.table")

local gates = {}
local connection = {}
local clientNumber = 0
local clientMax = 1024
local watchdog
local gateIp
local gatePort
local balance = 1

local function _read(fd)
    return skynet.tostring(socket_proxy.read(fd))
end

local function _newAgent(fd, addr)
    local publicKey = crypt.randomkey()
    local agent = {
        fd = fd,
        addr = addr,
        publicKey = publicKey,
        secretKey = crypt.dhexchange(publicKey),
        encryptKey = "",
        handshake = 0
    }
    return agent
end

local handler = {}
function handler.onAccept(fd, addr)
    if clientNumber > clientMax then
        socket_proxy.close(fd)
        return
    end

    -- 负载均衡
    local gate = gates[balance]
    skynet.send(gate, "lua", "connect", fd, addr)
    balance = balance + 1
    if balance > #gates then
        balance = 1
    end
end

function handler.onConnect(fd, addr)
    socket_proxy.subscribe(fd)

    assert(not connection[fd])
    clientNumber = clientNumber + 1
    local agent = _newAgent(fd, addr)
    connection[fd] = agent
    skynet.error(string.format("%s connected as %d", addr, fd))

    -- D-H exchange
    socket_proxy.write(fd)

    -- send to watchdog
    --skynet.send(address, "lua", "client", "onconnect", fd, addr)

    skynet.timeout(0, function()
        while true do
            local ok, msg = pcall(_read, fd)
            if not ok then
                handler.onClose(fd)
                break
            end

            xpcall(handler.onMessage, skynet.error, fd, msg)
        end
    end)
end

function handler.onMessage(fd, msg)
    local agent = connection[fd]
    if not agent then
        skynet.error(string.format("Invalid agent, fd = %d", fd or -1))
        return
    end

    skynet.error("recv msg: ", fd, msg)

    -- 反序列化
    -- TODO

    -- send to watchdog
    --skynet.send(address, "lua", "client", "onmessage", fd, msg)
end

function handler.onClose(fd)
    if not connection[fd] then
        return
    end

    assert(clientNumber >= 0, clientNumber)
    clientNumber = clientNumber - 1
    connection[fd] = nil
    socket_proxy.close(fd)

    --skynet.send(address, "lua", "client", "onclose", fd)
end

--- lua 消息处理
local LUA = {}
function LUA.open(conf)
    skynet.error(table.dump(conf))
    gateIp = conf.ip or "::"
    gatePort = conf.port
    watchdog = conf.watchdog

    if not conf.isSlave then
        table.insert(gates, skynet.self())
        local id = assert(socket.listen(gateIp, gatePort))
        socket.start(id, function(fd, addr)
            skynet.error(string.format("%s accept as %d", addr, fd))
            handler.onAccept(fd, addr)
        end)

        -- slave gates
        conf.isSlave = true
        local slaveNum = conf.slaveNum or 0
        for i = 1, slaveNum, 1 do
            local slaveGate = skynet.newservice("tcp")
            skynet.call(slaveGate, "lua", "open", conf)
            table.insert(gates, slaveGate)
        end
    end
    skynet.retpack()
end

function LUA.connect(fd, addr)
    handler.onConnect(fd, addr)
end

function LUA.close(fd)
    if not connection[fd] then
        return
    end
end

function LUA.write(fd, args)
    if not connection[fd] then
        return
    end

    -- 序列化
    local msg = encode(args)
    socket_proxy.write(fd, msg)
end

-- 启动 tcp gate 服务，监听节点内部的 lua 消息
skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local func = LUA[cmd]
        func(...)
    end)
end)
