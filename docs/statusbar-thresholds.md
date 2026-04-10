# Status Bar — Context Usage Color Thresholds

Reference for the color thresholds used in `~/.claude/statusline.sh`.
Last updated: 2026-04-10

---

## Anthropic Pricing (as of April 2026)

| Model | Input | Cache Write | Cache Read |
|-------|-------|-------------|------------|
| Claude Opus 4.6 | $5.00/1M | $6.25/1M | $0.50/1M |
| Claude Sonnet 4.6 | $3.00/1M | $3.75/1M | $0.30/1M |
| Claude Haiku 4.5 | $1.00/1M | $1.25/1M | $0.10/1M |

---

## Mathematical Model

### Variables
- **P** = fraction of context used (0–1)
- **T** = max context window tokens
- **N** = number of turns in session

### Cost Per Turn (reading full cached context)
```
C_turn(P) = T × P × cache_read_price
```

At full context (P=1):
- Opus 1M:    1,000,000 × $0.0000005  = **$0.50/turn**
- Sonnet 200k:  200,000 × $0.0000003  = **$0.06/turn**
- Haiku 200k:   200,000 × $0.0000001  = **$0.02/turn**

### Cumulative Session Cost (N=50 turns, linear fill)
Reads compound quadratically because every turn re-reads the growing cache:
```
C_session(P) = T × cache_write × P  +  T × cache_read × P² × N/2
               └─ one-time writes ─┘   └─── compounding reads each turn ────┘
```

#### Opus 1M
```
C(P) = 6.25P + 12.5P²
```
| Usage % | Cumulative Cost |
|---------|----------------|
| 10% | $0.75 |
| 15% | $1.22 |
| 20% | $1.75 |
| 30% | $3.00 |
| 50% | $6.25 |
| 100% | $18.75 |

#### Sonnet 200k
```
C(P) = 0.75P + 1.5P²
```
| Usage % | Cumulative Cost |
|---------|----------------|
| 30% | $0.36 |
| 40% | $0.54 |
| 50% | $0.75 |
| 62% | $1.04 |
| 100% | $2.25 |

#### Haiku 200k
```
C(P) = 0.25P + 0.5P²
```
| Usage % | Cumulative Cost |
|---------|----------------|
| 40% | $0.18 |
| 50% | $0.25 |
| 65% | $0.37 |
| 75% | $0.47 |
| 100% | $0.75 |

---

## Threshold Derivation

### Opus 1M — Primary signal: **cost**
Cache reads at Opus rates are expensive. Thresholds are set at cumulative cost milestones.

- **Orange at 15%** — ~$1.22 cumulative. Each turn is now $0.075 just for cache reads. Solve: `12.5P² + 6.25P = 1` → P ≈ 12%, rounded up to 15%.
- **Red at 30%** — ~$3.00 cumulative. Each turn is $0.15 in cache reads. Solve: `12.5P² + 6.25P = 3` → P ≈ 29%, rounded to 30%.

### Sonnet 4.6 — Primary signal: **cost + context availability**
Cost and context availability milestones happen to align at reasonable thresholds.

- **Orange at 40%** — ~$0.54 cumulative. 60% context still available. Solve: `1.5P² + 0.75P = 0.5` → P ≈ 39%.
- **Red at 62%** — ~$1.04 cumulative. 38% context remaining. Solve: `1.5P² + 0.75P = 1` → P ≈ 60.4%, rounded to 62%.

### Haiku 4.5 — Primary signal: **context availability**
Haiku is cheap enough that even a full 200k context session costs under $0.75 total. Cost is not meaningful — these thresholds are purely about how much context remains.

- **Orange at 50%** — half gone, still comfortable. At this point per-turn cost is $0.01, negligible.
- **Red at 75%** — only a quarter left, time to wrap up. Cumulative ~$0.47 (still cheap, but context is the concern).

---

## Final Thresholds

| Model | Default | Orange | Red | Primary Signal |
|-------|---------|--------|-----|----------------|
| Opus 4.6 (1M) | 0–14% | 15–29% | 30%+ | Cost ($1/$3 cumulative) |
| Sonnet 4.6 | 0–39% | 40–61% | 62%+ | Cost + context ($0.50/$1.00) |
| Haiku 4.5 | 0–49% | 50–74% | 75%+ | Context availability |

Detection in script: Opus detected by `max_tokens >= 900000`, Haiku by model name, Sonnet is the default fallback.
