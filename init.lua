--[[readme
引擎层提供的全局table:
- dysonet 扩展了skynet
- logger 日志功能
]]

-- 以下是dysonet 引擎必定会加载的模块
require("util.init")
require("class")
require("logger")
require("dysonet")
