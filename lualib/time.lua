-- 时间扩展库

local time = {}

function time.zoneoffset(t)
    t = t or os.time()
    local diff = os.difftime(t, os.time(os.date("!*t", t)))
    diff = math.floor(diff)

    local zone
    if diff%3600 == 0 then
        zone = diff // 3600
    else
        zone = diff / 3600
    end
    return zone
end

function time.timezone(t)
    local zone = time.zoneoffset(t)
    return "UTC" .. (zone > 0 and "+"..zone or zone)
end

return time