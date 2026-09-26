--[[
tests/fixtures.luau — plain-data ProviderSnapshot fixtures for the domain tests.

No network, no captured CLI output, no Noctalia Runtime (ADR-015). The fixtures
cover the contracts in docs/DATA-MODEL.md and deliberately include provider
mistakes (`sloppy`) and invalid states (`wrong_state`) so the validation and
isolation paths are exercised rather than assumed.
]]

local Capabilities = require("../lib/capabilities")
local Schema = require("../lib/schema")

local Fixtures = {}

local function capabilities(overrides)
    local map = Capabilities.empty()
    for key, value in pairs(overrides or {}) do
        map[key] = value
    end
    return map
end

local function signal(fields)
    return {
        id = fields.id,
        entity_id = fields.entity_id,
        kind = fields.kind,
        title = fields.title,
        url = fields.url,
        repo = fields.repo,
        updated_at = fields.updated_at,
        urgency = fields.urgency,
        attention = fields.attention == true,
        read = fields.read == true,
        provider = fields.provider,
        host = fields.host,
        meta = {},
    }
end

local function build(fields)
    local items = {}
    for _, entry in ipairs(fields.items or {}) do
        entry.provider = entry.provider or fields.provider
        entry.host = entry.host or fields.host
        items[#items + 1] = entry
    end
    return {
        schema_version = Schema.VERSION,
        provider = fields.provider,
        host = fields.host,
        account = fields.account or "",
        state = fields.state or "ready",
        data_state = fields.data_state or "fresh",
        stale_since = fields.stale_since,
        capabilities = Capabilities.normalize(fields.capabilities),
        counts = fields.counts or Schema.counts_from_items(items),
        items = items,
        activity = fields.activity or {},
        fetched_at = fields.fetched_at or 1000,
        last_attempt_at = fields.last_attempt_at or fields.fetched_at or 1000,
        message = fields.message or "",
    }
end

-- github: one PR that is notification + review + failing CI (entity dedup case),
-- plus a non-attention issue.
function Fixtures.github()
    return build({
        provider = "github",
        host = "github.com",
        account = "alice",
        capabilities = {
            notifications = true,
            reviews = true,
            work_items = true,
            issues = true,
            ci = true,
            contributions = false,
            mark_read = true,
        },
        items = {
            signal({
                id = "github:notification:abc",
                entity_id = "github:pr:github.com/org/repo#42",
                kind = "notification",
                title = "Review requested on feat/login",
                url = "https://github.com/org/repo/pull/42",
                repo = "org/repo",
                updated_at = 100,
                urgency = "high",
                attention = true,
            }),
            signal({
                id = "github:review:def",
                entity_id = "github:pr:github.com/org/repo#42",
                kind = "review",
                title = "Review requested on feat/login",
                url = "https://github.com/org/repo/pull/42",
                repo = "org/repo",
                updated_at = 120,
                urgency = "critical",
                attention = true,
            }),
            signal({
                id = "github:ci_run:ghi",
                entity_id = "github:pr:github.com/org/repo#42",
                kind = "ci_run",
                title = "CI failed on feat/login",
                url = "https://github.com/org/repo/actions/runs/9",
                repo = "org/repo",
                updated_at = 110,
                urgency = "high",
                attention = true,
            }),
            signal({
                id = "github:issue:xyz",
                entity_id = "github:issue:github.com/org/repo#7",
                kind = "issue",
                title = "Assigned: flaky test in CI",
                url = "https://github.com/org/repo/issues/7",
                repo = "org/repo",
                updated_at = 90,
                urgency = "low",
                attention = false,
            }),
        },
    })
end

-- gitlab: MR + assigned issue, different host/account, no reviews support.
function Fixtures.gitlab()
    return build({
        provider = "gitlab",
        host = "gitlab.com",
        account = "bob",
        capabilities = {
            notifications = true,
            reviews = false,
            work_items = true,
            issues = true,
            ci = true,
            contributions = false,
            mark_read = false,
        },
        fetched_at = 1500,
        items = {
            signal({
                id = "gitlab:merge_request:m1",
                entity_id = "gitlab:mr:gitlab.com/group/proj#5",
                kind = "merge_request",
                title = "Draft: cache warmup",
                url = "https://gitlab.com/group/proj/-/merge_requests/5",
                repo = "group/proj",
                updated_at = 200,
                urgency = "normal",
                attention = true,
            }),
            signal({
                id = "gitlab:notification:n1",
                entity_id = "gitlab:issue:gitlab.com/group/proj#9",
                kind = "notification",
                title = "Assigned: pipeline timeout on main",
                url = "https://gitlab.com/group/proj/-/issues/9",
                repo = "group/proj",
                updated_at = 210,
                urgency = "high",
                attention = true,
            }),
        },
    })
end

-- Not authenticated: identity empty, privileged lists cleared (REQ-D-010 / ADR-012).
function Fixtures.anonymous()
    return build({
        provider = "github",
        host = "github.com",
        account = "",
        state = "auth_required",
        data_state = "empty",
        capabilities = {},
        counts = Schema.new_counts(),
        fetched_at = 0,
        last_attempt_at = 1200,
        message = "run: gh auth login",
    })
end

-- Rate limited with last-good data still on screen (ADR-011 stale model).
function Fixtures.rate_limited_stale()
    return build({
        provider = "github",
        host = "github.com",
        account = "alice",
        state = "rate_limited",
        data_state = "stale",
        stale_since = 900,
        fetched_at = 900,
        last_attempt_at = 1200,
        capabilities = { notifications = true, mark_read = true },
        message = "API rate limit exceeded",
        items = {
            signal({
                id = "github:notification:old",
                entity_id = "github:pr:github.com/org/repo#43",
                kind = "notification",
                title = "Review requested (last known)",
                url = "https://github.com/org/repo/pull/43",
                repo = "org/repo",
                updated_at = 880,
                urgency = "high",
                attention = true,
            }),
        },
    })
end

-- Provider sloppiness that must be repaired, not hidden: forge-specific
-- capability keys and a wrong attention counter (REQ-D-004 / REQ-D-005).
-- The capability map is set raw, bypassing the fixture builder, so validation
-- actually sees the forbidden keys.
function Fixtures.sloppy()
    local snapshot = build({
        provider = "github",
        host = "github.com",
        account = "alice",
        items = {
            signal({
                id = "github:notification:sloppy",
                entity_id = "github:pr:github.com/org/repo#44",
                kind = "notification",
                title = "Review requested",
                url = "https://github.com/org/repo/pull/44",
                repo = "org/repo",
                updated_at = 300,
                urgency = "high",
                attention = true,
            }),
        },
    })
    snapshot.capabilities = {
        notifications = true,
        pull_requests = true,
        pipelines = true,
    }
    snapshot.counts = {
        attention = 99,
        notifications = 1,
        reviews = 0,
        work_items = 0,
        issues = 0,
        ci = 0,
    }
    return snapshot
end


-- Invalid lifecycle state: staleness belongs in data_state (ADR-011).
function Fixtures.wrong_state()
    return build({
        provider = "github",
        host = "github.com",
        account = "alice",
        state = "stale",
        data_state = "fresh",
        capabilities = { notifications = true },
        items = {
            signal({
                id = "github:notification:wrong",
                entity_id = "github:pr:github.com/org/repo#45",
                kind = "notification",
                title = "Should not be published",
                url = "https://github.com/org/repo/pull/45",
                repo = "org/repo",
                updated_at = 400,
                urgency = "high",
                attention = true,
            }),
        },
    })
end


function Fixtures.garbage()
    return "this is not a snapshot"
end

return Fixtures
