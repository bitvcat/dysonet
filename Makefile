# dyson net makefile

CC ?= gcc

SKYNET_PATH ?= ./skynet
LUALIB_PATH ?= lualib
LUACLIB_PATH ?= luaclib
SERVICE_PATH ?= service
CSERVICE_PATH ?= cservice

LUA_INC ?= $(SKYNET_PATH)/3rd/lua
LUA_LIB ?= $(SKYNET_PATH)/3rd/lua/liblua.a

# gcc 编译参数
# -g 编译产生调试信息
# -O2 优化等级，参考：https://www.zhihu.com/question/27090458
# -Wall 生成所有警告信息
CFLAGS = -g -O2 -Wall -I$(LUA_INC)
SHARED = -fPIC --shared

# 创建目标对应的文件夹
$(LUALIB_PATH):
	mkdir -p $(LUALIB_PATH)

$(LUACLIB_PATH):
	mkdir -p $(LUACLIB_PATH)

$(SERVICE_PATH):
	mkdir -p $(SERVICE_PATH)

$(CSERVICE_PATH):
	mkdir -p $(CSERVICE_PATH)


# skynet_package
$(CSERVICE_PATH)/package.so : 3rd/skynet_package/service_package.c
	echo aa=$^,b=$@
	$(CC) $(CFLAGS) $(SHARED) -o $@ $^ -I$(SKYNET_PATH)/skynet-src

# xlogger
$(CSERVICE_PATH)/xlogger.so : service-src/service_xlogger.c
	$(CC) $(CFLAGS) $(SHARED) -o $@ $^ -I$(SKYNET_PATH)/skynet-src

# slogger
$(CSERVICE_PATH)/slogger.so : service-src/service_slogger.c
	$(CC) $(CFLAGS) $(SHARED) -o $@ $^ -I$(SKYNET_PATH)/skynet-src

$(LUALIB_PATH)/socket_proxy.lua: 3rd/skynet_package/lualib/socket_proxy.lua
	echo "copy $^ to $@ ..."
	cp $^ $@

$(SERVICE_PATH)/socket_proxyd.lua: 3rd/skynet_package/service/socket_proxyd.lua
	echo "copy $^ to $@ ..."
	cp $^ $@

# lua-protobuf
$(LUACLIB_PATH)/pb.so: 3rd/lua-protobuf/pb.c
	echo "lua-protobuf $@ $^"
	$(CC) $(CFLAGS) $(SHARED) -o $@ $^

# lutil
$(LUACLIB_PATH)/lutil.so: lualib-src/lutil.c
	$(CC) $(CFLAGS) $(SHARED) -o $@ $^

# lfs
$(LUACLIB_PATH)/lfs.so: 3rd/lfs/src/lfs.c
	$(CC) $(CFLAGS) $(SHARED) -o $@ $^

# lua-cjson
$(LUACLIB_PATH)/cjson.so: 3rd/lua-cjson/lua_cjson.c 3rd/lua-cjson/strbuf.c 3rd/lua-cjson/fpconv.c
	echo "lua-cjson $@ $^"
	$(CC) $(CFLAGS) $(SHARED) -o $@ $^

LUALIB = socket_proxy.lua
LUACLIB = pb.so lutil.so cjson.so
SERVICE = socket_proxyd.lua
CSERVICE = package.so xlogger.so slogger.so

all: $(LUALIB_PATH) $(LUACLIB_PATH) $(SERVICE_PATH)  $(CSERVICE_PATH) \
	$(foreach v,$(LUALIB),$(LUALIB_PATH)/$(v)) \
	$(foreach v,$(LUACLIB),$(LUACLIB_PATH)/$(v)) \
	$(foreach v,$(SERVICE),$(SERVICE_PATH)/$(v)) \
	$(foreach v,$(CSERVICE),$(CSERVICE_PATH)/$(v))

.PHONY: all