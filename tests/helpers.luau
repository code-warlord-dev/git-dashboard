--[[
tests/helpers.luau — shared assertions for the domain test suite.
]]

local Helpers = {}

-- All problems with a given severity (nil = every problem).
function Helpers.severity(problems, wanted)
    local found = {}
    for _, problem in ipairs(problems or {}) do
        if wanted == nil or problem.severity == wanted then
            found[#found + 1] = problem
        end
    end
    return found
end

function Helpers.find(problems, code)
    for _, problem in ipairs(problems or {}) do
        if problem.code == code then
            return problem
        end
    end
    return nil
end

function Helpers.has(problems, code)
    return Helpers.find(problems, code) ~= nil
end

function Helpers.paths(problems)
    local paths = {}
    for _, problem in ipairs(problems or {}) do
        paths[#paths + 1] = tostring(problem.path)
    end
    table.sort(paths)
    return paths
end

function Helpers.codes(problems)
    local codes = {}
    for _, problem in ipairs(problems or {}) do
        codes[#codes + 1] = tostring(problem.code)
    end
    table.sort(codes)
    return codes
end

function Helpers.entity_ids(attention)
    local ids = {}
    for _, entity in ipairs(attention or {}) do
        ids[#ids + 1] = entity.entity_id
    end
    return ids
end

function Helpers.source_keys(overview)
    local keys = {}
    for _, source in ipairs(overview.sources or {}) do
        keys[#keys + 1] = source.source_key
    end
    return keys
end

-- REQ-D-008: everything published to the state channel is plain data.
function Helpers.find_non_plain(value, path)
    path = path or ""
    local kind = type(value)
    if kind == "function" or kind == "userdata" or kind == "thread" then
        return path .. " (" .. kind .. ")"
    end
    if kind ~= "table" then
        return nil
    end
    for key, entry in pairs(value) do
        local found = Helpers.find_non_plain(entry, path .. "." .. tostring(key))
        if found ~= nil then
            return found
        end
    end
    return nil
end

return Helpers
