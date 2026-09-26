--[[
tests/test_schema.luau — domain schema tests.

Covers: REQ-D-001 … REQ-D-010 with test ids T-D-001 … T-D-005
(docs/TRACEABILITY.md). Every case states which contract it protects, because a
test that cannot name its requirement tends to become decoration.
]]

local T = require("./harness")
local Helpers = require("./helpers")
local Fixtures = require("./fixtures")
local Schema = require("../lib/schema")
local Capabilities = require("../lib/capabilities")
local Errors = require("../lib/errors")
local Urgency = require("../lib/urgency")

T.test("T-D-001: a complete snapshot validates with no problems", function()
    local snapshot = Fixtures.github()
    local ok, problems = Schema.validate(snapshot)
    T.eq(#problems, 0, "expected a clean validation, got: " .. T.render(problems))
    T.truthy(ok, "the fixture must be a valid snapshot")
end)

T.test("T-D-001: every missing required snapshot field is reported", function()
    local ok, problems = Schema.validate({})
    T.falsy(ok, "an empty table is not a snapshot")
    T.eq(#Helpers.severity(problems, "error"), #Schema.SNAPSHOT_FIELDS,
        "one error per missing required field")

    local reported = {}
    for _, problem in ipairs(problems) do
        if problem.code == "missing_field" then
            reported[problem.path] = true
        end
    end
    for _, field in ipairs(Schema.SNAPSHOT_FIELDS) do
        T.truthy(reported[field], "missing_field problem expected for " .. field)
    end
end)

T.test("T-D-001: item contracts are enforced (fields, kind, urgency, url scheme)", function()
    local snapshot = Fixtures.github()
    snapshot.items[1].url = "javascript:alert(1)"
    snapshot.items[2].kind = "pull_requests"
    snapshot.items[3].urgency = "urgent"
    snapshot.items[4].title = nil

    local ok, problems = Schema.validate(snapshot)
    T.falsy(ok, "invalid items must fail validation")
    T.truthy(Helpers.has(problems, "item_url_scheme"), "only http(s) may be opened (DATA-MODEL §13)")
    T.truthy(Helpers.has(problems, "item_unknown_kind"), "kind must come from the canonical list")
    T.truthy(Helpers.has(problems, "item_unknown_urgency"), "urgency must be a known rank")
    T.truthy(Helpers.has(problems, "item_missing_field"), "required item fields are mandatory")
end)

T.test("T-D-001/REQ-D-010: identity is required unless the state is anonymous", function()
    local ready = Fixtures.github()
    ready.account = ""
    local ok, problems = Schema.validate(ready)
    T.falsy(ok, "ready state without an account must not validate")
    T.truthy(Helpers.has(problems, "identity_account_missing"))

    local anonymous = Fixtures.anonymous()
    local anonymous_ok, anonymous_problems = Schema.validate(anonymous)
    T.truthy(anonymous_ok, "auth_required may omit identity: " .. T.render(anonymous_problems))
end)

T.test("T-D-001: source_key is provider|host|account with an anonymous placeholder", function()
    T.eq(Schema.source_key("GitHub", "GitHub.com", "alice"), "github|github.com|alice")
    T.eq(Schema.source_key("github", "github.com", ""), "github|github.com|_")
    T.eq(Schema.source_key("github", "github.com", nil), "github|github.com|_")
    T.eq(Schema.parse_source_key("github|github.com|_"),
        { provider = "github", host = "github.com", account = "" })
end)

T.test("T-D-002: failure taxonomy maps evidence, not exit codes", function()
    local cases = {
        { "unauthenticated CLI",
            { exit_code = 1, stderr = "To get started with GitHub CLI, please run: gh auth login" }, "auth_required" },
        { "rate limit message",
            { exit_code = 1, stderr = "API rate limit exceeded for user ID 1" }, "rate_limited" },
        { "403 without rate wording",
            { exit_code = 1, stderr = "HTTP 403: Resource not accessible by integration" }, "api_error" },
        { "DNS failure",
            { exit_code = 1, stderr = "dial tcp: lookup api.github.com: no such host" }, "network_error" },
        { "timeout", { timed_out = true, exit_code = 124 }, "network_error" },
        { "unparseable output", { parse = true, exit_code = 0, stdout = "<html>not json</html>" }, "bad_response" },
        { "json decode text", { exit_code = 1, stderr = "unexpected end of JSON input" }, "bad_response" },
        { "exit 429", { exit_code = 429 }, "rate_limited" },
        { "retry_after only", { exit_code = 1, retry_after = 60 }, "rate_limited" },
        { "CLI missing", { cli_missing = true }, "unavailable" },
        { "provider disabled", { disabled = true }, "unavailable" },
        { "HTTP 401", { exit_code = 401 }, "auth_required" },
        { "unknown CLI error", { exit_code = 2, stderr = "unknown flag: --nope" }, "api_error" },
        { "exit 0", { exit_code = 0 }, "ready" },
    }
    for _, case in ipairs(cases) do
        T.eq(Errors.classify(case[2]), case[3], "classification case: " .. case[1])
    end

    local state, err = Errors.classify(nil)
    T.eq(state, "ready", "no failure at all means success")
    T.eq(err, nil)
end)

T.test("T-D-002: a bare non-zero exit never becomes auth_required", function()
    T.eq(Errors.classify({ exit_code = 1 }), "api_error")
    T.eq(Errors.is_retryable("api_error"), true)
    T.eq(Errors.is_retryable("auth_required"), false)
    T.eq(Errors.is_retryable("bad_response"), false)
end)

T.test("T-D-002: staleness is data_state, never a lifecycle state", function()
    T.eq(Errors.is_state("stale"), false, "ADR-011: no state named stale")
    T.eq(Errors.is_data_state("stale"), true)

    local invalid_ok, problems = Schema.validate(Fixtures.wrong_state())
    T.falsy(invalid_ok, "state = \"stale\" must be refused")
    T.truthy(Helpers.has(problems, "stale_is_not_a_state"))

    local stale_ok, stale_problems = Schema.validate(Fixtures.rate_limited_stale())
    T.truthy(stale_ok, "rate_limited + data_state=stale is the correct shape: " .. T.render(stale_problems))
end)

T.test("T-D-002: the structured error object follows DATA-MODEL §8", function()
    T.eq(Errors.new("rate_limited", "API rate limit exceeded", { retry_after = 30, exit_code = 1 }), {
        code = "rate_limited",
        message = "API rate limit exceeded",
        retryable = true,
        retry_after = 30,
        exit_code = 1,
    })
    T.eq(Errors.new("auth_required", "run: gh auth login"), {
        code = "auth_required",
        message = "run: gh auth login",
        retryable = false,
    })
    T.eq(Errors.new("bad_response", "decode failed", { exit_code = 0 }), {
        code = "bad_response",
        message = "decode failed",
        retryable = false,
        exit_code = 0,
    })
end)

T.test("T-D-003: forge-specific capability keys are aliased and reported", function()
    local caps, report = Capabilities.normalize({
        notifications = true,
        pull_requests = true,
        merge_requests = false,
        actions = true,
        pipelines = false,
        made_up = true,
    })
    T.eq(caps.notifications, true)
    T.eq(caps.work_items, true, "pull_requests/merge_requests -> work_items, true wins")
    T.eq(caps.ci, true, "actions/pipelines -> ci, true wins")
    T.eq(caps.made_up, nil, "unknown keys never reach capabilities")
    T.eq(report.aliased.pull_requests, "work_items")
    T.eq(report.aliased.pipelines, "ci")
    T.eq(report.unknown, { "made_up" })

    for key in pairs(caps) do
        T.truthy(Capabilities.is_canonical(key), "non-canonical capability key survived: " .. tostring(key))
    end
end)

T.test("T-D-003: forbidden capability keys are warnings, not fatal errors", function()
    local ok, problems = Schema.validate(Fixtures.sloppy())
    T.truthy(ok, "a sloppy but usable source is still publishable")
    T.eq(#Helpers.severity(problems, "error"), 0)

    local forbidden = 0
    for _, problem in ipairs(problems) do
        if problem.code == "forbidden_capability_key" then
            forbidden = forbidden + 1
        end
    end
    T.eq(forbidden, 2, "pull_requests and pipelines must both be flagged")
    T.truthy(Helpers.has(problems, "attention_count_mismatch"))
end)

T.test("T-D-005: attention counts distinct entity_id, not signals", function()
    local items = Fixtures.github().items
    T.eq(#items, 4)
    T.eq(Schema.count_attention(items), 1, "three signals on one entity; the issue is attention=false")
    T.eq(Schema.counts_from_items(items), {
        attention = 1,
        notifications = 1,
        reviews = 1,
        work_items = 0,
        issues = 1,
        ci = 1,
    })
end)

T.test("T-D-005: normalize repairs a provider's wrong attention counter", function()
    local normalized, report = Schema.normalize(Fixtures.sloppy())
    T.eq(normalized.counts.attention, 1, "REQ-D-005 is an invariant, not provider opinion")
    T.eq(normalized.capabilities.work_items, true)
    T.eq(normalized.capabilities.pull_requests, nil)
    T.eq(normalized.capabilities.contributions, false)
    T.eq(report.aliased_capabilities.pull_requests, "work_items")
    T.eq(report.unknown_capabilities, {})
end)

T.test("T-D-004: urgency order is normative and unknown urgency sorts last", function()
    T.eq(Urgency.rank("critical"), 4)
    T.eq(Urgency.rank("high"), 3)
    T.eq(Urgency.rank("normal"), 2)
    T.eq(Urgency.rank("low"), 1)
    T.eq(Urgency.rank("unheard-of"), 0, "unknown urgency is never promoted")

    local list = {
        { id = "c", urgency = "low", updated_at = 1 },
        { id = "a", urgency = "critical", updated_at = 1 },
        { id = "e", urgency = "unheard-of", updated_at = 99 },
        { id = "b", urgency = "high", updated_at = 1 },
        { id = "d", urgency = "normal", updated_at = 1 },
    }
    table.sort(list, Urgency.compare)
    local order = {}
    for _, item in ipairs(list) do
        order[#order + 1] = item.id
    end
    T.eq(order, { "a", "b", "d", "c", "e" }, "critical > high > normal > low > unknown")
end)


