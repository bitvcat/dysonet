-- 数学库扩展

function math.round(val, digit)
    return math.floor((val * 10 ^ digit + 0.5)) / 10 ^ digit
end

function math.roundup(val, digit)
    return math.ceil(val * 10 ^ digit) / 10 ^ digit
end
