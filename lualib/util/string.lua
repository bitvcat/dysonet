-- 字符串库扩展

function string.split(s, p)
    local rt = {}
    s = string.gsub(s, '[^' .. p .. ']+', function(w) table.insert(rt, w) end)
    return rt
end

function string.ltrim(s, cutset)
    local pattern = "^[ \t\r\n]+"
    if cutset then
        pattern = string.format("^[%s]+", cutset)
    end
    return string.gsub(s, pattern, "")
end

function string.rtrim(s, cutset)
    local pattern = "[ \t\r\n]+$"
    if cutset then
        pattern = string.format("[%s]+$", cutset)
    end
    return string.gsub(s, pattern, "")
end

function string.trim(s, cutset)
    s = string.ltrim(s, cutset)
    return string.rtrim(s, cutset)
end

function string.tohex(str, pretty)
    assert(type(str) == "string")
    if pretty then
        local strlen = #str
        local linenum = math.ceil(strlen / 16)

        local lines = {}
        -- header
        local header = { "\n" .. string.rep(" ", 9) }
        for i = 1, 16, 1 do
            header[#header + 1] = string.format("%02x", i)
        end
        header[#header + 1] = "Decoded Text"
        lines[#lines + 1] = table.concat(header, " ")

        -- hex
        for i = 1, linenum, 1 do
            local startpos = (i - 1) * 16
            local hex = { string.format("%08x:", (i - 1) * 16) }
            for j = 1, 16, 1 do
                local pos = startpos + j
                local byte = string.byte(str, pos, pos)
                hex[1 + j] = byte and string.format("%02x", byte) or "  "
                hex[16 + 1 + j] = byte and string.char(byte) or " "
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
