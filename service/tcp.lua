-- tcp gate service

local skynet = require "skynet"
local socket = require "skynet.socket"
local socket_proxy = require "socket_proxy"
local crypt = require "skynet.crypt"
local protobuf = require "protobuf"
require("util.init")

local gates = {}
local connection = {}
local clientNumber = 0
local clientMax = 1024
local watchdog
local gateIp
local gatePort
local balance = 1

local function _newAgent(fd, addr)
    local secretKey = crypt.randomkey()
    local agent = {
        fd = fd,
        addr = addr,
        secretKey = secretKey,
        publicKey = crypt.dhexchange(secretKey),
        encryptKey = "",
        handshake = 0
    }
    return agent
end

-- socket
local socket_start = socket_proxy.subscribe
local socket_read = function(fd)
    local ok, msg, sz = pcall(socket_proxy.read, fd)
    if not ok then
        return false
    end
    return true, skynet.tostring(msg, sz)
end
local socket_write = socket_proxy.write
local socket_close = function(fd, reason)
    socket_proxy.close(fd)

    if connection[fd] then
        assert(clientNumber >= 0, clientNumber)
        clientNumber = clientNumber - 1
        connection[fd] = nil
        skynet.send(watchdog, "lua", "client", "onClose", fd, reason)
    end
end

local handler = {}
function handler.onAccept(fd, addr)
    if clientNumber > clientMax then
        socket_close(fd, "maxclient")
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
    socket_start(fd)

    assert(not connection[fd])
    clientNumber = clientNumber + 1
    local agent = _newAgent(fd, addr)
    connection[fd] = agent
    skynet.error(string.format("%s connected as %d", addr, fd))

    -- D-H exchange
    local msg = protobuf.encode_message(nil, agent.publicKey)
    socket_write(fd, msg)

    -- send to watchdog
    skynet.send(watchdog, "lua", "client", "onConnect", fd, addr)

    skynet.timeout(0, function()
        while true do
            local ok, msg = socket_read(fd)
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

    if agent.handshake == 0 then
        local _, hexstr = protobuf.decode_message(msg)
        local cPublicKey, cEncryptKey = string.match(hexstr, "(.+)|(.+)")
        cPublicKey, cEncryptKey = crypt.hexdecode(cPublicKey), crypt.hexdecode(cEncryptKey)
        local sEncryptKey = crypt.dhsecret(cPublicKey, agent.secretKey)
        if cEncryptKey == sEncryptKey then
            agent.encryptKey = sEncryptKey
            agent.handshake = 1
        else
            socket_close(fd, "validation fails")
            return
        end
    else
        -- 握手成功
        local opcode, args = protobuf.decode_message(msg)
        skynet.send(watchdog, "lua", "client", "onMessage", fd, opcode, args)
    end
end

function handler.onClose(fd)
    socket_close(fd, "client closed")
end

--- lua 消息处理
local LUA = {}
function LUA.open(conf)
    gateIp = conf.ip or "::"
    gatePort = conf.port
    watchdog = conf.watchdog
    protobuf.start({ pbfile = "assets/proto/all.pb" })

    if not conf.isSlave then
        table.insert(gates, skynet.self())
        local id = assert(socket.listen(gateIp, gatePort))
        skynet.error("Start tcp gate listen at " .. gateIp .. ":" .. gatePort)

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
    socket_close(fd, "shutdown")
end

function LUA.write(fd, opname, args)
    if not connection[fd] then
        return
    end

    -- 序列化
    local msg = protobuf.encode_message(opname, args)
    socket_write(fd, msg)
end

-- 启动 tcp gate 服务，监听节点内部的 lua 消息
skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local func = LUA[cmd]
        func(...)
    end)
end)
