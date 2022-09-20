-- http gate service

local skynet = require "skynet"
local socket = require "skynet.socket"
local urllib = require "http.url"
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"

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

local function response(id, write, ...)
    local ok, err = httpd.write_response(write, ...)
    if not ok then
        -- if err == sockethelper.socket_error , that means socket closed.
        skynet.error(string.format("fd = %d, %s", id, err))
    end
end

local SSLCTX_SERVER = nil
local function gen_interface(fd)
    if protocol == "http" then
        return {
            init = nil,
            close = nil,
            read = sockethelper.readfunc(fd),
            write = sockethelper.writefunc(fd),
        }
    elseif protocol == "https" then
        local tls = require "http.tlshelper"
        if not SSLCTX_SERVER then
            SSLCTX_SERVER = tls.newctx()
            -- gen cert and key
            -- openssl req -x509 -newkey rsa:2048 -days 3650 -nodes -keyout server-key.pem -out server-cert.pem
            local certfile = skynet.getenv("certfile") or "./server-cert.pem"
            local keyfile = skynet.getenv("keyfile") or "./server-key.pem"
            print(certfile, keyfile)
            SSLCTX_SERVER:set_cert(certfile, keyfile)
        end
        local tls_ctx = tls.newtls("server", SSLCTX_SERVER)
        return {
            init = tls.init_responsefunc(fd, tls_ctx),
            close = tls.closefunc(tls_ctx),
            read = tls.readfunc(fd, tls_ctx),
            write = tls.writefunc(fd, tls_ctx),
        }
    else
        error(string.format("Invalid protocol: %s", protocol))
    end
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
            local slaveGate = skynet.newservice("gate_http")
            skynet.call(slaveGate, "lua", "open", conf)
            table.insert(gates, slaveGate)
        end

        -- listen
        local id = assert(socket.listen(gateIp, gatePort))
        skynet.error(string.format("Listen http gate at %s:%s protocol:%s", gateIp, gatePort, protocol))
        socket.start(id, function(fd, addr)
            skynet.error(string.format("%s accept as %d", addr, fd))
            accept(fd, addr)
        end)
    end
    skynet.retpack()
end

function LUA.connect(fd, addr)
    socket.start(fd)
    local interface = gen_interface(fd)
    if interface.init then
        interface.init()
    end
    -- limit request body size to 8192 (you can pass nil to unlimit)
    local code, url, method, header, body = httpd.read_request(interface.read, 8192)
    if code then
        if code ~= 200 then
            response(fd, interface.write, code)
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
                realIp = header["x-real-ip"] -- for nginx
            }
            local repcode, repbody, repheader = skynet.call(watchdog, "lua", "Http", "onMessage", linkobj, path, method
                , query, header, body)
            -- fd,writefunc,code, bodyfunc, header
            response(fd, interface.write, repcode, repbody, repheader)
        end
    else
        if url == sockethelper.socket_error then
            skynet.error("socket closed")
        else
            skynet.error(url)
        end
    end
    socket.close(fd)
    if interface.close then
        interface.close()
    end
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local func = LUA[cmd]
        func(...)
    end)
end)
