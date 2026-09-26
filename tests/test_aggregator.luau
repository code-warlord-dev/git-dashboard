--[[
tests/test_aggregator.luau — domain aggregator tests.

Covers: REQ-A-001 … REQ-A-008 with test ids T-A-001 … T-A-005
(docs/TRACEABILITY.md). T-A-006 (refresh generation) belongs to M1.4 and is not
claimed here.
]]

local T = require("./harness")
local Helpers = require("./helpers")
local Fixtures = require("./fixtures")
local Aggregator = require("../lib/aggregator")
local Capabilities = require("../lib/capabilities")
local Schema = require("../lib/schema")

T.test("T-A-001: merge combines two snapshots into one unified overview", function()
    local overview = Aggregator.merge({ Fixtures.github(), Fixtures.gitlab() }, { published_at = 1234 })

    T.eq(overview.schema_version, 1)
    T.eq(overview.published_at, 1234)
    T.eq(overview.mode, "all")
    T.eq(overview.providers, { "github", "gitlab" })
    T.eq(#overview.sources, 2)
    T.eq(Helpers.source_keys(overview), { "github|github.com|alice", "gitlab|gitlab.com|bob" })
    T.eq(overview.item_count, 6)
    T.eq(#overview.problems, 0, "clean fixtures must produce no diagnostics")

    T.eq(overview.counts, {
        attention = 3,
        notifications = 2,
        reviews = 1,
        work_items = 1,
        issues = 1,
        ci = 1,
    })

    T.eq(Helpers.entity_ids(overview.attention), {
        "github:pr:github.com/org/repo#42",
        "gitlab:issue:gitlab.com/group/proj#9",
        "gitlab:mr:gitlab.com/group/proj#5",
    }, "sorted by urgency rank, then updated_at")
end)

T.test("T-A-001: merge accepts zero snapshots (REQ-A-001)", function()
    local overview = Aggregator.merge({})
    T.eq(overview.sources, {})
    T.eq(overview.providers, {})
    T.eq(overview.attention, {})
    T.eq(overview.item_count, 0)
    T.eq(overview.counts, Schema.new_counts())

    T.eq(#Aggregator.merge(nil).sources, 0, "nil is treated as an empty source list")
end)

T.test("T-A-001/REQ-A-008: the published overview is plain data only", function()
    local overview = Aggregator.merge({ Fixtures.github(), Fixtures.gitlab() })
    T.eq(Helpers.find_non_plain(overview), nil,
        "no functions/userdata may reach noctalia.state (REQ-D-008)")
    T.eq(overview.refresh_id, 0, "refresh generation is injected by the service (ADR-013)")

    local injected = Aggregator.new({ refresh_id = 7 }):merge({ Fixtures.github() })
    T.eq(injected.refresh_id, 7)
end)

T.test("T-A-002: a broken source degrades itself without poisoning others", function()
    local overview = Aggregator.merge({ Fixtures.github(), Fixtures.garbage() })

    T.eq(#overview.sources, 2)
    local broken = overview.sources[2]
    T.eq(broken.state, "bad_response")
    T.eq(broken.data_state, "empty")
    T.eq(broken.counts, Schema.new_counts())
    T.eq(broken.item_count, 0)
    T.eq(broken.valid, false)
    T.truthy(Helpers.has(broken.problems, "not_a_table"))
    T.eq(overview.providers, { "github" }, "an unattributable snapshot must not create a tab")

    local healthy = overview.sources[1]
    T.eq(healthy.state, "ready")
    T.eq(healthy.problems, {})
    T.eq(Helpers.entity_ids(overview.attention), { "github:pr:github.com/org/repo#42" })
    T.eq(overview.counts.attention, 1)
    T.eq(overview.counts.issues, 1)
    T.truthy(#overview.problems > 0, "the failure is visible, not swallowed")
end)

T.test("T-A-002: a snapshot that breaks the contract is degraded, not published", function()
    local overview = Aggregator.merge({ Fixtures.gitlab(), Fixtures.wrong_state() })
    local invalid = overview.sources[2]

    T.eq(invalid.state, "bad_response")
    T.eq(invalid.data_state, "empty")
    T.eq(invalid.valid, false)
    T.eq(invalid.error.code, "bad_response")
    T.truthy(Helpers.has(invalid.problems, "stale_is_not_a_state"))
    T.eq(invalid.counts, Schema.new_counts())

    T.eq(Helpers.entity_ids(overview.attention), {
        "gitlab:issue:gitlab.com/group/proj#9",
        "gitlab:mr:gitlab.com/group/proj#5",
    }, "the healthy provider keeps every item")
    T.eq(overview.counts.notifications, 1)
    T.eq(overview.counts.work_items, 1)
end)

T.test("T-A-002: auth loss on one provider clears only that provider", function()
    local overview = Aggregator.merge({ Fixtures.anonymous(), Fixtures.github() })

    local anonymous = overview.sources[1]
    T.eq(anonymous.state, "auth_required")
    T.eq(anonymous.data_state, "empty")
    T.eq(anonymous.counts, Schema.new_counts())
    T.eq(anonymous.item_count, 0)
    T.eq(anonymous.capabilities, Capabilities.empty())

    T.eq(overview.counts, Aggregator.merge({ Fixtures.github() }).counts,
        "the authenticated provider is unaffected")
    T.eq(Helpers.entity_ids(overview.attention), { "github:pr:github.com/org/repo#42" })
end)

T.test("T-A-002/ADR-011: rate-limited last-good still contributes, it is not a wipe", function()
    local overview = Aggregator.merge({ Fixtures.rate_limited_stale() })
    T.eq(overview.sources[1].state, "rate_limited")
    T.eq(overview.sources[1].data_state, "stale")
    T.eq(overview.sources[1].stale_since, 900)
    T.eq(overview.counts.attention, 1)
    T.eq(Helpers.entity_ids(overview.attention), { "github:pr:github.com/org/repo#43" })
end)

T.test("T-A-003: filtering is pure and rebuilds counts, attention and capabilities", function()
    local overview = Aggregator.merge({ Fixtures.github(), Fixtures.gitlab() })
    local full_entities = Helpers.entity_ids(overview.attention)

    local github = Aggregator.filter(overview, "github")
    T.eq(github.mode, "github")
    T.eq(github.providers, { "github" })
    T.eq(#github.sources, 1)
    T.eq(Helpers.source_keys(github), { "github|github.com|alice" })
    T.eq(github.counts, Aggregator.merge({ Fixtures.github() }).counts)
    T.eq(Helpers.entity_ids(github.attention), { "github:pr:github.com/org/repo#42" })
    T.eq(github.capabilities_union.reviews, true)
    T.eq(github.capabilities_union.issues, true)

    -- filtering must not need a re-fetch and must not mutate the published model
    T.eq(Helpers.entity_ids(overview.attention), full_entities)
    T.eq(#overview.sources, 2)
    T.eq(overview.counts.attention, 3)

    local by_identity = Aggregator.filter(overview, { provider = "gitlab", host = "gitlab.com" })
    T.eq(Helpers.source_keys(by_identity), { "gitlab|gitlab.com|bob" })

    local empty = Aggregator.filter(overview, "gitea")
    T.eq(#empty.sources, 0)
    T.eq(empty.counts, Schema.new_counts())
    T.eq(empty.attention, {})
    T.eq(empty.capabilities_union, Capabilities.empty())
end)

T.test("T-A-003/REQ-A-007: tabs come from the model, not from provider conditionals", function()
    local overview = Aggregator.merge({ Fixtures.github(), Fixtures.gitlab() })
    T.eq(Aggregator.modes(overview), { "all", "github", "gitlab" })
    T.eq(Aggregator.modes(Aggregator.merge({})), { "all" })
end)

T.test("T-A-004: capability honesty — hidden, unavailable, empty, list", function()
    local caps = Capabilities.empty()
    T.eq(Capabilities.section_mode(caps, "ci", 0), "hidden", "unclaimed capability is hidden even with items")

    caps.ci = true
    T.eq(Capabilities.section_mode(caps, "ci", nil), "unavailable", "claimed but no data channel")
    T.eq(Capabilities.section_mode(caps, "ci", 0), "empty", "the honest 'you are clear' state")
    T.eq(Capabilities.section_mode(caps, "ci", 3), "list")

    T.eq(Capabilities.section_mode(caps, "pipelines", 3), "hidden", "non-canonical keys never render")
    T.eq(Capabilities.section_mode(caps, "reviews", 0), "hidden", "a forge may simply not have reviews")
end)

T.test("T-A-004: a filtered tab stays capability-honest per source", function()
    local overview = Aggregator.merge({ Fixtures.github(), Fixtures.gitlab() })
    local source = Aggregator.filter(overview, "gitlab").sources[1]

    T.eq(Capabilities.section_mode(source.capabilities, "reviews", 0), "hidden")
    T.eq(Capabilities.section_mode(source.capabilities, "reviews", 5), "hidden")
    T.eq(Capabilities.section_mode(source.capabilities, "notifications", 1), "list")
    T.eq(Capabilities.section_mode(source.capabilities, "mark_read", 1), "hidden",
        "gitlab cannot mark read here; the UI must not offer it")
end)

T.test("T-A-005: one entity with three signals is one attention item", function()
    local overview = Aggregator.merge({ Fixtures.github() })
    T.eq(#overview.attention, 1)

    local entity = overview.attention[1]
    T.eq(entity.entity_id, "github:pr:github.com/org/repo#42")
    T.eq(entity.urgency, "critical", "the highest-urgency signal becomes the face")
    T.eq(entity.kind, "review")
    T.eq(entity.signal_count, 3)
    T.eq(entity.signal_ids, { "github:ci_run:ghi", "github:notification:abc", "github:review:def" })
    T.eq(entity.kinds, { "ci_run", "notification", "review" })
    T.eq(entity.updated_at, 120, "latest signal timestamp wins")
    T.eq(entity.provider, "github")
    T.eq(entity.host, "github.com")

    T.eq(overview.counts.attention, 1, "the badge counts entities, not signals (ADR-010)")
    T.eq(overview.counts.reviews + overview.counts.notifications + overview.counts.ci, 3,
        "signal badges still expose the underlying activity")
end)

T.test("REQ-A-005: union and per-source capability maps are both exposed", function()
    local overview = Aggregator.merge({ Fixtures.github(), Fixtures.gitlab() })
    T.eq(overview.capabilities_union.reviews, true, "github supports reviews")
    T.eq(overview.capabilities_union.mark_read, true)
    T.eq(overview.capabilities_union.contributions, false, "no provider claims contributions yet")
    T.eq(overview.sources[1].capabilities.reviews, true)
    T.eq(overview.sources[2].capabilities.reviews, false, "gitlab must not inherit github capabilities")
    T.eq(overview.sources[2].capabilities.mark_read, false)
end)

T.test("T-D-005/REQ-A-003: provider mistakes are repaired and stay visible", function()
    local overview = Aggregator.merge({ Fixtures.sloppy() })
    local source = overview.sources[1]

    T.eq(overview.counts.attention, 1, "the wrong counter never reaches the badge")
    T.eq(source.counts.attention, 1)
    T.eq(source.capabilities.work_items, true)
    T.eq(source.capabilities.pull_requests, nil, "no forge-specific capability key in the model")
    T.eq(source.valid, true, "warnings do not degrade a usable source")

    T.truthy(Helpers.has(overview.problems, "attention_count_mismatch"))
    T.truthy(Helpers.has(overview.problems, "forbidden_capability_key"))

    local problem = Helpers.find(overview.problems, "attention_count_mismatch")
    T.eq(problem.source_key, "github|github.com|alice", "diagnostics are attributable to a source")
    T.eq(problem.severity, "warn")
end)

T.test("REQ-A-007: per-source status is exposed for the panel and the widget", function()
    local overview = Aggregator.merge({
        Fixtures.github(),
        Fixtures.gitlab(),
        Fixtures.rate_limited_stale(),
    })
    local github, gitlab, limited = overview.sources[1], overview.sources[2], overview.sources[3]

    T.eq(github.state, "ready")
    T.eq(github.data_state, "fresh")
    T.eq(github.fetched_at, 1000)
    T.eq(github.item_count, 4)

    T.eq(gitlab.account, "bob")
    T.eq(gitlab.last_attempt_at, 1500)

    T.eq(limited.state, "rate_limited")
    T.eq(limited.data_state, "stale")
    T.eq(limited.stale_since, 900)
    T.eq(limited.message, "API rate limit exceeded")
    T.eq(limited.error, nil, "the lifecycle state carries the failure; no error object is invented")

    T.eq(overview.providers, { "github", "gitlab" }, "the provider list stays unique and ordered")
    T.eq(overview.counts.attention, 4, "one entity per distinct source entity_id")
    T.eq(overview.counts.notifications, 3)
    T.eq(overview.item_count, 7)
end)


