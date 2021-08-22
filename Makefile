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

$(LUALIB_PATH)/socket_proxy.lua: 3rd/skynet_package/lualib/socket_proxy.lua
	cp $^ $@

$(SERVICE_PATH)/socket_proxyd.lua: 3rd/skynet_package/service/socket_proxyd.lua
	cp $^ $@

all: $(CSERVICE_PATH) $(CSERVICE_PATH)/package.so

.PHONY: all