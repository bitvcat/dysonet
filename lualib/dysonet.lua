-- 扩展skynet

-- dysonet
dysonet = dysonet or {}

-- skynet 引擎的常用模块挂载到dysonet下，方便使用
dysonet.skynet = require "skynet.manager"
dysonet.cluster = require "skynet.cluster"
dysonet.socket = require "skynet.socket"
dysonet.httpc = require "http.httpc"
dysonet.httpd = require "http.httpd"
dysonet.url = require "http.url"
dysonet.md5 = require "md5"
dysonet.crypt = require "skynet.crypt"
dysonet.mongo = require "skynet.db.mongo"
dysonet.bson = require "bson"
dysonet.cjson = require "cjson"

-- dysonet 扩展模块
dysonet.time = require "time"

-- dysonet 扩展api
function dysonet.onerror(errmsg)
	local err = string.format('%s\n%s\n[END]', errmsg or '', debug.traceback())
    if xlogger then
        xlogger.logf("ERROR", "error", err)
    end
    return err
end

function dysonet.xpcall(func, ...)
    return xpcall(func, dysonet.onerror, ...)
end

-- queue
local skynet_queue = require "skynet.queue"
dysonet.queues = dysonet.queues or {}
function dysonet.add_queue(id, func, ...)
    local queues = dysonet.queues
    local queue = queues[id]
    if not queue then
        queue = skynet_queue()
        queues[id] = queue
    end
    return queue(func, ...)
end