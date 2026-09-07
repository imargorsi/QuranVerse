// Deterministic, offline, contextual verse selection.
//
// No network, no randomness, no persisted RNG state: given the same date
// (and the same "recently shown" list) this returns the same reference every
// time. Service.qml owns the data files and the recent-history cache; this
// file is pure logic so it can be unit-tested with plain node
// (tools/test-selection.mjs).
//
// Flow:  date -> context signals -> candidate themes -> theme -> verse
//
// See docs/CONTEXT-SELECTION.md for the reasoning behind the mappings.

// ---------------------------------------------------------------- date utils

function pad2(n) {
  return n < 10 ? "0" + n : String(n);
}

// Local calendar date as YYYY-MM-DD. This is the selection seed, so it must
// follow the user's wall clock (a new day = a new verse at local midnight).
function isoDate(date) {
  return date.getFullYear() + "-" + pad2(date.getMonth() + 1) + "-" + pad2(date.getDate());
}

// Four coarse day parts. Boundaries are deliberately simple; dawn/dusk drift
// isn't worth a solar calculation for a verse nudge.
function partOfDay(hour) {
  if (hour >= 5 && hour < 11) return "morning";
  if (hour >= 11 && hour < 17) return "midday";
  if (hour >= 17 && hour < 21) return "evening";
  return "night";
}

// Objective, local-only signals. Ordered most-general to most-specific so the
// day part sets the baseline mood and the calendar signals layer on top.
// getDay() === 5 is Friday (Jumu'ah).
function contextSignals(date) {
  var signals = [partOfDay(date.getHours())];
  if (date.getDay() === 5) signals.push("friday");

  var dom = date.getDate();
  if (dom <= 3) signals.push("month_start");
  else if (dom >= 26) signals.push("month_end");

  return signals;
}

// ---------------------------------------------------------------- hashing

// FNV-1a, 32-bit. Small, stable across engines, and good enough to scatter
// short date strings across a handful of buckets. Not security-sensitive.
function hashString(str) {
  var h = 0x811c9dc5;
  for (var i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  return h >>> 0;
}

// ---------------------------------------------------------------- selection

// Ordered, de-duplicated list of themes the current context prefers. Falls
// back to every theme (a balanced rotation) when no context entry matched.
function preferredThemes(date, contextMap, allThemes) {
  var out = [];
  var signals = contextSignals(date);
  for (var s = 0; s < signals.length; s++) {
    var themes = (contextMap && contextMap[signals[s]]) || [];
    for (var t = 0; t < themes.length; t++) {
      if (allThemes.indexOf(themes[t]) !== -1 && out.indexOf(themes[t]) === -1) {
        out.push(themes[t]);
      }
    }
  }
  return out.length > 0 ? out : allThemes.slice();
}

// Pick today's reference.
//
//   verseThemes : parsed verse-themes.json ({ themes, context })
//   recent      : array of recently shown "s:a" references, newest first
//
// Returns { reference, theme, signals } or null when the data is unusable.
function pickVerse(date, verseThemes, recent) {
  var themes = (verseThemes && verseThemes.themes) || {};
  var allThemes = Object.keys(themes);
  if (allThemes.length === 0) return null;

  var seed = isoDate(date);
  var candidates = preferredThemes(date, verseThemes.context || {}, allThemes);
  var theme = candidates[hashString(seed) % candidates.length];

  var pool = (themes[theme] || []).slice();
  if (pool.length === 0) {
    // Curated list for the chosen theme is empty — use the first theme that
    // actually has verses rather than returning nothing.
    for (var i = 0; i < allThemes.length; i++) {
      if ((themes[allThemes[i]] || []).length > 0) {
        theme = allThemes[i];
        pool = themes[theme].slice();
        break;
      }
    }
  }
  if (pool.length === 0) return null;

  var seen = {};
  var list = recent || [];
  for (var r = 0; r < list.length; r++) seen[list[r]] = true;

  // Deterministic start index, then walk forward to the first verse that
  // isn't in recent history. If every verse in the theme was shown recently
  // we keep the deterministic pick (graceful fallback, no repeats-avoidance).
  var start = hashString(seed + "|" + theme) % pool.length;
  var reference = pool[start];
  for (var k = 0; k < pool.length; k++) {
    var cand = pool[(start + k) % pool.length];
    if (!seen[cand]) {
      reference = cand;
      break;
    }
  }

  return { reference: reference, theme: theme, signals: contextSignals(date) };
}

// Prepend today's reference to the recent list, drop duplicates, and cap the
// length. Kept tiny on purpose — this is a nicety, not a database.
function pushRecent(recent, reference, cap) {
  var limit = cap || 24;
  var out = [reference];
  var list = recent || [];
  for (var i = 0; i < list.length && out.length < limit; i++) {
    if (list[i] !== reference) out.push(list[i]);
  }
  return out;
}

if (typeof module !== "undefined") {
  module.exports = {
    isoDate: isoDate,
    partOfDay: partOfDay,
    contextSignals: contextSignals,
    hashString: hashString,
    preferredThemes: preferredThemes,
    pickVerse: pickVerse,
    pushRecent: pushRecent
  };
}
