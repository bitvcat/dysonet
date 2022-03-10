# dysonnet
A game server base on skynet.

## 简介
dysonet 是基于 skynet 二次封装的服务器框架，它在 skynet 的基础上增加了一些游戏常用的功能、模块。

## 特性
- [x] 面向对象
- [ ] logger
- [ ] mysql 解析
- [ ] tcp gate(使用 skynet_package 实现)
- [ ] kcp gate
- [ ] aoi
- [ ] astar 寻路
- [ ] 配置中心化

## 目录结构
dysonet 目录结构基本与 skynet 目录结构保持一致，其目录结构如下：

```
dysonet
    ├─3rd                   -- 第三方库
    ├─lualib                -- lua 库/模块
    ├─lualib-src            -- 自己实现的 lua c 库（例如：AOI，astar 等）
    ├─luaclib               -- 自己实现的 lua c 库编译输出目录（.so文件）
    ├─service               -- 基础 lua 服务
    ├─service-src           -- 基础 c 服务源码
    ├─cservice              -- 基础 c 服务编译输出目录(.so 文件)
    ├─skynet                -- skynet 框架(以 gitsubmodule 方式集成)
    └─README.MD
```

### 各目录规划
- 3rd
    1.  [lkcp](https://github.com/xiyoo0812/lkcp)
    2.  [crab 敏感词过滤](https://github.com/xjdrew/crab)
    3.  [lfs](https://github.com/keplerproject/luafilesystem)
    4.  [lua-cjson](https://github.com/mpx/lua-cjson)
    5.  [lua-profile](https://github.com/lvzixun/luaprofile)
    6.  [lua-protobuf](https://github.com/starwing/lua-protobuf)
    7.  [lua-snapshot](https://github.com/sundream/lua-snapshot)
    8.  [ltrace](https://github.com/rocaltair/ltrace)
    9.  [lua-webclient](https://github.com/dpull/lua-webclient)
    10. [lua-websocket]()
    11. [lua-zlib](https://github.com/brimworks/lua-zlib)
    12. [lua-zset](https://github.com/xjdrew/lua-zset)
    13. [skynet_package](https://github.com/cloudwu/skynet_package)

- lualib
    1. lua 标准库的扩展(string、table、math)
    2. time 时间处理
    3. timer 定时器
    4. 面向对象实现

- service
    1. gate 网关(包括 tcp、kcp、websocket、http)
    2. logger 服务