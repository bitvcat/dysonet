-- websocket gate service

local skynet = require "skynet"
local socket = require "skynet.socket"
local websocket = require "http.websocket"
local protobuf = require "protobuf"

local watchdog
local gateIp
local gatePort
local gateNode
local gateAddr
local gates = {}
local protocol

local balance = 1
local function accept(fd, addr)
    -- 负载均衡
    local gate = gates[balance]
    skynet.send(gate, "lua", "connect", fd, addr)
    balance = balance + 1
    if balance > #gates then
        balance = 1
    end
end

-- handle
local handle = {}
function handle.connect(fd)
    print("ws connect from: " .. tostring(fd))
    skynet.send(watchdog, "lua", "Client", "onConnect", fd, websocket.addrinfo(fd), gateNode, gateAddr, protocol)
end

function handle.handshake(fd, header, url)
    local addr = websocket.addrinfo(fd)
    print("ws handshake from: " .. tostring(fd), "url", url, "addr:", addr)
    print("----header-----")
    for k,v in pairs(header) do
        print(k,v)
    end
    print("--------------")
end

function handle.message(fd, msg, msg_type)
    assert(msg_type == "binary" or msg_type == "text")
    print("ws recv message: " .. tostring(msg) .. "\n")
    websocket.write(fd, msg)
    --local resp = string.rep("a", 65535+5)
    --websocket.write(fd, resp)
    -- local opname, args, session = protobuf.decode_message(msg)
    -- if #opname > 0 then
    --     skynet.send(watchdog, "lua", "Client", "onMessage", fd, opname, args, session)
    -- end
end

function handle.ping(fd)
    print("ws ping from: " .. tostring(fd) .. "\n")
end

function handle.pong(fd)
    print("ws pong from: " .. tostring(fd))
end

function handle.close(fd, code, reason)
    print("ws close from: " .. tostring(fd), code, reason)
    --print(debug.traceback())
    --skynet.send(watchdog, "lua", "Client", "onClose", fd, reason)
end

function handle.error(fd)
    print("ws error from: " .. tostring(fd))
    --websocket.close(id, code, reason)
    --skynet.send(watchdog, "lua", "Client", "onClose", fd, "wsError")
end

local LUA = {}
function LUA.open(conf)
    gateIp = conf.ip or "::"
    gatePort = conf.port
    watchdog = conf.watchdog
    protocol = conf.protocol
    gateNode = skynet.getenv("name")
    gateAddr = skynet.self()

    if not conf.isSlave then
        table.insert(gates, skynet.self())

        -- slave gates
        conf.isSlave = true
        local slaveNum = conf.slaveNum or 0
        for i = 1, slaveNum, 1 do
            local slaveGate = skynet.newservice("gate_ws")
            skynet.call(slaveGate, "lua", "open", conf)
            table.insert(gates, slaveGate)
        end

        -- listen
        local id = assert(socket.listen(gateIp, gatePort))
        skynet.error(string.format("Listen websocket gate at %s:%s protocol:%s", gateIp, gatePort, protocol))
        socket.start(id, function(fd, addr)
            skynet.error(string.format("%s accept as %d", addr, fd))
            accept(fd, addr)
        end)
    end
    skynet.retpack()
end

function LUA.connect(fd, addr)
    local ok, err = websocket.accept(fd, handle, protocol, addr)
    if not ok then
        print(err)
    end
end

function LUA.write(fd, opname, args, session)
    local data = protobuf.encode_message(opname, args, session)
    local ok, err = websocket.write(fd, data, "binary")
    if not ok then
        print(err)
    end
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local func = LUA[cmd]
        func(...)
    end)
end)
