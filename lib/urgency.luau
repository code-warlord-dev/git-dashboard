--[[
lib/urgency.luau — urgency vocabulary and ordering.

Domain module (M1): pure data plus pure functions. No Noctalia Runtime API, no
forge SDK, no network, no global state.

Normative: docs/DATA-MODEL.md §5 (urgency rank), docs/SPEC.md REQ-D-002 /
REQ-D-006.
Tests: T-D-004 (docs/TRACEABILITY.md).

Why a rank module: the badge, the attention queue and the notification policy
all need exactly one definition of "more urgent", otherwise M2/M3 drift.
]]

local Urgency = {}

-- Rank table is normative — docs/DATA-MODEL.md §5.
Urgency.RANK = {
    critical = 4,
    high = 3,
    normal = 2,
    low = 1,
}

-- Descending severity order, for iteration and validation.
Urgency.ORDER = { "critical", "high", "normal", "low" }

-- Unknown urgency ranks 0 so it sorts last; it is never silently promoted.
function Urgency.rank(value)
    return Urgency.RANK[value] or 0
end

function Urgency.is_valid(value)
    return Urgency.RANK[value] ~= nil
end

-- Returns the more urgent of two values; an unknown value loses to a known one.
function Urgency.max(a, b)
    if Urgency.rank(b) > Urgency.rank(a) then
        return b
    end
    return a
end

--[[
Comparator for attention / list ordering (REQ-A-002):
urgency rank DESC, then updated_at DESC, then id ASC.

The id tie-break exists because table.sort is not stable: without it, output
order would depend on input order and tests could pass accidentally.

Usage: table.sort(list, Urgency.compare)
]]
function Urgency.compare(a, b)
    local rank_a, rank_b = Urgency.rank(a and a.urgency), Urgency.rank(b and b.urgency)
    if rank_a ~= rank_b then
        return rank_a > rank_b
    end
    local updated_a = (a and a.updated_at) or 0
    local updated_b = (b and b.updated_at) or 0
    if updated_a ~= updated_b then
        return updated_a > updated_b
    end
    local id_a = (a and (a.entity_id or a.id)) or ""
    local id_b = (b and (b.entity_id or b.id)) or ""
    return id_a < id_b
end

return Urgency
