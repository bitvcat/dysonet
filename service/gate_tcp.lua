-- tcp gate service

local skynet = require "skynet"
local socket = require "skynet.socket"
local socket_proxy = require "socket_proxy"
local crypt = require "skynet.crypt"
local protobuf = require "protobuf"

local gates = {}
local connection = {}
local clientNumber = 0
local clientMax = 1024
local watchdog
local gateIp
local gatePort
local balance = 1
local gateNode
local gateAddr
local protocol

local function _newAgent(fd, addr)
    local secretKey = crypt.randomkey()
    local agent = {
        fd = fd,
        addr = addr,
        randomCode = crypt.hexencode(crypt.randomkey()),
        secretKey = secretKey,
        publicKey = crypt.dhexchange(secretKey),
        encryptKey = "",
        handshake = 0
    }
    return agent
end

--- socket
local socket_start = socket_proxy.subscribe
local socket_read = function(fd)
    local ok, msg, sz = pcall(socket_proxy.read, fd)
    if not ok then
        return false
    end
    return true, skynet.tostring(msg, sz)
end
local socket_write = socket_proxy.write
local socket_close = function(fd)
    socket_proxy.close(fd)

    if connection[fd] then
        assert(clientNumber >= 0, clientNumber)
        clientNumber = clientNumber - 1
        connection[fd] = nil
    end
end

--- handler
local handler = {}
function handler.onAccept(fd, addr)
    if clientNumber > clientMax then
        handler.onClose(fd, "maxClient")
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

    -- send to watchdog
    skynet.send(watchdog, "lua", "Client", "onConnect", fd, addr, gateNode, gateAddr, protocol)

    skynet.timeout(0, function()
        while true do
            local ok, msg = socket_read(fd)
            if not ok then
                handler.onClose(fd, "clientClose")
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
        local _, hellostr = protobuf.decode_message(msg)
        assert(hellostr == "client hello", hellostr)

         -- D-H exchange
        local hexstr = agent.randomCode .. "|" .. crypt.hexencode(agent.publicKey)
        local msg = protobuf.encode_message(nil, hexstr)
        socket_write(fd, msg)
        agent.handshake = 1
    elseif agent.handshake == 1 then
        local _, hexstr = protobuf.decode_message(msg)
        local randomHex, cPublicHex = string.match(hexstr, "(.+)|(.+)")
        local randomDes, cPublicKey = crypt.hexdecode(randomHex), crypt.hexdecode(cPublicHex)
        local encryptKey = crypt.dhsecret(cPublicKey, agent.secretKey)
        if agent.randomCode == crypt.desdecode(encryptKey, randomDes) then
            agent.encryptKey = encryptKey
            agent.handshake = 2

            local msg = protobuf.encode_message(nil, "server done")
            socket_write(fd, msg)
        else
            handler.onClose(fd, "validationFail")
            return
        end
    elseif agent.handshake == 2 then
        local opname, args, session = protobuf.decode_message(msg)
        if #opname > 0 then
            skynet.send(watchdog, "lua", "Client", "onMessage", fd, opname, args, session)
        end
    else
        handler.onClose(fd, "unauthLink")
    end
end

function handler.onClose(fd, reason)
    socket_close(fd)
    skynet.send(watchdog, "lua", "Client", "onClose", fd, reason)
end

--- lua 消息处理
local LUA = {}
function LUA.open(conf)
    gateIp = conf.ip or "::"
    gatePort = conf.port
    watchdog = conf.watchdog
    gateNode = skynet.getenv("name")
    gateAddr = skynet.self()
    protocol = conf.protocol
    protobuf.start({ pbfile = "assets/proto/all.pb" })

    if not conf.isSlave then
        table.insert(gates, skynet.self())

        -- slave gates
        conf.isSlave = true
        local slaveNum = conf.slaveNum or 0
        for i = 1, slaveNum, 1 do
            local slaveGate = skynet.newservice("gate_tcp")
            skynet.call(slaveGate, "lua", "open", conf)
            table.insert(gates, slaveGate)
        end

        -- listen
        local id = assert(socket.listen(gateIp, gatePort))
        skynet.error(string.format("Listen tcp gate at %s:%s", gateIp, gatePort))
        socket.start(id, function(fd, addr)
            skynet.error(string.format("%s accept as %d", addr, fd))
            handler.onAccept(fd, addr)
        end)
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
    socket_close(fd)
end

function LUA.write(fd, opname, args, session)
    if not connection[fd] then
        return
    end

    -- 序列化
    local msg = protobuf.encode_message(opname, args, session)
    socket_write(fd, msg)
end

-- 启动 tcp gate 服务，监听节点内部的 lua 消息
skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local func = LUA[cmd]
        func(...)
    end)
end)
