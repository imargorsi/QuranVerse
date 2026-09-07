# Contextual selection

The verse of the day is chosen by a small deterministic function, not at
random and not by any model. This document explains what it does and why.

## Goals, in order

1. **Correct** — every verse is a real reference in the bundled translation,
   shown verbatim.
2. **Deterministic** — the same day shows the same verse; reopening the popup
   never reshuffles it.
3. **Contextual** — the choice leans toward a theme that suits the moment
   (morning, Friday, the end of a month), using only objective local facts.
4. **Not repetitive** — recently shown verses are skipped when there's an
   alternative.
5. **Tiny** — a hash and two lookups. No engine, no database, no tuning knobs.

## Inputs

Only the local clock and two bundled files:

- `new Date()` — the user's wall clock.
- `verse-themes.json`
  - `themes` — each theme name → a short list of verified `"surah:ayah"`
    references. ~83 references across 13 themes.
  - `context` — each context signal → an ordered list of theme names it
    prefers.

## Steps

### 1. Context signals — `contextSignals(date)`

Objective facts about *now*, most general first:

| Signal | Condition |
|--------|-----------|
| `morning` | hour 05:00–10:59 |
| `midday` | hour 11:00–16:59 |
| `evening` | hour 17:00–20:59 |
| `night` | hour 21:00–04:59 |
| `friday` | `getDay() === 5` (Jumu'ah) |
| `month_start` | day of month ≤ 3 |
| `month_end` | day of month ≥ 26 |

Exactly one day-part is always present. `friday` and a month-boundary signal
layer on top when they apply. Emotional state, location, history, and identity
are deliberately **not** inputs.

The day-part boundaries are fixed clock hours on purpose — a solar dawn/dusk
calculation is not worth it for a verse nudge, and keeping them fixed keeps the
function pure and testable.

### 2. Preferred themes — `preferredThemes(date, contextMap, allThemes)`

Concatenate `context[signal]` for each signal, in signal order, de-duplicated.
If nothing matched (shouldn't happen — a day-part always does), fall back to
*all* themes, i.e. a flat rotation.

Example — a Friday afternoon at the end of the month:
`midday` → `[patience, good_deeds, knowledge, trust]`, then
`friday` → `[reflection, guidance, mercy, faith]`, then
`month_end` → `[gratitude, patience, reflection]`.
De-duplicated: `[patience, good_deeds, knowledge, trust, reflection, guidance,
mercy, faith, gratitude]`.

### 3. Pick a theme

```
theme = preferred[ hashString(isoDate(date)) % preferred.length ]
```

`isoDate` is the local `YYYY-MM-DD`. `hashString` is FNV-1a (32-bit) — small,
stable across JS engines, well-scattered for short strings, and not
security-relevant. The date alone seeds the theme pick, so the theme is stable
for the whole day.

### 4. Pick a verse within the theme

```
pool  = verse-themes.themes[theme]
start = hashString(isoDate + "|" + theme) % pool.length
```

Walk `pool` forward from `start` and take the first reference **not** in the
recent list. If every verse in the pool was shown recently, keep the one at
`start` (graceful fallback — determinism wins over novelty).

### 5. Resolve

`Service.qml` looks the `"surah:ayah"` up in `quran.json` for the surah name
and the English text, then writes today's pick and an updated `recent` list
(newest first, capped at 24) to the state cache.

## Why the daily cache matters here

Time of day is a selection input, so *in principle* the same date at a
different hour could resolve differently. In practice `Service.qml` freezes the
first pick of the day in `~/.local/state/omarchy/quran-verse.json` and serves
that for the rest of the day. So:

- open the popup at 09:00 and again at 23:00 → same verse (cache).
- clear the cache mid-day and reopen → may re-pick with the current hour's
  context. This is the only way the within-day verse changes, and it's a
  deliberate escape hatch, not a bug.

## Changing the mappings

Everything above is data except the five steps, which are ~40 lines in
`Selection.js`. To retune, edit `verse-themes.json` and run:

```sh
python3 tools/verify-references.py   # references still valid?
node    tools/test-selection.cjs     # determinism + context still hold?
```
