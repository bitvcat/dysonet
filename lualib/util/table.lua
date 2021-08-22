-- table 扩展

-- table.dump
local _eqStr = " = "
local _bktL = "{"
local _bktR = "}"
local _tbShort = "{ ... }"
local _tbEmpty = "{ }"
local _indent = "    "

local function _EscapeKey(key)
    if type(key) == "string" then
        key ='\"' .. tostring(key) .. '\"'
    else
        key = tostring(key)
    end

    local brackets = "["..key.."]"
    return key, brackets
end

local function _Comma(isLast)
    return isLast and "" or ","
end

local function _BktR(isLast)
    return _bktR .. _Comma(isLast)
end

local function _Space(space, key, isLast, noAlignLine)
    local indent
    if noAlignLine or isLast then
        indent = space .. _indent
    else
        indent = space .. "|" .. string.rep(" ", 3)
    end
    return indent
end

local function _EmptyTable(isLast)
    return _tbEmpty .. _Comma(isLast)
end

local function _Concat(...)
    return table.concat({...}, "")
end

-- 树型dump一个 table,不用担心循环引用
-- depthMax 打印层数控制，默认3层（-1表示无视层数）
-- excludeKey 排除打印的key
-- excludeType 排除打印的值类型
-- noAlignLine 不打印对齐线
table.dump = function(root, depthMax, excludeKey, excludeType, noAlignLine)
    if type(root) ~= "table" then
        return root
    end

    depthMax = depthMax or 3 -- 默认三层
    local cache = { [root] = "." }
    local depth = 0
    local temp = {"{"}
    local function _dump(t, space, name)
        for k,v in pairs(t) do
            local ok, isLast = pcall(function() return not next(t, k) end) --最后一个字段
			isLast = ok and isLast
            local key, keyBkt = _EscapeKey(k)

            if type(v) == "table" then
                if cache[v] then
                    table.insert(temp, _Concat(space, keyBkt, _eqStr, _bktL, cache[v], _BktR(isLast)))
                else
                    local new_key = name .. "." .. tostring(k)
                    cache[v] = new_key .. " ->[".. tostring(v) .."]"

                    -- table 深度判断
                    depth = depth + 1
                    if (depthMax > 0 and depth >= depthMax) or (excludeKey and excludeKey==k) then
                        table.insert(temp, _Concat(space, keyBkt, _eqStr, _tbShort, _Comma(isLast)))
                    else
                        if next(v) then
                            -- 非空table
                            table.insert(temp, _Concat(space, keyBkt, _eqStr, _bktL))
                            _dump(v, _Space(space, key, isLast, noAlignLine), new_key)
                            table.insert(temp, _Concat(space, _BktR(isLast)))
                        else
                            table.insert(temp, _Concat(space, keyBkt, _eqStr, _EmptyTable(isLast)))
                        end
                    end
                    depth = depth -1
                end
            else
                local vType = type(v)
                if not excludeType or excludeType ~= vType then
                    if vType == "string" then
                        v = '\"' .. v .. '\"'
                    else
                        v = tostring(v) or "nil"
                    end
                    table.insert(temp, _Concat(space, keyBkt, _eqStr, v, _Comma(isLast)))
                end
            end
        end

        --return #temp>0 and table.concat(temp,"\n") or nil
    end
    _dump(root, _indent, "")
    table.insert(temp, "}")

    return table.concat(temp, "\n")
end

-- table 深拷贝
table.deepcopy = function(object)
	local lookup_table = nil
	local function _copy(object)
		if type(object) ~= "table" then
			return object
		elseif lookup_table and lookup_table[object] then
			return lookup_table[object]
		end

		local new_table = {}
		--if not lookup_table then lookup_table = {} end
		lookup_table = lookup_table or {}
		lookup_table[object] = new_table --table的副本
		for key, value in pairs(object) do
			new_table[_copy(key)] = _copy(value)
		end
		return setmetatable(new_table, getmetatable(object))
	end
	return _copy(object)
end

-- 从表中查找符合条件的元素
table.find = function(tbl, func)
    local isfunc = type(func) == "function"
    for k,v in pairs(tbl) do
        if isfunc then
            if func(k,v) then
                return k,v
            end
        else
            if func == v then
                return k,v
            end
        end
    end
end