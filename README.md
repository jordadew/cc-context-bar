# cc-context-bar

A Claude Code status bar that tells you when you're burning through context — before it's too late.

Most Claude Code users don't realise their session cost is compounding quadratically until the context bar is already red. This script adds a cost-aware progress bar to your status line with thresholds derived from Anthropic's actual pricing data, calibrated differently for each model.

```
[████░░░░░░░░░░] 30% | 🅾️ Opus 4.6 | ↓8.2k ↑2.1k | 5h 42% 1h58m · 7d 61%● 3d4h | ◑ 28m
[█████░░░░░░░░░] 40% | ✴️ Sonnet 5.5 | ↓12k ↑3.1k | 5h 68% 3h4m · 7d 74%▲ 2d | ◕ 41m
[███████░░░░░░░] 50% | ❇️ Haiku 4.5 | ↓5.9k ↑1.8k | 5h 91% 22m · 7d 38%▼ 4d | ○ cold
```

---

## What it does

**Visual progress bar** — replaces the default status line with a `█░` bar showing context window usage.

**Cost-aware color thresholds** — the bar changes color based on when it actually starts costing you, not just when you're running out of space:

| Model | Goes orange | Goes red | Signal |
|-------|-------------|----------|--------|
| Opus 4.6 (1M context) | 15% | 30% | Cost — ~$1 / ~$3 cumulative cache spend |
| Sonnet 5.5 | 40% | 62% | Cost + context — ~$0.50 / ~$1.00 |
| Haiku 4.5 | 50% | 75% | Context only — cost is negligible |

Opus fires early because 30% of a 1M context window at Opus cache-read rates costs ~$3 per turn to maintain. Haiku fires late because even a full session costs under $0.75 total.

**Model identity** — your active model is labeled with a matching emoji and color so you always know what you're running:
- 🈂️ Fable — blue
- 🅾️ Opus — red
- ✴️ Sonnet — orange
- ❇️ Haiku — green

**Token counts** — input/output tokens for the session shown inline.

**5-hour and 7-day usage windows** — how much of each Max/Pro rate-limit window you've spent, plus a live countdown to reset (`5h 42% 1h58m · 7d 61% 3d4h`). Each goes orange at 60%, red at 85%. Uses Claude Code's native `rate_limits` data — appears once the session's first API response lands, and silently omits itself otherwise (e.g. early in a session or on non-subscription auth).

**7-day pace glyph** — a dim glyph after the 7d % showing where you'll land at reset if you keep burning at your window-average rate (`used% / elapsed%`):

| Glyph | Projected at reset | Meaning |
|-------|--------------------|---------|
| `▲▲` | ≥130% | Out well before reset |
| `▲` | 105–130% | Over, will probably hit the cap |
| `●` | 90–105% | On track, you use it all |
| `▼` | 70–90% | Under, some quota left unused |
| `▼▼` | <70% | Well under, a lot of quota left unused |

Blank for the first 10% of the window (the projection is noise), once you're at 100%, or without a reset time. A ±2% dead zone stops it flickering at band edges; the last level is kept in `~/.claude/.pace-state`. The bands are in `window_str` in `statusline.sh`.

**Prompt-cache countdown** — a pie that empties by quarter over the 1h cache TTL since the last assistant turn (`● ◕ ◑ ◔`), orange at 20m, red at 5m, grey `○ cold` once expired. Read from the session transcript.

**Wraps in narrow windows** — when the full bar is wider than the pane (`$COLUMNS`, passed by Claude Code), the usage windows and cache countdown move to a second line.

---

## Install

Paste this into your terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/jordadew/cc-context-bar/main/statusline.sh -o ~/.claude/statusline.sh && python3 -c "
import json, pathlib
p = pathlib.Path.home() / '.claude/settings.json'
d = json.loads(p.read_text()) if p.exists() else {}
d['statusLine'] = {'type': 'command', 'command': 'bash ~/.claude/statusline.sh'}
p.write_text(json.dumps(d, indent=2))
print('Done — open /hooks in Claude Code to reload.')
"
```

No dependencies beyond `python3`, which is already on your machine. The command downloads the script and merges the required config into your existing `settings.json` without touching anything else.

> **Already have a `statusLine` configured?** The command will replace it. Back up your existing `statusLine` entry in `~/.claude/settings.json` first, then manually chain your existing command if needed.

---

## How the thresholds were derived

The color triggers aren't arbitrary. They're based on a quadratic cost model for Claude's prompt caching:

```
C_session(P) = T × cache_write × P  +  T × cache_read × P² × N/2
```

Where P = fraction of context used, T = max tokens, N = turns in session. Cache reads compound because every turn re-reads the growing context. Full derivation with tables in [`docs/statusbar-thresholds.md`](docs/statusbar-thresholds.md).

---

## Files

| File | Purpose |
|------|---------|
| `statusline.sh` | The script |
| `docs/statusbar-thresholds.md` | Pricing data, cost model, threshold derivation |
| `docs/model-colors.md` | Emoji choices, ANSI color codes, implementation notes |

---

## Customising

Thresholds are in `statusline.sh` around line 50. Each model has its own block — change the numbers to suit your workflow. Colors use 256-color ANSI (`38;5;N`) — see `docs/model-colors.md` for the palette reference.
