--[[
lib/errors.luau — lifecycle error taxonomy.

Normative: ADR-004 (errors distinct from auth), ADR-011 (staleness is not a
state), docs/DATA-MODEL.md §7–8, docs/SPEC.md REQ-D-003.

Domain module (M1): pure data plus pure functions. No Noctalia Runtime API, no
forge SDK, no network, no CLI invocation.
Tests: T-D-002 (docs/TRACEABILITY.md).

Why this module exists: "the CLI exited non-zero" is not the same as "you are
logged out". Mapping every failure to auth_required makes lists disappear on a
rate limit and teaches users to distrust the dashboard.
]]

local Errors = {}

-- Lifecycle states (REQ-D-003). "stale" is deliberately absent (ADR-011).
Errors.STATES = {
    "ready",
    "auth_required",
    "rate_limited",
    "network_error",
    "api_error",
    "bad_response",
    "loading",
    "unavailable",
}

-- Orthogonal data states (ADR-011).
Errors.DATA_STATES = { "fresh", "stale", "empty" }

-- Textual evidence. Matching is plain-substring on lowercased output, because
-- collectors run with LANG=C LC_ALL=C to keep these strings stable.
Errors.PATTERNS = {
    auth = {
        "gh auth login",
        "not logged in",
        "not logged into",
        "authentication required",
        "authenticate",
        "unauthorized",
        "bad credentials",
        "invalid credentials",
        "no oauth token",
        "login required",
        "to get started with github cli",
    },
    rate_limited = {
        "api rate limit exceeded",
        "rate limit",
        "rate-limit",
        "ratelimit",
        "too many requests",
        "secondary rate",
        "retry-after",
        "retry after",
    },
    network_error = {
        "timeout",
        "timed out",
        "etimedout",
        "econnreset",
        "econnrefused",
        "enotfound",
        "eai_again",
        "no such host",
        "temporary failure in name resolution",
        "could not resolve host",
        "connection reset",
        "connection refused",
        "network is unreachable",
        "tls handshake",
        "context deadline exceeded",
    },
    bad_response = {
        "unexpected end of json",
        "unexpected token",
        "invalid json",
        "failed to parse",
        "cannot decode",
        "decode error",
        "malformed",
        "schema mismatch",
        "unsupported schema_version",
    },
}

local RETRYABLE = {
    ready = false,
    auth_required = false,
    rate_limited = true,
    network_error = true,
    api_error = true,
    bad_response = false,
    loading = true,
    unavailable = false,
}

local function contains(list, value)
    for _, entry in ipairs(list) do
        if entry == value then
            return true
        end
    end
    return false
end

function Errors.is_state(state)
    return contains(Errors.STATES, state)
end

function Errors.is_data_state(data_state)
    return contains(Errors.DATA_STATES, data_state)
end

function Errors.is_retryable(state)
    return RETRYABLE[state] == true
end

-- Lowercased haystack of every textual channel a collector may produce.
function Errors.evidence_text(failure)
    if type(failure) ~= "table" then
        return ""
    end
    return string.lower(table.concat({
        tostring(failure.message or ""),
        tostring(failure.stderr or ""),
        tostring(failure.stdout or ""),
    }, "\n"))
end

function Errors.matches(text, pattern)
    return string.find(text, pattern, 1, true) ~= nil
end

-- Evidence flags per state family (used by classify; exposed for tests/logging).
function Errors.evidence(failure)
    local text = Errors.evidence_text(failure)
    local flags = {}
    for code, patterns in pairs(Errors.PATTERNS) do
        flags[code] = false
        for _, pattern in ipairs(patterns) do
            if Errors.matches(text, pattern) then
                flags[code] = true
                break
            end
        end
    end
    return flags
end

--[[
new(code, message, opts) -> structured error (docs/DATA-MODEL.md §8)

opts = { retryable?, retry_after?, exit_code? }

Retryability defaults to the taxonomy: the service uses it to decide whether a
failure is worth retrying before the next poll.
]]
function Errors.new(code, message, opts)
    opts = opts or {}
    local err = {
        code = code,
        message = message or "",
        retryable = opts.retryable ~= nil and opts.retryable or Errors.is_retryable(code),
    }
    if opts.retry_after ~= nil then
        err.retry_after = opts.retry_after
    end
    if opts.exit_code ~= nil then
        err.exit_code = opts.exit_code
    end
    return err
end

--[[
classify(failure) -> state, error|nil

  failure = nil            -> "ready", nil
  failure = {
    exit_code,             -- CLI exit status when available
    stdout, stderr, message,
    transport   = true,    -- transport failed before any CLI verdict
    timed_out   = true,    -- per-provider timeout (REQ-S-005)
    parse       = true,    -- output could not be parsed into the schema
    cli_missing = true,    -- CLI not installed
    disabled    = true,    -- provider disabled by settings
    retry_after,           -- seconds, when the forge reports it
  }

Precedence (documented and tested):
  unavailable → network_error → bad_response → rate_limited → auth_required →
  exit_code == 0 → api_error

Consequences of that order:
  * an exit code alone NEVER produces auth_required (ADR-004);
  * a 403 without rate-limit wording stays api_error, not auth_required;
  * an unknown failure becomes api_error, never a silent "ready".
]]
function Errors.classify(failure)
    if failure == nil then
        return "ready", nil
    end

    local flags = Errors.evidence(failure)
    local exit_code = failure.exit_code
    local message = tostring(failure.message or failure.stderr or "")

    if failure.disabled == true or failure.cli_missing == true then
        local text = message ~= "" and message or "provider unavailable"
        return "unavailable", Errors.new("unavailable", text, { exit_code = exit_code })
    end

    if failure.transport == true or failure.timed_out == true or flags.network_error then
        return "network_error", Errors.new("network_error", message, { exit_code = exit_code })
    end

    if failure.parse == true or flags.bad_response then
        return "bad_response", Errors.new("bad_response", message, { exit_code = exit_code })
    end

    if flags.rate_limited or failure.retry_after ~= nil or exit_code == 429 then
        return "rate_limited", Errors.new("rate_limited",
            message ~= "" and message or "rate limited",
            { exit_code = exit_code, retry_after = failure.retry_after })
    end

    if flags.auth or exit_code == 401 then
        return "auth_required", Errors.new("auth_required", message, { exit_code = exit_code })
    end

    if exit_code == 0 then
        return "ready", nil
    end

    return "api_error", Errors.new("api_error", message, { exit_code = exit_code })
end


return Errors
