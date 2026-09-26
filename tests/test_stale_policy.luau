--[[
tests/test_stale_policy.luau — last-good window and refresh generations.

Covers: REQ-A-009 with T-A-007 and REQ-S-005 / ADR-013 with T-A-006
(docs/TRACEABILITY.md). The staleness model itself (ADR-011) is asserted in
tests/test_schema.luau; here the policy decisions and generation ordering are.
]]

local T = require("./harness")
local Fixtures = require("./fixtures")
local Aggregator = require("../lib/aggregator")
local Errors = require("../lib/errors")
local Schema = require("../lib/schema")

local NOW = 100000

T.test("T-A-007: a successful fetch clears every staleness marker", function()
    local stale = Fixtures.rate_limited_stale()
    T.eq(stale.data_state, "stale")

    local fresh = Schema.apply_success(stale, NOW)
    T.eq(fresh.state, "ready")
    T.eq(fresh.data_state, "fresh")
    T.eq(fresh.stale_since, nil)
    T.eq(fresh.stale_expired, nil)
    T.eq(fresh.error, nil)
    T.eq(fresh.fetched_at, NOW)
    T.eq(fresh.last_attempt_at, NOW)
    T.eq(#fresh.items, 1, "last-good items survive a successful refresh")
end)

T.test("T-A-007: a rate limit inside the window serves last-good with a banner", function()
    local snapshot = Fixtures.github()
    snapshot.fetched_at = NOW - 600
    snapshot.last_attempt_at = NOW - 600

    local state, err = Errors.classify({ exit_code = 1, stderr = "API rate limit exceeded for user ID 1" })
    local updated = Schema.apply_failure(snapshot, { state = state, error = err, message = err.message }, { now = NOW })

    T.eq(state, "rate_limited")
    T.eq(updated.state, "rate_limited")
    T.eq(updated.data_state, "stale")
    T.eq(updated.stale_expired, false, "fresh enough to trust, with a banner")
    T.eq(updated.stale_since, NOW, "staleness starts at the failed attempt")
    T.eq(updated.last_attempt_at, NOW)
    T.eq(updated.fetched_at, NOW - 600, "fetched_at is frozen on the last success")
    T.eq(#updated.items, 4, "last-good is still on screen")
    T.eq(updated.counts.attention, 1)
    T.eq(updated.error.code, "rate_limited")
    T.eq(updated.error.retryable, true)
end)

T.test("T-A-007: beyond the window last-good is still served but flagged expired", function()
    local snapshot = Fixtures.github()
    snapshot.fetched_at = NOW - 4000

    local updated = Schema.apply_failure(snapshot,
        { state = "network_error", message = "timeout" }, { now = NOW })

    T.eq(updated.data_state, "stale")
    T.eq(updated.stale_expired, true, "REQ-A-009 prefers last-good over an empty dashboard")
    T.eq(#updated.items, 4, "but the banner must say the data may be outdated")
    T.eq(updated.stale_since, NOW)

    local custom = Schema.apply_failure(snapshot, { state = "network_error" },
        { now = NOW, stale_window_sec = 7200 })
    T.eq(custom.stale_expired, false, "the window is configurable")
end)

T.test("T-A-007/ADR-012: auth loss clears privileged items even inside the window", function()
    local snapshot = Fixtures.github()
    snapshot.fetched_at = NOW - 60

    local state, err = Errors.classify({ exit_code = 1, stderr = "please run: gh auth login" })
    local updated = Schema.apply_failure(snapshot, { state = state, error = err }, { now = NOW })

    T.eq(state, "auth_required")
    T.eq(updated.state, "auth_required")
    T.eq(updated.data_state, "empty")
    T.eq(#updated.items, 0, "no private titles may outlive a logout")
    T.eq(updated.activity, {})
    T.eq(updated.counts, Schema.new_counts())
    T.eq(updated.stale_since, nil)
    T.eq(updated.stale_expired, nil)
    T.eq(updated.error.code, "auth_required")

    -- the input snapshot must never be mutated by the policy helper
    T.eq(snapshot.data_state, "fresh")
    T.eq(snapshot.items[1].title, "Review requested on feat/login")
end)

T.test("T-A-007: an unavailable provider publishes nothing but keeps its identity", function()
    local snapshot = Fixtures.github()
    local updated = Schema.apply_failure(snapshot, { state = "unavailable", message = "gh not installed" }, { now = NOW })

    T.eq(updated.state, "unavailable")
    T.eq(updated.data_state, "empty")
    T.eq(#updated.items, 0)
    T.eq(updated.account, "alice", "identity stays for the provider-level banner")
    T.eq(updated.message, "gh not installed")
end)

T.test("T-A-007: a failure with nothing to serve reduces to empty, not fake staleness", function()
    local updated = Schema.apply_failure(Fixtures.anonymous(), { state = "network_error" }, { now = NOW })

    T.eq(updated.data_state, "empty")
    T.eq(updated.stale_since, nil)
    T.eq(updated.stale_expired, nil)
    T.eq(updated.counts, Schema.new_counts())
end)

T.test("T-A-007: staleness() gives the UI banner inputs without provider knowledge", function()
    local snapshot = Fixtures.github()
    snapshot.data_state = "stale"
    snapshot.fetched_at = NOW - 600
    snapshot.stale_since = NOW - 600

    local info = Schema.staleness(snapshot, NOW)
    T.eq(info.data_state, "stale")
    T.eq(info.age_sec, 600)
    T.eq(info.stale_since, NOW - 600)
    T.eq(info.expired, false, "default window is 30 minutes")

    T.eq(Schema.staleness(snapshot, NOW + 2000).expired, true)
    T.eq(Schema.staleness(snapshot, NOW, 900).expired, false, "window is configurable")
    T.eq(Schema.staleness(snapshot, NOW, 599).expired, true)
    T.eq(Schema.staleness({ fetched_at = NOW + 50, data_state = "fresh" }, NOW).age_sec, 0,
        "clock skew never produces a negative age")
end)

T.test("T-A-007: persisted last-good older than 24h is discarded on load", function()
    local snapshot = Fixtures.github()
    snapshot.fetched_at = NOW

    T.eq(Schema.should_discard_last_good(snapshot, NOW), false)
    T.eq(Schema.should_discard_last_good(snapshot, NOW + Schema.LAST_GOOD_MAX_AGE_SEC), false,
        "exactly at the retention limit is still usable")
    T.eq(Schema.should_discard_last_good(snapshot, NOW + Schema.LAST_GOOD_MAX_AGE_SEC + 1), true)
    T.eq(Schema.should_discard_last_good(snapshot, NOW + 11, { last_good_max_age_sec = 10 }), true,
        "retention is configurable")
    T.eq(Schema.should_discard_last_good({ fetched_at = 0 }, NOW), true, "no timestamp means no trust")
    T.eq(Schema.should_discard_last_good(nil, NOW), true)
end)

T.test("T-A-007: the aggregator keeps a rate-limited source visible and flags expiry", function()
    local snapshot = Fixtures.github()
    snapshot.fetched_at = NOW - 4000

    local state, err = Errors.classify({ exit_code = 1, stderr = "API rate limit exceeded" })
    local failed = Schema.apply_failure(snapshot, { state = state, error = err }, { now = NOW })

    local overview = Aggregator.merge({ failed })
    local source = overview.sources[1]

    T.eq(source.state, "rate_limited")
    T.eq(source.data_state, "stale")
    T.eq(source.stale_expired, true, "the flag survives normalization into the overview")
    T.eq(source.item_count, 4)
    T.eq(overview.counts.attention, 1)
    T.eq(#overview.attention, 1)
    T.eq(overview.sources[1].snapshot.stale_expired, true)
end)

T.test("T-A-006: refresh generations are monotonic and only the current one publishes", function()
    local aggregator = Aggregator.new()
    T.eq(aggregator.current_refresh_id, 0)

    local first = aggregator:begin_refresh()
    local second = aggregator:begin_refresh()
    T.eq(first, 1)
    T.eq(second, 2)
    T.eq(aggregator:accepts_generation(second), true)
    T.eq(aggregator:accepts_generation(first), false, "an older generation is late by definition")
    T.eq(aggregator:accepts_generation(nil), false)
end)

T.test("T-A-006: a late result is discarded instead of overwriting newer state", function()
    local aggregator = Aggregator.new()
    local slow = aggregator:begin_refresh()
    local newer = aggregator:begin_refresh()

    local overview, reason = aggregator:publish({ Fixtures.github() }, slow)
    T.eq(overview, nil)
    T.eq(reason, "stale_generation")
    T.eq(aggregator.accepted_refresh_id, 0, "nothing was published")

    local published = aggregator:publish({ Fixtures.gitlab() }, newer)
    T.truthy(published ~= nil, "the current generation publishes")
    T.eq(published.refresh_id, newer)
    T.eq(published.providers, { "gitlab" })
    T.eq(aggregator.accepted_refresh_id, newer)

    local again, second_reason = aggregator:publish({ Fixtures.github() }, slow)
    T.eq(again, nil)
    T.eq(second_reason, "stale_generation")
    T.eq(aggregator.accepted_refresh_id, newer, "newer state is never overwritten by an older generation")
end)

T.test("T-A-006: publish without a generation tag uses the current one", function()
    local aggregator = Aggregator.new()
    aggregator:begin_refresh()

    local overview = aggregator:publish({ Fixtures.github() }, nil, { published_at = 4242 })
    T.eq(overview.refresh_id, 1)
    T.eq(overview.published_at, 4242)
    T.eq(overview.schema_version, Schema.VERSION)
end)

T.test("T-A-006: refresh timeouts are bounded and keep last-good on expiry", function()
    T.eq(Aggregator.PROVIDER_TIMEOUT_SEC, 30)
    T.eq(Aggregator.REFRESH_BUDGET_SEC, 60)
    T.eq(Aggregator.provider_timed_out(0, 30), false, "exactly at the limit is not a timeout")
    T.eq(Aggregator.provider_timed_out(0, 31), true)
    T.eq(Aggregator.budget_exceeded(0, 60), false)
    T.eq(Aggregator.budget_exceeded(0, 61), true)
    T.eq(Aggregator.budget_exceeded(0, 11, 10), true, "budget is configurable")

    local snapshot = Fixtures.github()
    snapshot.fetched_at = NOW - 120
    local state, err = Errors.classify({ timed_out = true, exit_code = 124 })
    local kept = Schema.apply_failure(snapshot, { state = state, error = err }, { now = NOW })

    T.eq(state, "network_error")
    T.eq(kept.data_state, "stale")
    T.eq(#kept.items, 4, "a timed-out cycle must not wipe the dashboard")
end)

