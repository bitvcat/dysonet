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

static void _deepcopy(lua_State *L, int from) {
    lua_checkstack(L, 5);
    if (!lua_istable(L, from)) {
        lua_pushvalue(L, from);
        return;
    } else {
        lua_pushvalue(L, from);
        lua_gettable(L, 2);
        if (lua_type(L, -1) == LUA_TNIL) {
            lua_pop(L, 1); // pop nil
        } else {
            return;
        }
    }

    // create dst table
    lua_newtable(L);
    int to = lua_gettop(L);

    // set metatable
    if (lua_getmetatable(L, from)) {
        lua_setmetatable(L, to);
    }

    // set lookup
    lua_pushvalue(L, from); // key(src table)
    lua_pushvalue(L, -2);   // value(dst table)
    lua_settable(L, 2);     // lookup[key] = value

    // loop src table
    int key_index;
    int value_index;
    lua_pushnil(L);
    while (lua_next(L, from) != 0) {
        value_index = lua_gettop(L);
        key_index = value_index - 1;

        _deepcopy(L, key_index);
        _deepcopy(L, value_index);
        lua_rawset(L, to);
        lua_pop(L, 1);
    }
}

static int ltable_deepcopy(lua_State *L) {
    lua_newtable(L);
    _deepcopy(L, 1);
    return 1;
}

static int ltable_new(lua_State *L) {
    int narr = luaL_optinteger(L, 1, 0);
    int nrec = luaL_optinteger(L, 2, 8);
    lua_createtable(L, narr, nrec);
    return 1;
}

LUAMOD_API int luaopen_lutil(lua_State *L) {
    luaL_checkversion(L);
    luaL_Reg l[] = {
        {"elfhash", lelfhash},
        {"table_deepcopy", ltable_deepcopy},
        {"table_new", ltable_new},
        {NULL, NULL},
    };
    luaL_newlib(L, l);
    return 1;
}