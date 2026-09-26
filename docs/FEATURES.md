# FEATURES.md — Unique Features Brainstorm

**Goal:** Features that reference plugins (`ariadev/omarchy-dev-git`, `robzolkos/omarchy-github`) do not offer (or offer weakly), and that the community of Noctalia / Niri / CLI-first developers will actually use.

**Filter:** Must fit the architecture (normalized model, capability honesty, CLI auth, keyboard-first). No feature that requires a plugin-owned token store or compositor coupling.

**Last updated:** 2026-09-26

---

## 1. Tier S — High value, fits P0–M3

### F-S1 · Unified Attention Score
Cross-provider “needs you” score that weights:
- pending reviews (highest)
- unread mentions / assignments
- failing CI on your PRs / default branches
- age of the oldest pending review

Shown on widget badge and as a sorted All tab.  
**Why unique:** Most forge UIs are per-provider; almost none give a single number that mixes GitHub + GitLab.

### F-S2 · Keyboard Triage Mode
Full keyboard workflow without mouse:
- `j`/`k` move, `Enter` open, `m` mark-read, `o` open in browser, `r` refresh, `g g` top, `G` bottom
- `/` filter by repo or title
- `1`–`4` jump sections (notifications / reviews / PRs / issues)

Documented in USER.md; works with `capture_keys`.  
**Why unique:** Reference plugins are mouse-heavy; power users on Niri live on the keyboard.

### F-S3 · System Toasts with Urgency Gate
See NOTIFICATIONS.md. Configurable min urgency + quiet hours + dedup.  
**Why unique:** Many bar plugins only update a badge; few emit disciplined desktop toasts that respect DND and do not spam.

### F-S4 · Stale-but-Honest Banner
When rate-limited or offline, show last-good data **with a clear banner** and age (“data from 12 min ago · rate limited”). Never silently show empty or pretend logged-out.  
**Why unique:** Common failure mode in CLI dashboards is “everything disappeared” when the API hiccups.

### F-S5 · Capability-Honest Empty States
If Gitea has no Actions equivalent, the section is hidden or shows “Not available on Gitea” — never an empty list that looks like “you have zero runs”.  
**Why unique:** Multi-provider UIs often paper over differences and confuse users.

---

## 2. Tier A — Strong differentiators (M3–M5)


### F-S6 · Auth recovery without tokens (ADR-018)
On `auth_required` empty state: hotkey **`a`** opens terminal with `gh auth login` (argv only); after re-auth, restore focus to last `entity_id` kept in RAM.  
**Why unique:** Keyboard triage survives session expiry without a plugin token store.

### F-A1 · Review Aging / SLA Hint
For each pending review, show “waiting 2d 4h”. Optional soft highlight when older than user threshold (e.g. 48 h).  
**Why unique:** Helps reviewers and authors fight review latency; rarely surfaced in bar plugins.

### F-A2 · “My open PRs that need attention”
Filter: PRs you authored that have failing checks, or requested changes, or no review yet after N days.  
One-click list in All tab.  
**Why unique:** Classic “what did I forget?” surface.

### F-A3 · Cross-provider “Same repo name” grouping (optional)
When the same logical project exists on GitHub and GitLab (e.g. mirror), optional group in All view.  
**Why unique:** Multi-forge teams exist; almost no dashboard acknowledges mirrors.

### F-A4 · Local “Snooze” / Hide until
Hide an item from attention until a local timestamp (stored under pluginDataDir). Does not call the forge.  
**Why unique:** Sometimes you know you cannot act for 2 hours; pure local control is rare.

### F-A5 · Contribution Streak / Goal (lightweight)
Simple “commits this week vs goal” without heavy heatmap if contributions capability is weak.  
**Why unique:** Motivational without the fragility of HTML-scraped calendars.

### F-A6 · One-shot “Focus repo”
Temporarily filter entire dashboard to one repo (keyboard `f` then type). Clears on Escape or timer.  
**Why unique:** Deep work mode for monorepo or multi-repo days.

---

## 3. Tier B — Nice-to-have / post-1.0

### F-B1 · Digest toast (promoted — ADR-016)
Instead of N separate toasts, one summary when multiple high/critical items share entity or burst window (“3 CI failures · org/repo · last 10m”).  
**Normative:** ADR-016 / REQ-N-009 / NOTIFICATIONS.md §10. Target M3; optional earlier.  
**Why unique:** Reduces fatigue without hiding critical repeats (pairs with urgency-aware dedup windows).

### F-B2 · PR size / risk badge
If CLI can expose additions/deletions or file count, show a small “S / M / L” chip.  
**Why unique:** Helps prioritization; data often available via `gh pr view`.

### F-B3 · “Who is waiting on me” vs “Who I am waiting on”
Two explicit queues derived from review requests and your open PRs with pending reviews.  
**Why unique:** Mental model that matches how developers actually plan the day.

### F-B4 · Export attention list
Copy as Markdown checklist or open as a temporary buffer (via `wl-copy` / argv).  
**Why unique:** Handy for standup notes.

### F-B5 · Multi-host Enterprise switcher polish
Keyboard `[` / `]` + host name in header; remember last host per provider.  
**Why unique:** Enterprise users juggle github.com + GHE constantly.

### F-B6 · Optional AI summary (explicit opt-in, external)
If user configures a local or remote summarizer command, “Summarize this PR” runs via argv and shows a short blurb. **No default cloud call; no token in plugin.**  
**Why unique / careful:** Powerful but must stay opt-in and local-first to match CLI ethos.

---

## 4. Explicitly out of scope (v1)

| Idea | Why out |
|------|---------|
| Built-in PAT / OAuth UI as primary auth | Violates CLI-session principle |
| Webhooks / real-time push | Security + complexity; poll is enough for bar |
| Full PR review editor inside panel | Panel is triage, not IDE |
| Chat / Discussions client | Different product |
| Fake uniformity of every forge feature | Capability honesty is a feature |
| Compositor-specific animations | Portability |

---

## 5. Prioritization for ROADMAP

| Feature | Earliest milestone | Notes |
|---------|--------------------|-------|
| F-S3 System toasts + urgency-aware dedup | M2 | ADR-016 windows |
| F-S6 Auth recovery hotkey | M2 soft / M3 | ADR-018 |
| F-B1 Digest toast | M3 | ADR-016 |
| F-S4 Stale banner | M2 | Core |
| F-S5 Capability honesty | M1–M2 | Architecture |
| F-S2 Keyboard triage | M2 foundation, M3 full | |
| F-S1 Attention score | M2 (simple), M3 weighted | |
| F-A1 Review aging | M3 | |
| F-A2 My PRs needing attention | M3 | |
| F-A4 Snooze | M3 | |
| F-A6 Focus repo | M3 | |
| F-A3 / F-A5 / Tier B | M4+ or post-1.0 | |

---

## 6. Community signal

These features were chosen because they answer recurring complaints in CLI / tiling-WM developer communities:

1. “I have three forges and no single inbox.”
2. “The badge went red and I don’t know why / everything vanished on rate limit.”
3. “I live on the keyboard; mouse-only triage is friction.”
4. “Don’t pretend Gitea is GitHub.”
5. “Notify me for real fires, not for every bot comment.”

Ship S-tier first; measure; then A-tier.
