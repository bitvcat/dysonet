-- lua oop（不能热更）

local setmetatable = setmetatable
local getmetatable = getmetatable
local _weakMeta = {__mode = 'k'}

-- oo
oo = oo or {}

function oo.init()
    oo._objectLeak = oo._objectLeak or {} 	-- table 泄露检查的弱表
    setmetatable(oo._objectLeak, {__mode="k"})
end

function oo._class(name, father, isSingle)
    assert(type(name) == 'string')

    local cls = oo[name]
    if not cls then
        local fatherCls
        if father then
            assert(type(father) == 'string', father)
            fatherCls = oo[father]
            assert(type(fatherCls) == "table", father)

            assert(fatherCls, father)
            local singleton = rawget(fatherCls, "__singleton")
            if isSingle then
                assert(singleton, father)
            else
                assert(not singleton, father)
            end
        end

        cls = {}
        cls.__type = name
        cls.__index = cls
        if isSingle then
            rawset(cls, "__singleton", setmetatable({}, _weakMeta))
        end

        local meta = {
            __call = function(tlt, ...)
                assert(tlt == cls)

                local singleton
                if isSingle then
                    singleton = rawget(cls, "__singleton")
                    assert(singleton)
                    assert(not next(singleton))
                end

                local o = {}
                setmetatable(o, cls)
                o.__ctor(o, ...)
                oo._objectLeak[o] = os.time()
                if singleton then
                    singleton[o] = true
                end

                return o
            end,
            __index = fatherCls
        }
        cls.new = meta.__call
        meta.__call = nil
        setmetatable(cls, meta)

        -- register
        oo[name] = cls
    end

    assert(type(cls) == "table", name)
    return cls
end

--定义类
function oo.class(name, father)
    assert(type(name) == 'string')

    local prefix = string.sub(name, 1, 1)
    assert(prefix == "C")
    return oo._class(name, father)
end

function oo.single(name, father)
    assert(type(name) == 'string')

    local prefix = string.sub(name, 1, 1)
    assert(prefix == "S")
    return oo._class(name, father, true)
end

oo.init()
