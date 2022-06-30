function string.split(s, p)
    local rt = {}
    s = string.gsub(s, '[^' .. p .. ']+', function(w) print(w) table.insert(rt, w) end)
    return rt
end
