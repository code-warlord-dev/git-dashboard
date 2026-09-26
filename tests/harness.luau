--[[
tests/harness.luau — minimal pure Luau test harness (ADR-015).

Design constraints from ADR-015:
  * no dependency on Noctalia Runtime, no network, no external test library;
  * runs under `luau`, and also under `lua5.4` / `luajit` for local development;
  * assertions are plain functions: equality (deep), truthy, falsy, raises.

The relative-require shim exists so that `lib/` modules can use idiomatic Luau
relative imports (`require("./schema")`) while the same files still load under a
plain Lua interpreter. Luau resolves "./x" natively; Lua needs the shim below.
]]

local Harness = {}

local function normalize_module_name(name)
    name = name:gsub("^%./", "")
    name = name:gsub("/%.%/", "/")
    while true do
        local next_name = name
            :gsub("^[^/]+/%.%./", "")
            :gsub("/[^/]+/%.%./", "/")
        if next_name == name then
            return name
        end
        name = next_name
    end
end


--[[
Plain Lua caches modules by the literal name passed to require(), so
"./harness" and "tests/../lib/schema" would otherwise create duplicate module
instances. The shim therefore resolves and CANONICALIZES the name before
delegating to the real require.
]]
local function install_relative_require()
    if _VERSION == "Luau" then
        return
    end
    if type(package) ~= "table" or type(debug) ~= "table" then
        return
    end
    local real_require = require
    _G.require = function(name)
        if type(name) == "string" and string.sub(name, 1, 1) == "." then
            local info = debug.getinfo(2, "S")
            local source = (info and info.source) or ""
            local dir = string.match(source, "^@(.*)/[^/]*$")
            if dir ~= nil and dir ~= "" then
                name = normalize_module_name(dir .. "/" .. name)
            end
        end
        return real_require(name)
    end
end


install_relative_require()

Harness.tests = {}

function Harness.test(name, fn)
    Harness.tests[#Harness.tests + 1] = { name = name, fn = fn }
end

local function render(value, depth)
    depth = depth or 0
    local kind = type(value)
    if kind == "string" then
        return string.format("%q", value)
    end
    if kind ~= "table" then
        return tostring(value)
    end
    if depth > 4 then
        return "{...}"
    end
    local keys = {}
    for key in pairs(value) do
        keys[#keys + 1] = key
    end
    table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
    end)
    local parts = {}
    for _, key in ipairs(keys) do
        parts[#parts + 1] = tostring(key) .. " = " .. render(value[key], depth + 1)
    end
    return "{ " .. table.concat(parts, ", ") .. " }"
end

Harness.render = render

local function deep_equal(a, b)
    if a == b then
        return true
    end
    if type(a) ~= "table" or type(b) ~= "table" then
        return false
    end
    for key, value in pairs(a) do
        if not deep_equal(value, b[key]) then
            return false
        end
    end
    for key in pairs(b) do
        if a[key] == nil then
            return false
        end
    end
    return true
end

Harness.deep_equal = deep_equal

function Harness.eq(actual, expected, message)
    if not deep_equal(actual, expected) then
        error(string.format("%s\n    expected: %s\n    actual:   %s",
            message or "values differ", render(expected), render(actual)), 2)
    end
end

function Harness.truthy(value, message)
    if not value then
        error(message or "expected a truthy value", 2)
    end
end

function Harness.falsy(value, message)
    if value then
        error(message or "expected a falsy value", 2)
    end
end

function Harness.raises(fn, message)
    local ok = pcall(fn)
    if ok then
        error(message or "expected an error", 2)
    end
end

function Harness.run()
    local passed, failed = 0, 0
    for _, case in ipairs(Harness.tests) do
        local ok, err = pcall(case.fn)
        if ok then
            passed = passed + 1
            io.write(string.format("ok   %s\n", case.name))
        else
            failed = failed + 1
            local text = tostring(err)
            io.write(string.format("FAIL %s\n     %s\n", case.name, (text:gsub("\n", "\n     "))))
        end
    end
    io.write(string.format("\n%d passed, %d failed, %d total\n", passed, failed, #Harness.tests))
    return failed
end

return Harness
