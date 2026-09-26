--[[
lib/capabilities.luau — canonical capability vocabulary and capability-honest
section rules.

Normative: ADR-003 (capability-honest UI), ADR-009 (canonical keys),
docs/DATA-MODEL.md §2 and §12, docs/SPEC.md REQ-D-004 / REQ-A-005 / REQ-A-011.

Domain module (M1): pure data plus pure functions. No Noctalia Runtime API, no
forge SDK, no network.
Tests: T-D-003, T-A-004 (docs/TRACEABILITY.md).

Why this module exists: the UI must decide what to render without ever asking
"which forge is this?" — it asks the capability map instead.
]]

local Capabilities = {}

-- Canonical capability keys, in display order (ADR-009). Nothing else is legal.
Capabilities.KEYS = {
    "notifications",
    "reviews",
    "work_items",
    "issues",
    "ci",
    "contributions",
    "mark_read",
}

-- Forbidden capability keys: forge-specific vocabulary must not leak (ADR-009).
Capabilities.FORBIDDEN = {
    "pull_requests",
    "merge_requests",
    "actions",
    "pipelines",
}

--[[
Input aliases. A provider that reports a forge-specific key is translated to the
canonical key, and the translation is reported back so nothing is hidden from the
caller. Aliasing happens on input only; output is always canonical.
]]
Capabilities.ALIASES = {
    pull_requests = "work_items",
    merge_requests = "work_items",
    actions = "ci",
    pipelines = "ci",
}

-- Signal kind → capability (docs/DATA-MODEL.md §4).
Capabilities.KIND_CAPABILITY = {
    notification = "notifications",
    review = "reviews",
    pull_request = "work_items",
    merge_request = "work_items",
    issue = "issues",
    ci_run = "ci",
}

-- Section render modes (docs/DATA-MODEL.md §12).
Capabilities.SECTION_HIDDEN = "hidden"
Capabilities.SECTION_UNAVAILABLE = "unavailable"
Capabilities.SECTION_EMPTY = "empty"
Capabilities.SECTION_LIST = "list"

local function contains(list, value)
    for _, entry in ipairs(list) do
        if entry == value then
            return true
        end
    end
    return false
end

function Capabilities.is_canonical(key)
    return contains(Capabilities.KEYS, key)
end

function Capabilities.is_forbidden(key)
    return contains(Capabilities.FORBIDDEN, key)
end

function Capabilities.capability_for_kind(kind)
    return Capabilities.KIND_CAPABILITY[kind]
end

-- All canonical keys explicitly false: "nothing known yet" is not "supported".
function Capabilities.empty()
    local caps = {}
    for _, key in ipairs(Capabilities.KEYS) do
        caps[key] = false
    end
    return caps
end

--[[
normalize(map) -> caps, report

caps   : canonical keys only, values coerced to booleans
report : { aliased = { [input_key] = canonical_key }, unknown = { input_key, ... } }

Coercion is strict: only the boolean `true` means supported. Truthy strings such
as "yes" are not accepted — a capability is a contract, not a hint.

Two input keys may alias the same canonical key (e.g. `pull_requests` and
`merge_requests`). The rule is "true wins", which makes the result independent of
`pairs()` iteration order: a claimed capability is never erased by a sibling alias.
]]
function Capabilities.normalize(map)
    local caps = Capabilities.empty()
    local report = { aliased = {}, unknown = {} }
    if type(map) ~= "table" then
        return caps, report
    end
    for key, value in pairs(map) do
        local canonical = key
        if not Capabilities.is_canonical(key) then
            if Capabilities.ALIASES[key] then
                canonical = Capabilities.ALIASES[key]
                report.aliased[key] = canonical
            else
                report.unknown[#report.unknown + 1] = tostring(key)
                canonical = nil
            end
        end
        if canonical and value == true then
            caps[canonical] = true
        end
    end
    table.sort(report.unknown)
    return caps, report
end


-- Union of many capability maps (REQ-A-005): supported if any source supports it.
function Capabilities.union(maps)
    local caps = Capabilities.empty()
    for _, map in ipairs(maps or {}) do
        local normalized = Capabilities.normalize(map)
        for _, key in ipairs(Capabilities.KEYS) do
            if normalized[key] then
                caps[key] = true
            end
        end
    end
    return caps
end

function Capabilities.supported(caps, key)
    return type(caps) == "table" and caps[key] == true
end

-- Canonical keys the source claims to support.
function Capabilities.supported_keys(caps)
    local keys = {}
    for _, key in ipairs(Capabilities.KEYS) do
        if Capabilities.supported(caps, key) then
            keys[#keys + 1] = key
        end
    end
    return keys
end

-- Canonical keys the source does not support; these sections must stay hidden.
function Capabilities.hidden_keys(caps)
    local keys = {}
    for _, key in ipairs(Capabilities.KEYS) do
        if not Capabilities.supported(caps, key) then
            keys[#keys + 1] = key
        end
    end
    return keys
end

--[[
section_mode(caps, key, item_count) -> mode

Capability honesty (ADR-003 / REQ-A-011): a section is a list only when the
capability is claimed AND data exists. A claimed capability with no data channel
is "unavailable", never a fake empty section.

  key not canonical         -> "hidden"
  capability not claimed    -> "hidden"
  claimed, no data channel  -> "unavailable"  (item_count == nil)
  claimed, zero items       -> "empty"        (the "you're clear" state)
  claimed, items present    -> "list"
]]
function Capabilities.section_mode(caps, key, item_count)
    if not Capabilities.is_canonical(key) then
        return Capabilities.SECTION_HIDDEN
    end
    if not Capabilities.supported(caps, key) then
        return Capabilities.SECTION_HIDDEN
    end
    if item_count == nil then
        return Capabilities.SECTION_UNAVAILABLE
    end
    if item_count == 0 then
        return Capabilities.SECTION_EMPTY
    end
    return Capabilities.SECTION_LIST
end

return Capabilities
