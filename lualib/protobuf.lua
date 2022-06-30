-- lua-proobuf 封装

local pb = require "pb"
local skynet = require "skynet"
require("util.table")

local protobuf = {}
function protobuf.start(conf)
    protobuf.pbfile = conf.pbfile
    protobuf.idfile = conf.idfile
    protobuf.messageType = "MsgPackage"
    protobuf.loadpb()
end

function protobuf.loadpb()
    assert(pb.loadfile(protobuf.pbfile), protobuf.pbfile)
    -- pb options
    pb.option("no_default_values")
    pb.option("encode_default_values")

    local mapping = {}
    --local fd = io.open(protobuf.idfile, "r")
    -- assert(fd, protobuf.idfile)
    -- for line in fd:lines() do
    --     local opname, opcode = string.match(line, "([%w_]+)%s+=%s+(%d+)")
    --     if opname and opcode then
    --         opcode = tonumber(opcode)
    --         mapping[opname] = opcode
    --         mapping[opcode] = opname
    --     end
    -- end
    protobuf.mapping = mapping
    protobuf.message = pb.decode(protobuf.messageType)
end

function protobuf.reload()
    pb.clear()
    protobuf.loadpb()
end

function protobuf.encode_message(opname, args)
    opname = opname or ""
    assert(type(opname) == "string", opname)
    local opcode = protobuf.mapping[opname] or 0
    if opcode == 0 then
        args = tostring(args)
    end

    local message = protobuf.message
    message.opcode = opcode
    message.args = args
    return pb.encode(protobuf.messageType, message)
end

function protobuf.decode_message(bytes)
    local message = pb.decode(protobuf.messageType, bytes)
    assert(message)
    local opcode = message.opcode or 0
    if opcode == 0 then
        return "", tostring(message.args)
    else
        local opname = protobuf.mapping[opcode]
        assert(opname, opcode)
        local args = pb.decode(opname, message.args)
        return opname, args
    end
end

return protobuf
