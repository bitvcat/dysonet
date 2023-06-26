-- lua oop
--[[
函数命名约定：
- 大写字母开头为类静态方法
    1. New  创建对象
    2. Init 类初始化
- 小写字母开头为类方法，由对象调用
- 双下划线（"__"）开头的方法为对象内置方法，外部一般不调用
]]

-- oo
oo = oo or {}
oo._objectLeak = oo._objectLeak or {} -- table 泄露检查的弱表
setmetatable(oo._objectLeak, { __mode = "k" })

local function _extend(cls, father)
    -- father
    local fatherCls = nil
    if father then
        assert(type(father) == 'string', father)

        fatherCls = _G[father]
        if fatherCls and getmetatable(cls) ~= fatherCls then
            assert(oo[father] == "class", father)
            assert(rawget(fatherCls, "__index"))
            assert(type(fatherCls) == "table", father)
        end
    end
    setmetatable(cls, fatherCls)
end

function Class(name, father)
    assert(type(name) == 'string')
    assert(oo[name] ~= "singleton", name)

    local cls = _G[name]
    if not cls then
        cls = {
            __name = name,
            __index = false,
            New = false,
        }
        _G[name] = cls
        oo[name] = "class"

        cls.__index = cls
        cls.New = function(tlt, ...)
            assert(tlt == cls)
            local o
            if table.new then
                local narr = rawget(tlt, "__narr") or 0
                local nrec = rawget(tlt, "__nrec") or 8
                o = table.new(narr, nrec)
            else
                o = {}
            end
            setmetatable(o, cls)
            o.__ctor(o, ...)
            oo._objectLeak[o] = os.time()
            return o
        end

        -- father
        _extend(cls, father)
    end
    assert(type(cls) == "table", name)
    return cls
end

function Single(name, father)
    assert(type(name) == 'string')
    assert(oo[name] ~= "class", name)

    local cls = _G[name]
    if not cls then
        cls = {
            __name = name,
            __index = false,
            Init = false
        }
        _G[name] = cls
        oo[name] = "singleton"

        cls.__index = cls
        cls.Init = function(tlt, ...)
            assert(tlt == cls)
            local func = rawget(tlt, "__init")
            func(tlt, ...)
        end

        -- father
        _extend(cls, father)
    end
    assert(type(cls) == "table", name)
    return cls
end

function Extend(name)
    local cls = _G[name]
    assert(cls, name)
    assert(type(cls) == "table", name)
    return cls
end
