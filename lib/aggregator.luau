--[[
lib/aggregator.luau — DashboardAggregator: ProviderSnapshots → unified overview.

Normative: docs/DATA-MODEL.md §10, docs/SPEC.md §2 (REQ-A-001 … REQ-A-009),
ADR-010 (attention identity), ADR-014 (sources[] multi-host shape from M1).

Domain module (M1): pure data plus pure functions. No Noctalia Runtime API, no
forge SDK, no network, no timers. The service injects time and refresh identity.
Tests: T-A-001 … T-A-005 (docs/TRACEABILITY.md); T-A-006 lands with M1.4.

Design rules enforced here:
  * one aggregator, one overview — providers only ever produce snapshots;
  * a broken source degrades to bad_response and is excluded, it never poisons
    other sources (REQ-A-004);
  * the UI gets tabs, counts, capabilities and attention without asking which
    forge produced them (REQ-A-006, REQ-A-007).
]]

local Capabilities = require("./capabilities")
local Errors = require("./errors")
local Schema = require("./schema")
local Urgency = require("./urgency")

local Aggregator = {}

Aggregator.MODE_ALL = "all"
Aggregator.DEFAULT_STALE_WINDOW_SEC = 30 * 60

local DashboardAggregator = {}
DashboardAggregator.__index = DashboardAggregator

local function is_integer(value)
    return type(value) == "number" and value % 1 == 0
end

local function contains(list, value)
    for _, entry in ipairs(list) do
        if entry == value then
            return true
        end
    end
    return false
end

--[[
new(opts) -> aggregator

  schema_version   : overview schema version (default Schema.VERSION)
  stale_window_sec : last-good window used by the M1.4 stale policy (REQ-A-009)
  now              : function() -> unix seconds, injected by the service
  refresh_id       : current accepted refresh generation (ADR-013)
]]
function Aggregator.new(opts)
    opts = opts or {}
    return setmetatable({
        schema_version = opts.schema_version or Schema.VERSION,
        stale_window_sec = opts.stale_window_sec or Aggregator.DEFAULT_STALE_WINDOW_SEC,
        now = opts.now,
        -- `current_refresh_id` is the generation being collected; results tagged
        -- with it are the only ones allowed to publish (ADR-013).
        current_refresh_id = opts.refresh_id or 0,
        accepted_refresh_id = opts.refresh_id or 0,
    }, DashboardAggregator)
end


function Aggregator.mode_key(mode)
    if mode == nil or mode == Aggregator.MODE_ALL then
        return Aggregator.MODE_ALL
    end
    if type(mode) == "string" then
        return mode
    end
    if type(mode) == "table" then
        if mode.source_key ~= nil then
            return mode.source_key
        end
        return table.concat({
            mode.provider or "*",
            mode.host or "*",
            mode.account or "*",
        }, "|")
    end
    return Aggregator.MODE_ALL
end

--[[
matches_mode(source, mode) -> bool

mode: "all" | provider id ("github") | source_key | { provider?, host?, account? }
]]
function Aggregator.matches_mode(source, mode)
    if mode == nil or mode == Aggregator.MODE_ALL then
        return true
    end
    if type(mode) == "string" then
        return source.provider == mode or source.source_key == mode
    end
    if type(mode) == "table" then
        if mode.source_key ~= nil and source.source_key ~= mode.source_key then
            return false
        end
        if mode.provider ~= nil and source.provider ~= mode.provider then
            return false
        end
        if mode.host ~= nil and source.host ~= string.lower(mode.host) then
            return false
        end
        if mode.account ~= nil and source.account ~= mode.account then
            return false
        end
        return true
    end
    return false
end

-- Tab list for the panel: "all" plus providers in service-provided order. The
-- panel renders these without knowing any provider name (REQ-A-007).
function Aggregator.modes(overview)
    local modes = { Aggregator.MODE_ALL }
    for _, provider in ipairs((overview and overview.providers) or {}) do
        modes[#modes + 1] = provider
    end
    return modes
end

-- A source entry is the plain-data view of one snapshot plus the diagnostics the
-- UI may show ("github: rate limited, showing data from 12m ago").
local function degraded_entry(provider, host, account, error_object, problems)
    return {
        provider = provider or "unknown",
        host = host or "",
        account = account or "",
        source_key = Schema.source_key(provider or "unknown", host or "", account or ""),
        state = "bad_response",
        data_state = "empty",
        capabilities = Capabilities.empty(),
        counts = Schema.new_counts(),
        items = {},
        activity = {},
        error = error_object,
        message = "",
        problems = problems or {},
        valid = false,
        item_count = 0,
        fetched_at = 0,
        last_attempt_at = 0,
    }
end

--[[
build_source(raw) -> entry

Never throws (REQ-A-004). A structurally broken snapshot is reported as
bad_response with zero counts rather than taking the whole overview down.
]]
local function build_source(raw)
    if type(raw) ~= "table" then
        local problem = {
            severity = "error",
            code = "not_a_table",
            path = "",
            message = "snapshot is not a table",
        }
        return degraded_entry("unknown", "", "", Errors.new("bad_response", problem.message), { problem })
    end

    local ok, normalized = pcall(Schema.normalize, raw)
    if not ok or type(normalized) ~= "table" then
        local message = tostring(normalized)
        local problem = {
            severity = "error",
            code = "normalize_failed",
            path = "",
            message = message,
        }
        return degraded_entry(raw.provider, raw.host, raw.account,
            Errors.new("bad_response", "snapshot could not be normalized: " .. message), { problem })
    end

    local valid, problems = Schema.validate(raw)
    local entry = {
        provider = normalized.provider,
        host = normalized.host,
        account = normalized.account,
        source_key = normalized.source_key,
        state = normalized.state,
        data_state = normalized.data_state,
        stale_since = normalized.stale_since,
        stale_expired = normalized.stale_expired,
        capabilities = normalized.capabilities,
        counts = normalized.counts,
        items = normalized.items,
        activity = normalized.activity,
        error = normalized.error,
        message = normalized.message,
        fetched_at = normalized.fetched_at,
        last_attempt_at = normalized.last_attempt_at,
        item_count = #normalized.items,
        problems = problems,
        valid = valid,
        snapshot = normalized,
    }

    if not valid then
        local messages = {}
        for _, item in ipairs(problems) do
            if item.severity == "error" then
                messages[#messages + 1] = item.path .. ": " .. item.message
            end
        end
        entry.state = "bad_response"
        entry.data_state = "empty"
        entry.counts = Schema.new_counts()
        entry.items = {}
        entry.item_count = 0
        entry.error = Errors.new("bad_response", table.concat(messages, "; "))
    end

    return entry
end

--[[
collect_attention(entries) -> attention[]

Entity-level queue (REQ-A-002 / ADR-010): one entry per distinct entity_id, its
face taken from the highest-urgency signal, sorted by Urgency.compare. Only
usable sources contribute, so auth loss clears the queue (ADR-012).
]]
local function collect_attention(entries)
    local by_entity, order = {}, {}
    -- The id of the signal that currently owns the entity face. Kept in a side
    -- table so the published entity stays plain contract data (no internal keys).
    local face_ids = {}
    for _, entry in ipairs(entries) do
        if Schema.is_usable(entry.state, entry.data_state) then
            for _, item in ipairs(entry.items) do
                if item.attention == true then
                    local entity_id = Schema.attention_entity_id(item)
                    if entity_id ~= nil then
                        local entity = by_entity[entity_id]
                        if entity == nil then
                            entity = {
                                entity_id = entity_id,
                                urgency = item.urgency,
                                title = item.title,
                                url = item.url,
                                repo = item.repo,
                                kind = item.kind,
                                kinds = {},
                                provider = item.provider or entry.provider,
                                host = item.host or entry.host,
                                updated_at = item.updated_at or 0,
                                signal_ids = {},
                                signal_count = 0,
                            }
                            by_entity[entity_id] = entity
                            order[#order + 1] = entity_id
                            face_ids[entity_id] = tostring(item.id or "")
                        end
                        local item_rank = Urgency.rank(item.urgency)
                        local entity_rank = Urgency.rank(entity.urgency)
                        local item_updated = item.updated_at or 0
                        local item_id = tostring(item.id or "")
                        -- Full ties are broken by the smaller signal id so the face
                        -- never depends on intra-source item order.
                        local better = item_rank > entity_rank
                            or (item_rank == entity_rank and item_updated > entity.updated_at)
                            or (item_rank == entity_rank and item_updated == entity.updated_at
                                and item_id < (face_ids[entity_id] or ""))
                        if better then
                            entity.urgency = item.urgency
                            entity.title = item.title
                            entity.url = item.url
                            entity.repo = item.repo
                            entity.kind = item.kind
                            entity.provider = item.provider or entry.provider
                            entity.host = item.host or entry.host
                            face_ids[entity_id] = item_id
                        end
                        if item_updated > entity.updated_at then
                            entity.updated_at = item_updated
                        end

                        if not contains(entity.kinds, item.kind) then
                            entity.kinds[#entity.kinds + 1] = item.kind
                        end
                        entity.signal_ids[#entity.signal_ids + 1] = tostring(item.id or "")
                        entity.signal_count = entity.signal_count + 1
                    end
                end
            end
        end
    end

    local attention = {}
    for _, entity_id in ipairs(order) do
        local entity = by_entity[entity_id]
        table.sort(entity.kinds)
        table.sort(entity.signal_ids)
        attention[#attention + 1] = entity
    end
    table.sort(attention, Urgency.compare)
    return attention
end

-- REQ-A-003: only sources that are not unavailable and still hold data contribute.
local function counts_eligible(entry)
    if entry.state == "unavailable" then
        return false
    end
    return entry.data_state ~= "empty"
end

local function sum_counts(entries)
    local counts = Schema.new_counts()
    for _, entry in ipairs(entries) do
        if counts_eligible(entry) then
            for _, key in ipairs(Schema.COUNT_KEYS) do
                local value = entry.counts[key]
                if is_integer(value) and value > 0 then
                    counts[key] = counts[key] + value
                end
            end
        end
    end
    return counts
end

--[[
build_overview(entries, opts) -> overview

Overview shape is multi-host ready (ADR-014): `sources[]` keyed by
`source_key = provider|host|account`, never a map keyed by provider.
]]
local function build_overview(entries, opts)
    local counts = sum_counts(entries)
    local attention = collect_attention(entries)

    local sources, capability_maps = {}, {}
    local providers, seen_provider = {}, {}
    local item_count = 0
    for _, entry in ipairs(entries) do
        sources[#sources + 1] = entry
        capability_maps[#capability_maps + 1] = entry.capabilities
        -- An unattributable snapshot (no provider at all) must not create a tab.
        if entry.provider ~= "" and entry.provider ~= "unknown" and not seen_provider[entry.provider] then
            seen_provider[entry.provider] = true
            providers[#providers + 1] = entry.provider
        end
        item_count = item_count + (entry.item_count or 0)
    end


    -- Attention is entity-level on the overview too (REQ-D-005 / ADR-010).
    counts.attention = #attention

    local problems = {}
    for _, entry in ipairs(entries) do
        for _, problem in ipairs(entry.problems or {}) do
            problems[#problems + 1] = {
                source_key = entry.source_key,
                severity = problem.severity,
                code = problem.code,
                path = problem.path,
                message = problem.message,
            }
        end
    end

    return {
        schema_version = opts.schema_version,
        published_at = opts.published_at,
        refresh_id = opts.refresh_id,
        mode = Aggregator.MODE_ALL,
        providers = providers,
        counts = counts,
        sources = sources,
        attention = attention,
        capabilities_union = Capabilities.union(capability_maps),
        problems = problems,
        item_count = item_count,
    }
end

--[[
merge(snapshots, opts) -> overview   (REQ-A-001)

Accepts zero or more ProviderSnapshots. Isolation is total: every source is
normalized behind pcall and validated on its own, so one broken provider cannot
clear or poison another (REQ-A-004).

opts = { published_at?, refresh_id? }
]]
function DashboardAggregator:merge(snapshots, opts)
    opts = opts or {}
    local entries = {}
    for index, raw in ipairs(snapshots or {}) do
        entries[index] = build_source(raw)
    end
    return build_overview(entries, {
        schema_version = self.schema_version,
        published_at = opts.published_at or (self.now and self.now()) or 0,
        refresh_id = opts.refresh_id or self.accepted_refresh_id,
    })
end

-- Module-level convenience for callers that keep no aggregator state.
function Aggregator.merge(snapshots, opts)
    return Aggregator.new(opts):merge(snapshots, opts)
end

-- Default refresh budget per provider and per cycle (REQ-S-005).
Aggregator.PROVIDER_TIMEOUT_SEC = 30
Aggregator.REFRESH_BUDGET_SEC = 60

--[[
begin_refresh() -> refresh_id

Starts a monotonic generation (ADR-013). Once it returns, results tagged with an
older generation must be discarded, so bounded concurrency cannot overwrite newer
state with older collector output.
]]
function DashboardAggregator:begin_refresh()
    self.current_refresh_id = (self.current_refresh_id or 0) + 1
    return self.current_refresh_id
end

-- Only results of the current generation may mutate the published overview.
function DashboardAggregator:accepts_generation(refresh_id)
    return refresh_id ~= nil and refresh_id == self.current_refresh_id
end

--[[
publish(snapshots, refresh_id, opts) -> overview | nil, reason

Publishes only current-generation results. Late results (a provider that answered
after a newer refresh started) get `nil, "stale_generation"` instead of
overwriting newer state (REQ-S-005 / ADR-013). `refresh_id == nil` means "current
generation".
]]
function DashboardAggregator:publish(snapshots, refresh_id, opts)
    local generation = refresh_id
    if generation == nil then
        generation = self.current_refresh_id
    end
    if not self:accepts_generation(generation) then
        return nil, "stale_generation"
    end
    self.accepted_refresh_id = generation
    return self:merge(snapshots, {
        published_at = opts and opts.published_at,
        refresh_id = generation,
    })
end

--[[
budget_exceeded(started_at, now, budget_sec?) -> bool
provider_timed_out(started_at, now) -> bool

Refresh timeouts (REQ-S-005): 30s per provider, 60s per cycle by default. On expiry
the service classifies the collector as timed out / `network_error` and keeps
last-good through Schema.apply_failure.
]]
function Aggregator.budget_exceeded(started_at, now, budget_sec)
    local budget = budget_sec or Aggregator.REFRESH_BUDGET_SEC
    return (now - started_at) > budget
end

function Aggregator.provider_timed_out(started_at, now)
    return (now - started_at) > Aggregator.PROVIDER_TIMEOUT_SEC
end


--[[
filter(overview, mode) -> overview   (REQ-A-006)

Pure: switching tabs re-filters the published model without re-fetching, and
rebuilds counts, attention and capabilities from the selected sources so a
filtered tab stays as honest as the full overview.

mode: "all" | provider id | source_key | { provider?, host?, account? }
]]
function Aggregator.filter(overview, mode)
    if type(overview) ~= "table" then
        error("Aggregator.filter: overview must be a table", 2)
    end
    local selected = {}
    for _, entry in ipairs(overview.sources or {}) do
        if Aggregator.matches_mode(entry, mode) then
            selected[#selected + 1] = entry
        end
    end
    local filtered = build_overview(selected, {
        schema_version = overview.schema_version or Schema.VERSION,
        published_at = overview.published_at or 0,
        refresh_id = overview.refresh_id or 0,
    })
    filtered.mode = Aggregator.mode_key(mode)
    return filtered
end


return Aggregator


