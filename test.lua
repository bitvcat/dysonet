require("init")


local CBase = oo.class("CBase")
function CBase:__ctor(...)
    self._a = 100
end

function CBase:foo()
    print(self._a)
end

local CChild = oo.class("CChild", "CBase")
function CChild:__ctor(name, sex, level)
    oo.CBase.__ctor(self)

    self._name = name
    self._sex = sex
    self._level = level
end

local child = CChild:new("dyson", "boy", 4)
child:foo()
print(child.__type)

local SPlayerMgr = oo.single("SPlayerMgr")
function SPlayerMgr:__ctor()
    self._palyers = {}
end

local s = oo.SPlayerMgr:new()
print(table.dump(oo.SPlayerMgr.__singleton, -1))

s = nil
collectgarbage("collect")
print(table.dump(oo.SPlayerMgr.__singleton, -1))

s = oo.SPlayerMgr:new()
print(table.dump(oo.SPlayerMgr.__singleton, -1))
