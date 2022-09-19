local skynet = require "skynet"
require "skynet.manager"
local lutil = require "lutil"

-- 颜色代码
local COLOR = {
    BLACK   = "#30",
    RED     = "#31",
    GREEN   = "#32",
    YELLOW  = "#33",
    BLUE    = "#34",
    FUCHSIN = "#35", -- 品红
    CYAN    = "#36", -- 青色 蓝绿色
}

-- logger
logger = logger or {}

--level define
logger.DEBUG = 1   -- 调试
logger.INFO = 2    -- 信息
logger.WARN = 3    -- 警告
logger.ERROR = 4   -- 普通错误
logger.FATAL = 5   -- 致命错误

function logger.init(levelname, num)
    logger.wraps = {
        DEBUG = "[DEBUG]",
        INFO = "[INFO]",
        WARN = "[WARN]",
        ERROR = "[ERROR]",
        FATAL = "[FATAL]",
    }
    logger.level = logger[levelname] or logger.INFO

    skynet.register_protocol {
        name = "text",
        id = skynet.PTYPE_TEXT,
        pack = function(text) return text end,
        unpack = function(buf, sz) return skynet.tostring(buf, sz) end,
    }
    if not logger.addresses then
        logger.msgtable = { "", "", ""}
        logger.addresses = {}
        num = num or 4
        local logpath = skynet.getenv("logpath") or "log"
        for i = 1, num, 1 do
            local addr = assert(skynet.launch("xlogger", logpath))
            logger.addresses[i] = addr
        end
    end
end

function logger.getAddr(filename)
    assert(#filename > 0)
    assert(#logger.addresses > 0)
    local hashkey = lutil.elfhash(filename)
    local index = (hashkey % #logger.addresses) + 1
    return logger.addresses[index]
end

function logger.format(fmt, ...)
    local msg
    if select("#", ...) == 0 then
        msg = fmt
    else
        msg = string.format(fmt, ...)
    end
    return msg
end

function logger.logf(levelname, filename, fmt, ...)
    if logger[levelname] < logger.level then
        return
    end

    local msgtable = logger.msgtable
    local addr = logger.getAddr(filename)
    msgtable[1] = filename
    msgtable[2] = logger.wraps[levelname] or levelname
    msgtable[3] = logger.format(fmt, ...)
    skynet.send(addr, "text", table.concat(msgtable, " "))
end

function logger.print(...)
    local t = { ... }
    for i, value in ipairs(t) do
        t[i] = type(value) == "table" and table.dump(value) or value
    end
    local info = debug.getinfo(2)
    local prefix = (info.source or "?") .. ":" .. info.currentline
    skynet.error("[logger.print]", prefix, table.unpack(t))
end

function logger.color(colorname, ...)
    local t = { ... }
    for i, value in ipairs(t) do
        t[i] = type(value) == "table" and table.dump(value) or value
    end
    local info = debug.getinfo(2)
    local prefix = (info.source or "?") .. ":" .. info.currentline
    skynet.error(COLOR[colorname] or "", "[logger.color]", prefix, table.unpack(t))
end
