-- https gate service

local skynet = require "skynet"
local socket = require "skynet.socket"
local crypt = require "skynet.crypt"
local protobuf = require "protobuf"
local urllib = require "http.url"
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"
local tls = require "http.tlshelper"

local watchdog
local gateIp
local gatePort
local gateNode
local gateAddr
local certfile
local keyfile
local gates = {}

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

local function response(id, write, ...)
    local ok, err = httpd.write_response(write, ...)
    if not ok then
        -- if err == sockethelper.socket_error , that means socket closed.
        skynet.error(string.format("fd = %d, %s", id, err))
    end
end

local function new_ssl_ctx(certfile, keyfile)
    local SSLCTX_SERVER = tls.newctx()
    print(certfile, keyfile)
    SSLCTX_SERVER:set_cert(certfile, keyfile)
    return tls.newtls("server", SSLCTX_SERVER)
end

local LUA = {}
function LUA.open(conf)
    gateIp = conf.ip or "::"
    gatePort = conf.port
    watchdog = conf.watchdog
    protocol = conf.protocol
    gateNode = skynet.getenv("name")
    gateAddr = skynet.self()
    certfile = conf.certfile
    keyfile = conf.keyfile

    if not conf.isSlave then
        table.insert(gates, skynet.self())
        local id = assert(socket.listen(gateIp, gatePort))
        skynet.error(string.format("Listen https gate at %s:%s", gateIp, gatePort))

        -- slave gates
        conf.isSlave = true
        local slaveNum = conf.slaveNum or 0
        for i = 1, slaveNum, 1 do
            local slaveGate = skynet.newservice("gate_https")
            skynet.call(slaveGate, "lua", "open", conf)
            table.insert(gates, slaveGate)
        end

        socket.start(id, function(fd, addr)
            skynet.error(string.format("%s accept as %d", addr, fd))
            accept(fd, addr)
        end)
    end
    skynet.retpack()
end

function LUA.connect(fd, addr)
    socket.start(fd)

    -- init tls
    local tls_ctx = new_ssl_ctx(certfile, keyfile)
    local init = tls.init_responsefunc(fd, tls_ctx)
    local close = tls.closefunc(tls_ctx)
    local read = tls.readfunc(fd, tls_ctx)
    local write = tls.writefunc(fd, tls_ctx)
    init()

    -- limit request body size to 8192 (you can pass nil to unlimit)
    local code, url, method, header, body = httpd.read_request(read, 8192)
    if code then
        if code ~= 200 then
            response(fd, write, code)
        else
            local query
            local path, querystr = urllib.parse(url)
            if querystr then
                query = urllib.parse_query(querystr)
            end

            local linkobj = {
                gateNode = gateNode,
                gateAddr = gateAddr,
                fd = fd,
                addr = addr,
                realIp = header["x-real-ip"]
            }
            local repcode, repbody, repheader = skynet.call(watchdog, "lua", "Http", "onMessage", linkobj, path, method
                , query, header, body)
            -- fd,writefunc,code, bodyfunc, header
            response(fd, write, repcode, repbody, repheader)
        end
    else
        if url == sockethelper.socket_error then
            skynet.error("socket closed")
        else
            skynet.error(url)
        end
    end
    socket.close(fd)
    close()
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local func = LUA[cmd]
        func(...)
    end)
end)
