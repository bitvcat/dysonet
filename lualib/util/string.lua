--[[!
    @file
    @brief 字符串库扩展
    @details 详细 API 接口参见 string 类。
]]

--- @class string
--- @brief 扩展标准字符串库
--- @details 这里是字符串扩展的详细描述。
--- @package string
local test = {} --- test int
string.test1 = {} --- string test1
string.test2 = { --- string test2
    a = 1,
    b = 2
}

--- @brief test static function
local function foo()
end

--- @brief test function
--- @param string a this is a value
--- @param string b this is b value
function bar(a, b)
    print(a, b)
end

--- @brief 字符串分割
--- @param string s 要分割的字符串
--- @param char p 分隔符
--- @return 分割后的字符串列表
function string.split(s, p)
    local rt = {}
    s = string.gsub(s, '[^' .. p .. ']+', function(w) table.insert(rt, w) end)
    return rt
end

--- @brief 字符串左侧裁剪
--- @param string s 要裁剪的字符串
--- @param string cutset 裁减的字符集合
--- @return 裁剪后的字符串
function string.ltrim(s, cutset)
    local pattern = "^[ \t\r\n]+"
    if cutset then
        pattern = string.format("^[%s]+", cutset)
    end
    return string.gsub(s, pattern, "")
end

--- @brief 字符串<b>右侧</b>裁剪
--- @param string s 要裁剪的字符串
--- @param string cutset 裁减的字符集合
--- @return 裁剪后的字符串
function string.rtrim(s, cutset)
    local pattern = "[ \t\r\n]+$"
    if cutset then
        pattern = string.format("[%s]+$", cutset)
    end
    return string.gsub(s, pattern, "")
end

--- @brief 字符串裁剪
--- @param string s 要裁剪的字符串
--- @param string cutset 裁减的字符集合
--- @return 两边都裁剪后的字符串
function string.trim(s, cutset)
    s = string.ltrim(s, cutset)
    return string.rtrim(s, cutset)
end

--! @brief 字符串裁剪
--! @param string s 要裁剪的字符串
--! @param string cutset 裁减的字符集合
--! @return 两边都裁剪后的字符串
function string.trim1(s, cutset)
    cutset = cutset or " \t\r\n"
    local pattern = string.format("^[%s]*(.-)[%s]*$", cutset, cutset)
    return string.match(s, pattern)
end

--- @brief 将字符串用16进制格式化
--- @param[in] string str 要打印的字符串
--- @param[in] bool pretty 是否美化打印结果
--- @return 格式化的字符串
--- @note 无法被打印的字符显示为 ⊠
--- @remark 示例
---	@code{.lua}
---	local str = "abcdefg"
---	print(string.tohex(str, true))
--- @endcode
function string.tohex(str, pretty)
    assert(type(str) == "string")
    if pretty then
        local strlen = #str
        local linenum = math.ceil(strlen / 16)

        local lines = {}
        -- header
        local header = { "\n" .. string.rep(" ", 9) }
        for i = 1, 16, 1 do
            header[#header + 1] = string.format("%02x", i - 1)
        end
        header[#header + 1] = "  Decoded Text"
        lines[#lines + 1] = table.concat(header, " ")

        -- hex
        for i = 1, linenum, 1 do
            local startpos = (i - 1) * 16
            local hex = { string.format("%08x:", (i - 1) * 16) }
            hex[16 + 2] = "│"
            for j = 1, 16, 1 do
                local pos = startpos + j
                local byte = string.byte(str, pos, pos)
                hex[1 + j] = byte and string.format("%02x", byte) or "  "
                hex[16 + 2 + j] = byte and (byte>31 and byte<127 and string.char(byte) or "⊠") or " "
            end
            lines[#lines + 1] = table.concat(hex, " ")
        end
        return table.concat(lines, "\n")
    else
        local hex = { "0x" }
        for i = 1, #str, 1 do
            hex[#hex + 1] = string.format("%02x", string.byte(str, i, i))
        end
        return table.concat(hex)
    end
end
