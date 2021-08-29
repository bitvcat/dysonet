root = "./"
debug_port = 2001

thread = 8
logpath = "."
harbor = 0
start = "main"
bootstrap = "snlua bootstrap"
lualoader = root.."../skynet/lualib/loader.lua"

cpath = root.."../skynet/cservice/?.so;"
      ..root.."../cservice/?.so;"
luaservice = root.."../skynet/service/?.lua;"
           ..root.."../service/?.lua;"
           ..root.."/?.lua"
lua_cpath = root.."../skynet/luaclib/?.so;"
          ..root.."../luaclib/?.so;"
lua_path = root.."../skynet/lualib/?.lua;"
         ..root.."../skynet/lualib/compat10/?.lua;"
         ..root.."../skynet/lualib/?/init.lua;"
         ..root.."../lualib/?/init.lua;"
         ..root.."../lualib/?.lua;"

-- 日志输出路径
--logger = "log/skynet.log"

-- cluster
-- ..