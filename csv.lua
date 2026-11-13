---------------------------------------------------------------------------
-- csv.lua — read and write simple CSV files
--
-- Limits: no commas or line breaks inside fields, and no quoted fields.
--
-- Where files live: reading looks in the SAVE folder first, then the
-- project folder. Writing always goes to the save folder (the project
-- folder can't be written to, and on a phone it's read-only anyway).
---------------------------------------------------------------------------
local csv = {}

local function trim(s)
    return s:match("^%s*(.-)%s*$")
end

local function splitLine(line)
    local fields = {}
    for field in (line .. ","):gmatch("([^,]*),") do
        fields[#fields + 1] = trim(field)
    end
    return fields
end

-- Returns a list of rows, each a table keyed by the header names.
function csv.load(path)
    local rows, headers = {}, nil
    for line in love.filesystem.lines(path) do
        line = line:gsub("^\239\187\191", "")    -- strip Excel's invisible BOM
        if trim(line) ~= "" then
            local fields = splitLine(line)
            if not headers then
                headers = fields
            else
                local row = {}
                for i, name in ipairs(headers) do
                    local v = fields[i]
                    if v == "" then v = nil end
                    row[name] = v and (tonumber(v) or v)
                end
                rows[#rows + 1] = row
            end
        end
    end
    return rows
end

-- Turn one value into CSV text. nil becomes an empty cell. Commas and line
-- breaks are refused, since csv.load couldn't read them back.
local function toField(value)
    if value == nil then return "" end
    local text = tostring(value)
    assert(not text:find("[,\r\n]"),
        "can't save '" .. text .. "': commas and line breaks aren't supported")
    return text
end

-- rows    : list of tables
-- columns : the column names IN ORDER (table keys have no order of their own)
function csv.save(path, rows, columns)
    local lines = { table.concat(columns, ",") }
    for _, row in ipairs(rows) do
        local fields = {}
        for i, name in ipairs(columns) do
            fields[i] = toField(row[name])
        end
        lines[#lines + 1] = table.concat(fields, ",")
    end
    local ok, err = love.filesystem.write(path, table.concat(lines, "\n") .. "\n")
    assert(ok, "couldn't save " .. path .. ": " .. tostring(err))
end

-- Does a file exist (in the save folder or the project folder)?
function csv.exists(path)
    return love.filesystem.getInfo(path) ~= nil
end

return csv