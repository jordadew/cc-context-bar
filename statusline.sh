#!/bin/sh
# cc-context-bar — Claude Code status bar with cost-aware context tracking
# https://github.com/jordan-adew/cc-context-bar
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
u  = cw.get('current_usage', {})
fields = [
    ('model',               str(d.get('model', {}).get('display_name', 'Unknown model'))),
    ('used_pct',            str(cw.get('used_percentage', ''))),
    ('context_window_size', str(cw.get('max_tokens', 0))),
    ('in_tokens',           str(u.get('input_tokens', ''))),
    ('out_tokens',          str(u.get('output_tokens', ''))),
]
for k, v in fields:
    print(k + '=' + shlex.quote(v))
")"

model_lower=$(echo "$model" | tr '[:upper:]' '[:lower:]')

# --- Context window progress bar ---
if [ -n "$used_pct" ]; then
    used_int=$(printf "%.0f" "$used_pct")

    bar_width=20
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
    context_str="[--------------------] --%"
fi

# --- Token counts ---
format_tokens() {
    t="$1"
    [ "$t" -ge 1000 ] && awk "BEGIN { printf \"%.1fk\", $t / 1000 }" || echo "$t"
}

if [ -n "$in_tokens" ] || [ -n "$out_tokens" ]; then
    in_str=$([ -n "$in_tokens" ]  && format_tokens "$in_tokens"  || echo "?")
    out_str=$([ -n "$out_tokens" ] && format_tokens "$out_tokens" || echo "?")
    token_segment="  |  ↓${in_str} ↑${out_str}"
else
    token_segment=""
fi

# --- Model identity: emoji + color ---
# Colors match each model's emoji hue — see docs/model-colors.md
case "$model_lower" in
    *opus*)   model_icon="🅾️"; model_color=$(printf '\033[38;5;196m') ;;  # red
    *sonnet*) model_icon="✴️"; model_color=$(printf '\033[38;5;208m') ;;  # orange
    *haiku*)  model_icon="❇️"; model_color=$(printf '\033[38;5;46m')  ;;  # green
    *)        model_icon="";   model_color="" ;;
esac
reset=$(printf '\033[0m')

# --- Output ---
if [ -n "$model_icon" ]; then
    printf "%s  |  %s ${model_color}%s${reset}%s" "$context_str" "$model_icon" "$model" "${token_segment:-}"
else
    printf "%s  |  ◆ ${model_color}%s${reset}%s" "$context_str" "$model" "${token_segment:-}"
fi
