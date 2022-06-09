-- lua oop（不能热更）

-- oo
oo = oo or {}
oo._objectLeak = oo._objectLeak or {} -- table 泄露检查的弱表
setmetatable(oo._objectLeak, { __mode = "k" })

function Class(name, father)
    assert(type(name) == 'string')

    local cls = _G[name]
    if not cls then
        cls = {}
        cls.__name = name
        cls.__index = cls
        cls.new = function(tlt, ...)
            assert(tlt == cls)
            local o = {} -- 优化：预定义table的大小
            setmetatable(o, cls)
            o.__ctor(o, ...)
            oo._objectLeak[o] = os.time()
            return o
        end

        if father then
            assert(type(father) == 'string', father)
            local fatherCls = _G[father]
            assert(type(fatherCls) == "table", father)
            setmetatable(cls, { __index = fatherCls })
        end
    end

    assert(type(cls) == "table", name)
    return cls
end
