-- lua oop（不能热更）

-- oo
oo = oo or {}
oo._objectLeak = oo._objectLeak or {} -- table 泄露检查的弱表
setmetatable(oo._objectLeak, { __mode = "k" })

function Class(name, father)
    assert(type(name) == 'string')

    local cls = _G[name]
    if not cls then
        cls = {
            __name = name,
            __index = false,
            New = function(tlt, ...)
                assert(tlt == cls)
                local o = {} -- 优化：预定义table的大小
                setmetatable(o, cls)
                o.__ctor(o, ...)
                oo._objectLeak[o] = os.time()
                return o
            end
        }
        cls.__index = cls
        _G[name] = cls
    end

    local fatherCls = nil
    if father then
        assert(type(father) == 'string', father)

        fatherCls = _G[father]
        if fatherCls and getmetatable(cls) ~= fatherCls then
            assert(rawget(fatherCls, "__index"))
            assert(type(fatherCls) == "table", father)
        end
    end
    setmetatable(cls, fatherCls)

    assert(type(cls) == "table", name)
    return cls
end
