--[[
lib/schema.luau — ProviderSnapshot schema v1: construction, normalization,
validation, derived counts.

Normative: docs/DATA-MODEL.md §3–§9, docs/SPEC.md REQ-D-001 … REQ-D-010.

Domain module (M1): pure data plus pure functions. No Noctalia Runtime API, no
forge SDK, no network.
Tests: T-D-001 … T-D-005 (docs/TRACEABILITY.md).

Two levels of distrust:
  * normalize() is tolerant — it fixes provider sloppiness and never throws on
    plain-data input, so one bad provider cannot break the aggregator;
  * validate() is strict — it reports error-severity problems the aggregator
    must refuse to publish.
]]

local Capabilities = require("./capabilities")
local Errors = require("./errors")
local Urgency = require("./urgency")

local Schema = {}

Schema.VERSION = 1

Schema.KINDS = { "notification", "review", "pull_request", "merge_request", "issue", "ci_run" }

-- Count keys: `attention` is normative (REQ-D-005); the rest are signal badges.
Schema.COUNT_KEYS = { "attention", "notifications", "reviews", "work_items", "issues", "ci" }

-- REQ-D-001: minimum fields of a ProviderSnapshot.
Schema.SNAPSHOT_FIELDS = {
    "schema_version",
    "provider",
    "host",
    "account",
    "state",
    "capabilities",
    "counts",
    "items",
    "activity",
    "fetched_at",
}

-- REQ-D-006: required fields of a signal item. `provider` / `host` are
-- source-level and defaulted from the snapshot; `read` applies where applicable.
Schema.ITEM_FIELDS = {
    "id",
    "entity_id",
    "kind",
    "title",
    "url",
    "repo",
    "updated_at",
    "urgency",
    "attention",
}

-- States in which identity may legitimately be empty (REQ-D-010).
Schema.ANONYMOUS_STATES = { auth_required = true, unavailable = true }

--[[
Stale policy constants (REQ-A-009 / ADR-011 / ADR-012).

`data_state` is derived by the domain, never guessed by a provider:
  success                    -> "fresh"
  failure + usable last-good -> "stale" (+ `stale_expired` past the window)
  failure + nothing to serve -> "empty"
  auth_required/unavailable  -> "empty" and privileged items cleared

ADR-012 is the stricter rule and wins over REQ-A-009's optional "may keep
last-good inside the window" behaviour for an unauthenticated source.
]]
Schema.STALE_WINDOW_SEC = 30 * 60
Schema.LAST_GOOD_MAX_AGE_SEC = 24 * 60 * 60

-- Which failures keep last-good on screen and which clear it.
-- `ready = "fresh"` documents the intended non-failure outcome; `apply_failure`
-- never receives a `ready` state (that path is `Schema.apply_success`).
Schema.POLICY = {
    ready = "fresh",
    auth_required = "clear",
    unavailable = "clear",
    rate_limited = "serve_stale",
    network_error = "serve_stale",
    api_error = "serve_stale",
    bad_response = "serve_stale",
    loading = "serve_stale",
}


local function contains(list, value)
    for _, entry in ipairs(list) do
        if entry == value then
            return true
        end
    end
    return false
end

local function is_integer(value)
    return type(value) == "number" and value % 1 == 0
end

-- Sequence-like table check: an empty table counts as an array (review P2).
local function is_array(value)
    return type(value) == "table" and (#value > 0 or next(value) == nil)
end


-- Fresh zeroed counter table.
function Schema.new_counts()
    local counts = {}
    for _, key in ipairs(Schema.COUNT_KEYS) do
        counts[key] = 0
    end
    return counts
end

--[[
source_key(provider, host, account) -> "provider|host|account"

Canonical storage/identity key (docs/DATA-MODEL.md §6). Provider and host are
lowercased. An empty account becomes "_" (anonymous / not authenticated).
]]
function Schema.source_key(provider, host, account)
    local account_part = account
    if account_part == nil or account_part == "" then
        account_part = "_"
    end
    return table.concat({
        string.lower(tostring(provider or "")),
        string.lower(tostring(host or "")),
        tostring(account_part),
    }, "|")
end

function Schema.parse_source_key(key)
    if type(key) ~= "string" then
        return nil
    end
    local provider, host, account = string.match(key, "^([^|]*)|([^|]*)|(.*)$")
    if provider == nil then
        return nil
    end
    if account == "_" then
        account = ""
    end
    return { provider = provider, host = host, account = account }
end

-- The underlying work object of a signal (ADR-010); `id` is the last resort.
function Schema.attention_entity_id(item)
    if type(item) ~= "table" then
        return nil
    end
    return item.entity_id or item.id
end

--[[
is_usable(state, data_state) -> bool

True when a source may contribute privileged data (REQ-A-002): ready, or stale
last-good. `data_state = "empty"` never contributes, which is what makes auth
loss actually clear the queue (ADR-012).
]]
function Schema.is_usable(state, data_state)
    if data_state == "empty" then
        return false
    end
    return state == "ready" or data_state == "stale"
end

-- Distinct entity_id count among attention signals (REQ-D-005 / ADR-010).
function Schema.count_attention(items)
    local seen, total = {}, 0
    for _, item in ipairs(items or {}) do
        if type(item) == "table" and item.attention == true then
            local entity = Schema.attention_entity_id(item)
            if entity ~= nil and not seen[entity] then
                seen[entity] = true
                total = total + 1
            end
        end
    end
    return total
end

--[[
counts_from_items(items) -> counts

Signal-level counts per capability plus the normative distinct-entity attention
count. One PR appearing as notification + review + failing CI contributes 1.
]]
function Schema.counts_from_items(items)
    local counts = Schema.new_counts()
    local seen = {}
    for _, item in ipairs(items or {}) do
        if type(item) == "table" then
            local capability = Capabilities.capability_for_kind(item.kind)
            if capability ~= nil and counts[capability] ~= nil then
                counts[capability] = counts[capability] + 1
            end
            if item.attention == true then
                local entity = Schema.attention_entity_id(item)
                if entity ~= nil and not seen[entity] then
                    seen[entity] = true
                    counts.attention = counts.attention + 1
                end
            end
        end
    end
    return counts
end

-- Reported counters are trusted only where they are valid integers; `attention`
-- is always recomputed because REQ-D-005 makes it an invariant.
function Schema.merge_counts(reported, derived)
    local counts = Schema.new_counts()
    for _, key in ipairs(Schema.COUNT_KEYS) do
        local value = type(reported) == "table" and reported[key] or nil
        if is_integer(value) and value >= 0 then
            counts[key] = value
        else
            counts[key] = derived[key]
        end
    end
    counts.attention = derived.attention
    return counts
end

-- Only http(s) may ever be handed to the opener (docs/DATA-MODEL.md §13).
function Schema.is_openable_url(url)
    if url == nil or url == "" then
        return true
    end
    if type(url) ~= "string" then
        return false
    end
    return string.sub(url, 1, 7) == "http://" or string.sub(url, 1, 8) == "https://"
end

-- Signal items are copied, never mutated in place: the aggregator holds both the
-- raw snapshot and the normalized one, and callers may still hold the fixture.
local function normalize_item(item, provider, host)
    if type(item) ~= "table" then
        return nil
    end
    local normalized = {}
    for key, value in pairs(item) do
        normalized[key] = value
    end
    normalized.id = item.id or ""
    -- Fallback keeps the tolerant path defined; validate() still rejects a
    -- missing entity_id as an error-severity source problem.
    normalized.entity_id = item.entity_id or normalized.id
    normalized.kind = item.kind or ""
    normalized.title = item.title or ""
    normalized.url = item.url or ""
    normalized.repo = item.repo or ""
    normalized.updated_at = is_integer(item.updated_at) and item.updated_at or 0
    normalized.attention = item.attention == true
    normalized.read = item.read == true
    normalized.provider = item.provider or provider
    normalized.host = item.host or host
    return normalized
end

--[[
normalize(snapshot) -> normalized, report

report = { aliased_capabilities = { [input] = canonical },
           unknown_capabilities = { input, ... } }

Tolerant by design (REQ-A-004): plain-data input never throws, defaults are
filled, capabilities become canonical, and `counts.attention` is recomputed so
REQ-D-005 always holds in the published model. Identity fields are never invented.
]]
function Schema.normalize(snapshot)
    local source = type(snapshot) == "table" and snapshot or {}
    local caps, capability_report = Capabilities.normalize(source.capabilities)
    local provider = string.lower(tostring(source.provider or ""))
    local host = string.lower(tostring(source.host or ""))

    local items = {}
    if type(source.items) == "table" then
        for _, item in ipairs(source.items) do
            local normalized_item = normalize_item(item, provider, host)
            if normalized_item ~= nil then
                items[#items + 1] = normalized_item
            end
        end
    end

    local derived = Schema.counts_from_items(items)
    local normalized = {
        schema_version = is_integer(source.schema_version) and source.schema_version or Schema.VERSION,
        provider = provider,
        host = host,
        account = tostring(source.account or ""),
        state = source.state or "loading",
        data_state = source.data_state or "empty",
        capabilities = caps,
        counts = Schema.merge_counts(source.counts, derived),
        items = items,
        activity = is_array(source.activity) and source.activity or {},
        fetched_at = is_integer(source.fetched_at) and source.fetched_at or 0,
        last_attempt_at = is_integer(source.last_attempt_at) and source.last_attempt_at or 0,
        message = tostring(source.message or ""),
        error = type(source.error) == "table" and source.error or nil,
        stale_since = is_integer(source.stale_since) and source.stale_since or nil,
        stale_expired = source.stale_expired == true or nil,
    }
    normalized.source_key = source.source_key
        or Schema.source_key(normalized.provider, normalized.host, normalized.account)

    return normalized, {
        aliased_capabilities = capability_report.aliased,
        unknown_capabilities = capability_report.unknown,
    }
end

--[[
validate(snapshot) -> ok, problems

problems[i] = { severity, code, path, message }

  error → the snapshot must not be trusted; the aggregator degrades the source
          to bad_response / data_state = "empty" instead of publishing it
  warn  → recoverable provider sloppiness that normalize() already fixes
          (capability aliases, stale counts, newer schema_version)

Validation runs on the raw snapshot so provider mistakes stay visible as
diagnostics, instead of being silently repaired and forgotten.
]]
function Schema.validate(snapshot)
    local problems = {}
    local function problem(severity, code, path, message)
        problems[#problems + 1] = {
            severity = severity,
            code = code,
            path = path,
            message = message,
        }
    end

    if type(snapshot) ~= "table" then
        problem("error", "not_a_table", "", "snapshot must be a table")
        return false, problems
    end

    for _, field in ipairs(Schema.SNAPSHOT_FIELDS) do
        if snapshot[field] == nil then
            problem("error", "missing_field", field, "required field missing: " .. field)
        end
    end

    local version = snapshot.schema_version
    if version ~= nil then
        if not is_integer(version) or version < 1 then
            problem("error", "bad_schema_version", "schema_version", "schema_version must be an integer >= 1")
        elseif version > Schema.VERSION then
            problem("warn", "future_schema_version", "schema_version", "snapshot uses a newer schema_version")
        end
    end

    if snapshot.state == "stale" then
        problem("error", "stale_is_not_a_state", "state",
            "use data_state = \"stale\"; state must be a lifecycle state (ADR-011)")
    elseif snapshot.state ~= nil and not Errors.is_state(snapshot.state) then
        problem("error", "unknown_state", "state", "unknown lifecycle state: " .. tostring(snapshot.state))
    end

    if snapshot.data_state ~= nil and not Errors.is_data_state(snapshot.data_state) then
        problem("error", "unknown_data_state", "data_state", "unknown data_state: " .. tostring(snapshot.data_state))
    end

    if snapshot.stale_expired == true and snapshot.data_state ~= "stale" then
        problem("warn", "stale_expired_without_stale_data", "stale_expired",
            "stale_expired only applies when data_state == \"stale\"")
    end

    -- REQ-D-010: identity is only allowed to be empty when not authenticated.
    if snapshot.state ~= nil and not Schema.ANONYMOUS_STATES[snapshot.state] then
        if tostring(snapshot.host or "") == "" then
            problem("error", "identity_host_missing", "host", "host required unless state is auth_required/unavailable")
        end
        if tostring(snapshot.account or "") == "" then
            problem("error", "identity_account_missing", "account",
                "account required unless state is auth_required/unavailable")
        end
    end

    if type(snapshot.capabilities) == "table" then
        for key, value in pairs(snapshot.capabilities) do
            if Capabilities.is_forbidden(key) then
                problem("warn", "forbidden_capability_key", "capabilities." .. tostring(key),
                    "forge-specific capability key; canonical key is " .. tostring(Capabilities.ALIASES[key]))
            elseif not Capabilities.is_canonical(key) then
                problem("warn", "unknown_capability_key", "capabilities." .. tostring(key), "not a canonical capability key")
            elseif type(value) ~= "boolean" then
                problem("warn", "capability_not_boolean", "capabilities." .. tostring(key), "capability values must be booleans")
            end
        end
    end

    if type(snapshot.items) == "table" then
        for index, item in ipairs(snapshot.items) do
            local path = string.format("items[%d]", index)
            if type(item) ~= "table" then
                problem("error", "item_not_a_table", path, "item must be a table")
            else
                for _, field in ipairs(Schema.ITEM_FIELDS) do
                    if item[field] == nil then
                        problem("error", "item_missing_field", path .. "." .. field, "required item field missing")
                    end
                end
                if item.kind ~= nil and not contains(Schema.KINDS, item.kind) then
                    problem("error", "item_unknown_kind", path .. ".kind", "unknown kind: " .. tostring(item.kind))
                end
                if item.urgency ~= nil and not Urgency.is_valid(item.urgency) then
                    problem("error", "item_unknown_urgency", path .. ".urgency", "unknown urgency: " .. tostring(item.urgency))
                end
                if item.attention ~= nil and type(item.attention) ~= "boolean" then
                    problem("error", "item_attention_not_boolean", path .. ".attention", "attention must be boolean")
                end
                if item.url ~= nil and not Schema.is_openable_url(item.url) then
                    problem("error", "item_url_scheme", path .. ".url", "url must be http(s) or empty (DATA-MODEL §13)")
                end
            end
        end

        -- REQ-D-005: reported attention must equal distinct entity_id count.
        local expected = Schema.count_attention(snapshot.items)
        local reported = type(snapshot.counts) == "table" and snapshot.counts.attention or nil
        if is_integer(reported) and reported ~= expected then
            problem("warn", "attention_count_mismatch", "counts.attention",
                string.format("reported %d, distinct entity_id count %d", reported, expected))
        end
    end

    local ok = true
    for _, entry in ipairs(problems) do
        if entry.severity == "error" then
            ok = false
            break
        end
    end
    return ok, problems
end


-- Policy for a lifecycle state. Unknown states keep last-good rather than
-- discarding data because of an unclassified error.
function Schema.policy_for(state)
    return Schema.POLICY[state] or "serve_stale"
end

--[[
staleness(snapshot, now, window_sec?) -> { data_state, age_sec, stale_since, expired }

Banner input for the widget/panel, derived from the model alone (REQ-A-007): the UI
never needs to know which provider produced the snapshot.
]]
function Schema.staleness(snapshot, now, window_sec)
    local window = window_sec or Schema.STALE_WINDOW_SEC
    local is_table = type(snapshot) == "table"
    local fetched_at = (is_table and snapshot.fetched_at) or 0
    local age = (now or 0) - fetched_at
    if age < 0 then
        age = 0
    end
    local data_state = is_table and snapshot.data_state or "empty"
    return {
        data_state = data_state,
        age_sec = age,
        stale_since = is_table and snapshot.stale_since or nil,
        expired = data_state == "stale" and age > window,
    }
end

local function shallow_copy(snapshot)
    local copy = {}
    for key, value in pairs(snapshot) do
        copy[key] = value
    end
    return copy
end

--[[
apply_success(snapshot, now) -> snapshot

A successful fetch: fresh data, no error, no staleness markers.
]]
function Schema.apply_success(snapshot, now)
    local updated = shallow_copy(type(snapshot) == "table" and snapshot or {})
    updated.state = "ready"
    updated.data_state = "fresh"
    updated.stale_since = nil
    updated.stale_expired = nil
    updated.error = nil
    if now ~= nil then
        updated.fetched_at = now
        updated.last_attempt_at = now
    end
    return updated
end

--[[
apply_failure(snapshot, failure, opts) -> snapshot

failure = { state, error?, message? }  (state from Errors.classify)
opts    = { now?, stale_window_sec? }

Never mutates the input. Returns a new snapshot whose `data_state` follows the
policy table:
  * clear policy        -> items/activity dropped, counts zeroed, no stale markers;
  * serve_stale + items -> `data_state = "stale"`, `stale_expired` past the window;
  * nothing to serve    -> `data_state = "empty"`.

This is where "one bad provider must not poison others" becomes concrete: the
service calls this per source and publishes the result, so a rate-limited provider
keeps its last-good while an unauthenticated one publishes nothing.
]]
function Schema.apply_failure(snapshot, failure, opts)
    opts = opts or {}
    local base = type(snapshot) == "table" and snapshot or Schema.normalize({})
    local updated = shallow_copy(base)
    local state = (failure and failure.state) or "api_error"

    updated.state = state
    if opts.now ~= nil then
        updated.last_attempt_at = opts.now
    end
    if failure and failure.error ~= nil then
        updated.error = failure.error
    end
    if failure and failure.message ~= nil then
        updated.message = failure.message
    end

    local items = type(updated.items) == "table" and updated.items or {}
    if Schema.policy_for(state) == "clear" or #items == 0 then
        updated.data_state = "empty"
        updated.items = {}
        updated.activity = {}
        updated.counts = Schema.new_counts()
        updated.stale_since = nil
        updated.stale_expired = nil
        return updated
    end

    local window = opts.stale_window_sec or Schema.STALE_WINDOW_SEC
    local reference = opts.now or base.fetched_at or 0
    updated.data_state = "stale"
    updated.stale_since = base.stale_since or opts.now
    updated.stale_expired = (reference - (base.fetched_at or 0)) > window
    return updated
end

--[[
should_discard_last_good(snapshot, now, opts) -> bool

Retention (DATA-MODEL §11): a persisted last-good older than
`last_good_max_age_sec` (default 24h) — or without a usable timestamp — must be
discarded on load instead of being merged into the next overview.
]]
function Schema.should_discard_last_good(snapshot, now, opts)
    opts = opts or {}
    if type(snapshot) ~= "table" then
        return true
    end
    local fetched_at = snapshot.fetched_at
    if type(fetched_at) ~= "number" or fetched_at <= 0 then
        return true
    end
    local max_age = opts.last_good_max_age_sec or Schema.LAST_GOOD_MAX_AGE_SEC
    return ((now or 0) - fetched_at) > max_age
end


return Schema


