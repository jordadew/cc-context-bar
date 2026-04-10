# Model Display — Emoji & Color Reference

Reference for the model icon and color choices in `~/.claude/statusline.sh`.
Last updated: 2026-04-10

---

## Model Identity Palette

Each model has an emoji that conveys its character, and a text color that matches that emoji's dominant hue.

| Model | Emoji | Color Name | ANSI Code | Hex (approx) |
|-------|-------|------------|-----------|--------------|
| Claude Opus 4.6 | 🅾️ | Red | `\033[38;5;196m` | #FF0000 |
| Claude Sonnet 4.6 | ✴️ | Orange | `\033[38;5;208m` | #FF8700 |
| Claude Haiku 4.5 | ❇️ | Green | `\033[38;5;46m` | #00FF00 |
| Unknown | *(none)* | *(none)* | — | — |

---

## Emoji Choices

**🅾️ Opus** — The O matches "Opus". The red fill conveys power and cost — Opus is the most capable and expensive model. Red also aligns with "stop and think" — you're using the serious tool.

**✴️ Sonnet** — Eight-pointed star suggests balance and versatility. Orange sits between the urgency of red and the calm of green — Sonnet is the everyday workhorse, capable but not alarming.

**❇️ Haiku** — The sparkle/asterisk style suggests something light and fast. Green conveys low cost, low stakes — Haiku is the efficient, cheap option.

---

## Color Rationale

Colors were chosen to match the dominant hue in each emoji as rendered in most terminals/macOS:

- 🅾️ has a red circle fill → `38;5;196` (pure ANSI red in 256-color space)
- ✴️ renders with an orange/gold body → `38;5;208` (orange, sits between yellow 202 and red 196)
- ❇️ has green sparkle elements → `38;5;46` (bright green)

All colors use the 256-color xterm palette (`38;5;N`) rather than basic 16-color ANSI to get accurate hues. Basic ANSI `\033[31m` (red) and `\033[33m` (yellow) don't have orange.

---

## Implementation

In `~/.claude/statusline.sh`, model detection uses a case match on the lowercased display name:

```sh
case "$model_lower" in
    *opus*)   model_icon="🅾️"; model_color=$(printf '\033[38;5;196m') ;;
    *sonnet*) model_icon="✴️"; model_color=$(printf '\033[38;5;208m') ;;
    *haiku*)  model_icon="❇️"; model_color=$(printf '\033[38;5;46m')  ;;
    *)        model_icon="";   model_color=""                         ;;
esac
```

Color variables are generated with `printf '\033[...]'` rather than literal `\033` strings — shell variables don't interpret escape sequences, so the `printf` call bakes in the actual escape bytes.

---

## Adjusting Colors

To change a color, find the new code in the 256-color xterm chart:
- Quick reference: values 196–231 cover the color cube; 232–255 are grayscale
- Orange range: 202–214
- Red range: 160–196
- Green range: 40–82

Replace the number in `38;5;N` and test with:
```sh
printf '\033[38;5;208mthis is orange\033[0m\n'
```
