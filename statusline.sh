#!/bin/sh
# cc-context-bar — Claude Code status bar with cost-aware context tracking
# https://github.com/jordadew/cc-context-bar
#
# Adds a visual progress bar to the Claude Code status line that:
# - Color-codes context usage based on per-model cost thresholds
# - Identifies your active model with emoji + matching color
# - Shows token counts for the current session
#
# Thresholds derived from Anthropic pricing data — see docs/statusbar-thresholds.md

input=$(cat)

# --- Parse JSON in one Python call (no jq dependency) ---
eval "$(echo "$input" | python3 -c "
import json, sys, shlex
d = json.load(sys.stdin)
cw = d.get('context_window', {})
fields = [
    ('model',               str(d.get('model', {}).get('display_name', 'Unknown model'))),
    ('used_pct',            str(cw.get('used_percentage', ''))),
    ('context_window_size', str(cw.get('context_window_size', cw.get('max_tokens', 0)))),
    ('in_tokens',           str(cw.get('total_input_tokens', ''))),
    ('out_tokens',          str(cw.get('total_output_tokens', ''))),
    ('five_pct',            str(d.get('rate_limits', {}).get('five_hour', {}).get('used_percentage', ''))),
    ('five_reset',          str(d.get('rate_limits', {}).get('five_hour', {}).get('resets_at', ''))),
    ('week_pct',            str(d.get('rate_limits', {}).get('seven_day', {}).get('used_percentage', ''))),
    ('week_reset',          str(d.get('rate_limits', {}).get('seven_day', {}).get('resets_at', ''))),
]
# Prompt cache: minutes left on the 1h TTL since the last assistant turn (blank if unknown)
cache_rem = ''
tp = d.get('transcript_path')
if tp:
    try:
        import os, time
        from datetime import datetime
        with open(tp, 'rb') as f:
            f.seek(0, 2); f.seek(max(0, f.tell() - 262144))
            tail = f.read().decode('utf-8', 'ignore').splitlines()
        for line in reversed(tail):
            try: e = json.loads(line)
            except Exception: continue
            if e.get('type') == 'assistant' and e.get('timestamp'):
                t = datetime.fromisoformat(e['timestamp'].replace('Z', '+00:00')).timestamp()
                cache_rem = str(max(0, -(-(3600 - (time.time() - t)) // 60)))  # ceil minutes
                break
    except Exception:
        pass
fields.append(('cache_rem', str(int(float(cache_rem))) if cache_rem else ''))
for k, v in fields:
    print(k + '=' + shlex.quote(v))
")"

model=$(echo "$model" | sed 's/^Claude //; s/ context)/)/')
model_lower=$(echo "$model" | tr '[:upper:]' '[:lower:]')

# --- Context window progress bar ---
if [ -n "$used_pct" ]; then
    used_int=$(printf "%.0f" "$used_pct")

    bar_width=14
    filled=$(( used_int * bar_width / 100 ))
    empty=$(( bar_width - filled ))

    bar=""
    i=0; while [ $i -lt $filled ]; do bar="${bar}█"; i=$(( i + 1 )); done
    i=0; while [ $i -lt $empty  ]; do bar="${bar}░"; i=$(( i + 1 )); done

    # Per-model color thresholds — see docs/statusbar-thresholds.md for derivation
    # Opus 1M:  cost-driven  — orange 15%, red 30%  (~$1/$3 cumulative cache cost)
    # Sonnet:   cost+context — orange 40%, red 62%  (~$0.50/$1.00 cumulative)
    # Haiku:    context-only — orange 50%, red 75%  (cost trivial, context is the signal)
    color_reset=$(printf '\033[0m')
    if [ "$context_window_size" -ge 900000 ] 2>/dev/null; then
        if   [ "$used_int" -ge 30 ]; then bar_color=$(printf '\033[38;5;196m')
        elif [ "$used_int" -ge 15 ]; then bar_color=$(printf '\033[38;5;208m')
        else bar_color=""; fi
    elif echo "$model_lower" | grep -q "haiku"; then
        if   [ "$used_int" -ge 75 ]; then bar_color=$(printf '\033[38;5;196m')
        elif [ "$used_int" -ge 50 ]; then bar_color=$(printf '\033[38;5;208m')
        else bar_color=""; fi
    else
        if   [ "$used_int" -ge 62 ]; then bar_color=$(printf '\033[38;5;196m')
        elif [ "$used_int" -ge 40 ]; then bar_color=$(printf '\033[38;5;208m')
        else bar_color=""; fi
    fi

    context_str="${bar_color}[${bar}] ${used_int}%${color_reset}"
else
    context_str="[--------------] --%"
fi

# --- Token counts ---
format_tokens() {
    awk -v t="$1" 'BEGIN {
        if      (t >= 1000000) printf "%.1fM", t/1000000
        else if (t >= 10000)   printf "%.0fk", t/1000
        else if (t >= 1000)    printf "%.1fk", t/1000
        else                   printf "%d",    t
    }'
}

if [ -n "$in_tokens" ] || [ -n "$out_tokens" ]; then
    in_str=$([ -n "$in_tokens" ]  && format_tokens "$in_tokens"  || echo "?")
    out_str=$([ -n "$out_tokens" ] && format_tokens "$out_tokens" || echo "?")
    token_segment=" | ↓${in_str} ↑${out_str}"
else
    token_segment=""
fi

# --- Usage windows: 5-hour + 7-day ---
# Native fields (Pro/Max only, present after first API response of the session).
# Absent early in a session or on non-subscription auth — degrade to nothing.
# window_str <label> <pct> <resets_at> -> e.g. "5h 29% 3h58m" / "7d 30% 3d"
window_str() {
    [ -n "$2" ] || return
    pct_int=$(printf "%.0f" "$2")

    # Countdown to window reset (resets_at is Unix epoch seconds)
    countdown=""
    if [ -n "$3" ]; then
        rem=$(( $3 - $(date +%s) ))
        [ "$rem" -lt 0 ] && rem=0
        d=$(( rem / 86400 )); h=$(( (rem % 86400) / 3600 )); m=$(( (rem % 3600) / 60 ))
        # 7d window: days + hours, then hours + minutes on the last day
        if   [ "$d" -gt 0 ]; then countdown=" ${d}d${h}h"
        elif [ "$h" -gt 0 ]; then countdown=" ${h}h${m}m"
        else countdown=" ${m}m"; fi
    fi

    # Color on how much of the window is spent — orange getting tight, red nearly gone
    if   [ "$pct_int" -ge 85 ]; then win_color=$(printf '\033[38;5;196m')
    elif [ "$pct_int" -ge 60 ]; then win_color=$(printf '\033[38;5;208m')
    else win_color=""; fi

    # 7d pace glyph: projected landing at reset = used% / elapsed%. Blank during the
    # first 10% of the window, once >=100% used, or without a reset time.
    glyph=""
    if [ "$1" = 7d ] && [ -n "$3" ] && [ "$pct_int" -lt 100 ]; then
        state="$HOME/.claude/.pace-state"
        prev=$(cat "$state" 2>/dev/null)
        lvl=$(awk -v u="$2" -v r="$3" -v now="$(date +%s)" -v prev="$prev" 'BEGIN {
            e = 1 - (r - now) / 604800
            if (e < 0.10 || e > 1) { print "none"; exit }
            p = u / e                       # projected % at reset
            b[1] = 90; b[2] = 105; b[3] = 130
            if (prev ~ /^[0-3]$/) {         # +-2 dead zone around band edges
                l = prev + 0
                while (l < 3 && p >= b[l+1] + 2) l++
                while (l > 0 && p <  b[l]   - 2) l--
            } else { l = 0; for (i = 1; i <= 3; i++) if (p >= b[i]) l = i }
            print l
        }')
        case "$lvl" in
            0) g="▼" ;; 1) g="●" ;; 2) g="▲" ;; 3) g="▲▲" ;; *) g="" ;;
        esac
        if [ -n "$g" ]; then
            echo "$lvl" > "$state"
            glyph="$(printf '\033[2m')${g}$(printf '\033[22m')"
        fi
    fi

    printf "%s%s %s%%%s%s%s%s" "$win_color" "$1" "$pct_int" "$glyph" "$countdown" "$(printf '\033[0m')"
}

five_str=$(window_str 5h "$five_pct" "$five_reset")
week_str=$(window_str 7d "$week_pct" "$week_reset")
windows="${five_str}${five_str:+${week_str:+ · }}${week_str}"
window_segment="${windows:+ | $windows}"

# --- Prompt cache countdown (pie empties by quarter) ---
# 1h TTL from last assistant turn. Orange <=20m, red <=5m, grey when cold.
if [ -n "$cache_rem" ]; then
    if   [ "$cache_rem" -gt 45 ]; then pie="●"
    elif [ "$cache_rem" -gt 30 ]; then pie="◕"
    elif [ "$cache_rem" -gt 15 ]; then pie="◑"
    elif [ "$cache_rem" -gt 0 ];  then pie="◔"
    else pie="○"; fi
    if   [ "$cache_rem" -le 0 ];  then c_color=$(printf '\033[38;5;245m'); c_text="cold"
    elif [ "$cache_rem" -le 5 ];  then c_color=$(printf '\033[38;5;196m'); c_text="${cache_rem}m"
    elif [ "$cache_rem" -le 20 ]; then c_color=$(printf '\033[38;5;208m'); c_text="${cache_rem}m"
    else c_color=""; c_text="${cache_rem}m"; fi
    window_segment="${window_segment} | ${c_color}${pie} ${c_text}$(printf '\033[0m')"
fi

# --- Model identity: emoji + color ---
# Colors match each model's emoji hue — see docs/model-colors.md
case "$model_lower" in
    *fable*)  model_icon="🈂️"; model_color=$(printf '\033[38;5;33m')  ;;  # blue
    *opus*)   model_icon="🅾️"; model_color=$(printf '\033[38;5;196m') ;;  # red
    *sonnet*) model_icon="✴️"; model_color=$(printf '\033[38;5;208m') ;;  # orange
    *haiku*)  model_icon="❇️"; model_color=$(printf '\033[38;5;46m')  ;;  # green
    *)        model_icon="";   model_color="" ;;
esac
reset=$(printf '\033[0m')

# --- Output ---
# Usage windows + cache drop to a second line when the full bar won't fit.
# Claude Code passes the pane width as $COLUMNS; keep a small margin for its padding.
line1="${context_str} | ${model_icon:-◆} ${model_color}${model}${reset}${token_segment:-}"
full="${line1}${window_segment:-}"
vis_width() {
    printf '%s' "$1" | python3 -c "
import re, sys, unicodedata as u
s = re.sub(r'\x1b\[[0-9;]*m', '', sys.stdin.read())
w = 0
for i, c in enumerate(s):
    if c == '\ufe0f': continue
    vs16 = i + 1 < len(s) and s[i+1] == '\ufe0f'
    w += 2 if vs16 or u.east_asian_width(c) in 'WF' else 1
print(w)"
}
if [ -n "$window_segment" ] && [ -n "$COLUMNS" ] && [ "$(vis_width "$full")" -gt $(( COLUMNS - 4 )) ]; then
    printf "%s\n%s\n" "$line1" "${window_segment# | }"
else
    printf "%s\n" "$full"
fi
