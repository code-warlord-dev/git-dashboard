--[[
tests/test_urgency_dedup.luau — ADR-016 effective dedup windows.

Covers: REQ-N-005 / T-N-007 / T-N-008 domain-side window selection.
]]

local T = require("./harness")
local Urgency = require("../lib/urgency")

T.test("T-N-007/ADR-016: critical default window is 5 minutes", function()
    T.eq(Urgency.dedup_window_minutes("critical", {}), 5)
end)

T.test("T-N-008/ADR-016: high default window is 15 minutes", function()
    T.eq(Urgency.dedup_window_minutes("high", {}), 15)
end)

T.test("T-N-002/ADR-016: normal and low use base dedup_minutes (30)", function()
    T.eq(Urgency.dedup_window_minutes("normal", {}), 30)
    T.eq(Urgency.dedup_window_minutes("low", {}), 30)
end)

T.test("T-N-007/ADR-016: settings override critical and high windows", function()
    local settings = {
        dedup_minutes = 45,
        dedup_minutes_high = 10,
        dedup_minutes_critical = 2,
    }
    T.eq(Urgency.dedup_window_minutes("critical", settings), 2)
    T.eq(Urgency.dedup_window_minutes("high", settings), 10)
    T.eq(Urgency.dedup_window_minutes("normal", settings), 45)
end)
