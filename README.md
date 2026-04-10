# cc-context-bar

A Claude Code status bar that tells you when you're burning through context — before it's too late.

Most Claude Code users don't realise their session cost is compounding quadratically until the context bar is already red. This script adds a cost-aware progress bar to your status line with thresholds derived from Anthropic's actual pricing data, calibrated differently for each model.

```
[████████░░░░░░░░░░░░] 40%  |  ✴️ Sonnet 4.6  |  ↓12.4k ↑3.1k
```

---

## What it does

**Visual progress bar** — replaces the default status line with a `█░` bar showing context window usage.

**Cost-aware color thresholds** — the bar changes color based on when it actually starts costing you, not just when you're running out of space:

| Model | Goes orange | Goes red | Signal |
|-------|-------------|----------|--------|
| Opus 4.6 (1M context) | 15% | 30% | Cost — ~$1 / ~$3 cumulative cache spend |
| Sonnet 4.6 | 40% | 62% | Cost + context — ~$0.50 / ~$1.00 |
| Haiku 4.5 | 50% | 75% | Context only — cost is negligible |

Opus fires early because 30% of a 1M context window at Opus cache-read rates costs ~$3 per turn to maintain. Haiku fires late because even a full session costs under $0.75 total.

**Model identity** — your active model is labeled with a matching emoji and color so you always know what you're running:
- 🅾️ Opus — red
- ✴️ Sonnet — orange
- ❇️ Haiku — green

**Token counts** — input/output tokens for the session shown inline.

---

## Install

Paste this into Claude Code:

```
Set up cc-context-bar for me.

1. Fetch https://raw.githubusercontent.com/jordan-adew/cc-context-bar/main/statusline.sh and write it to ~/.claude/statusline.sh

2. Merge this into ~/.claude/settings.json without replacing any existing keys:
   "statusLine": {
     "type": "command",
     "command": "bash ~/.claude/statusline.sh"
   }
```

That's it. No dependencies beyond `python3`, which is already on your machine. Open `/hooks` in Claude Code to reload config.

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

Thresholds are in `statusline.sh` around line 40. Each model has its own block — change the numbers to suit your workflow. Colors use 256-color ANSI (`38;5;N`) — see `docs/model-colors.md` for the palette reference.
