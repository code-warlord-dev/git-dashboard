# SECURITY.md

## Principles

1. **No plugin-owned secrets.** Auth is CLI sessions only.
2. **Argv-only** dynamic process execution when available on pinned Noctalia (ADR-006).
3. **Redact** collector output before logs.
4. **Plain data** on state channel — no tokens.
5. **Toast bodies** contain no secrets or diffs.
6. Plugins are trusted code; installation is a trust decision by the user.
7. **Auth loss** invalidates persisted privileged last-good (ADR-012).
8. **URL open:** only `http`/`https` schemes.

## Redaction patterns (REQ-S-006)

Before logging any collector stdout/stderr, scrub at least:

| Pattern class | Examples (case-insensitive where noted) |
|---------------|----------------------------------------|
| GitHub PAT | `ghp_`, `gho_`, `ghu_`, `ghs_`, `ghr_` + 20+ alnum |
| GitHub fine-grained | `github_pat_` |
| Bearer / Basic | `Authorization: Bearer …`, `Authorization: token …`, `Authorization: Basic …` |
| glab / tea tokens | Common `glpat-`, `gitea_` prefixes if present in output |
| Generic | `api_key=`, `access_token=`, `client_secret=` query-style |

Prefer substring/regex redaction to `[REDACTED]`. When in doubt, truncate stderr to a short non-sensitive summary.

## Retention / privacy

| Policy | Default |
|--------|---------|
| last_good_max_age_sec | 86400 |
| max_items_per_kind | 100 |
| clear_on_auth_loss | true |

`last-good.json` may contain private repo names and titles — treat as sensitive local data; invalidate on auth_required.

## Threat notes

| Threat | Mitigation |
|--------|------------|
| Token leakage via logs | Redaction patterns above |
| Shell injection via repo names | Argv form (ADR-006) |
| Toast storm | Urgency gate, dedup, quiet hours |
| Stale private data after logout | ADR-012 invalidation |
| Non-http URL open | Scheme allowlist |

## Privilege

Agent / CI must not request interactive sudo passwords. Prefer non-privileged verification; hand privileged commands to the human when required.
