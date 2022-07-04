#include <lauxlib.h>
#include <lua.h>

static int lelfhash(lua_State *L) {
    size_t sz = 0;
    const char *str = luaL_checklstring(L, 1, &sz);
    if (sz == 0) {
        return luaL_error(L, "Invalid string %s", str);
    }

    unsigned int hash = 0;
    unsigned int x = 0;
    while (*str) {
        hash = (hash << 4) + *str;
        if ((x = hash & 0xf0000000) != 0) {
            hash ^= (x >> 24); //影响5-8位，杂糅一次
            hash &= ~x;        //清空高四位
        }
        str++;
    }
    lua_pushinteger(L, hash & 0x7fffffff);
    return 1;
}

LUAMOD_API int luaopen_lutil(lua_State *L) {
    luaL_checkversion(L);
    luaL_Reg l[] = {
        {"elfhash", lelfhash},
        {NULL, NULL},
    };
    luaL_newlib(L, l);
    return 1;
}