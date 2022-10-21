--[[!
    @file
    @brief logger 日志管理模块源文件。
    @details 管理运行时日志。
    @details 管理玩法日志，负载均衡的将日志通过 xlogger 服务写入到文件中。
]]

local skynet = require "skynet"
require "skynet.manager"
local lutil = require "lutil"

-- 颜色代码
local COLOR = { --- 颜色定义
    BLACK   = "#30",
    RED     = "#31",
    GREEN   = "#32",
    YELLOW  = "#33",
    BLUE    = "#34",
    FUCHSIN = "#35", -- 品红
    CYAN    = "#36", -- 青色 蓝绿色
}

--! @class logger
--! @brief 日志管理模块
--! @package logger
logger = logger or {}

--level define
logger.DEBUG = 1   --- 调试
logger.INFO = 2    --- 信息
logger.WARN = 3    --- 警告
logger.ERROR = 4   --- 普通错误
logger.FATAL = 5   --- 致命错误

--- @brief 日志模块初始化
--- @details 注册<tt>text</tt>类型的消息处理，并启动 num 个 xlogger C服务。
--- @param string levelname 限制日志等级
--- @param integer num xlogger 服务数量
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

--- @brief 根据日志文件名获取对应的服务地址
--- @details 使用 elfhash 算法获取 filename 的哈希值。
--- @param string filename 日志文件名
--- @return 日志服务地址
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

--- @brief 格式化日志消息并写入到文件中
--- @param string levelname 指定日志等级
--- @param string filename 日志文件名
--- @param string fmt 日志消息格式化串
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

--- @brief 打印运行时日志，支持打印 table
--- @param vars ... 要打印的值列表
function logger.print(...)
    local t = { ... }
    for i, value in ipairs(t) do
        t[i] = type(value) == "table" and table.dump(value) or value
    end
    local info = debug.getinfo(2)
    local prefix = (info.source or "?") .. ":" .. info.currentline
    skynet.error("[logger.print]", prefix, table.concat(t,"\n"))
end

--- @brief 带颜色的运行时日志打印，支持打印 table
--- @param string colorname 指定颜色名称
--- @param vars ... 日志文件名
function logger.color(colorname, ...)
    local t = { ... }
    for i, value in ipairs(t) do
        t[i] = type(value) == "table" and table.dump(value) or value
    end
    local info = debug.getinfo(2)
    local prefix = (info.source or "?") .. ":" .. info.currentline
    skynet.error(COLOR[colorname] or "", "[logger.color]", prefix, table.unpack(t))
end
