#!/usr/bin/env node
/* Unit tests for Selection.js — the deterministic contextual picker.
 *
 *   node tools/test-selection.cjs
 *
 * Covers: same date => same verse, next date => (usually) a different verse,
 * context signals map to the right theme groups, and every pick resolves to a
 * real verse in quran.json.
 */
"use strict";

const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..");
const Selection = require(path.join(ROOT, "Selection.js"));
const verseThemes = JSON.parse(fs.readFileSync(path.join(ROOT, "verse-themes.json"), "utf8"));
const quran = JSON.parse(fs.readFileSync(path.join(ROOT, "quran.json"), "utf8"));

let failures = 0;
function check(name, cond) {
  console.log((cond ? "ok   " : "FAIL ") + name);
  if (!cond) failures++;
}

// A date at a fixed local hour, so partOfDay is predictable regardless of when
// the test runs.
function dayAt(y, m, d, hour) {
  return new Date(y, m - 1, d, hour, 0, 0);
}

// ---- determinism -----------------------------------------------------------

const a1 = Selection.pickVerse(dayAt(2026, 9, 7, 9), verseThemes, []);
const a2 = Selection.pickVerse(dayAt(2026, 9, 7, 9), verseThemes, []);
check("same date + same recent => same reference", a1.reference === a2.reference);

// Time of day is a deliberate context signal, so the same date at a
// different day-part may resolve to a different verse. Open-to-open
// stability within a day is guaranteed one level up, by Service.qml's
// daily cache (the first pick of the day is frozen). Here we only assert
// that the picker is a pure function of its inputs.
const a3 = Selection.pickVerse(dayAt(2026, 9, 7, 9), verseThemes, ["1:1", "2:2"]);
const a4 = Selection.pickVerse(dayAt(2026, 9, 7, 9), verseThemes, ["1:1", "2:2"]);
check("pure function: identical inputs => identical reference", a3.reference === a4.reference);
check("same date, same day-part => same reference",
  Selection.pickVerse(dayAt(2026, 9, 7, 10), verseThemes, []).reference === a1.reference);

let distinct = new Set();
for (let d = 1; d <= 30; d++) {
  distinct.add(Selection.pickVerse(dayAt(2026, 9, d, 9), verseThemes, []).reference);
}
check("30 consecutive days produce variety (>= 10 distinct verses)", distinct.size >= 10);

// ---- context -------------------------------------------------------------

// 2026-09-04 is a Friday.
const friday = Selection.pickVerse(dayAt(2026, 9, 4, 14), verseThemes, []);
check("Friday selects a Friday-preferred theme",
  verseThemes.context.friday.indexOf(friday.theme) !== -1);

const morning = Selection.contextSignals(dayAt(2026, 9, 8, 7));
check("07:00 is a morning", morning.indexOf("morning") !== -1);
const night = Selection.contextSignals(dayAt(2026, 9, 8, 23));
check("23:00 is a night", night.indexOf("night") !== -1);
check("2nd of the month is month_start",
  Selection.contextSignals(dayAt(2026, 9, 2, 12)).indexOf("month_start") !== -1);
check("28th of the month is month_end",
  Selection.contextSignals(dayAt(2026, 9, 28, 12)).indexOf("month_end") !== -1);

// ---- repeats-avoidance --------------------------------------------------

const base = Selection.pickVerse(dayAt(2026, 9, 10, 9), verseThemes, []);
const avoided = Selection.pickVerse(dayAt(2026, 9, 10, 9), verseThemes, [base.reference]);
check("a recent reference is skipped when the theme has alternatives",
  avoided.reference !== base.reference || (verseThemes.themes[base.theme] || []).length <= 1);

// ---- integrity ---------------------------------------------------------

let allResolve = true;
for (let d = 1; d <= 60; d++) {
  for (const h of [7, 13, 19, 23]) {
    const pick = Selection.pickVerse(dayAt(2026, 10, d <= 31 ? d : d - 31, h), verseThemes, []);
    if (!pick || !quran[pick.reference]) allResolve = false;
  }
}
check("every pick over 60 days x 4 hours resolves to a real verse", allResolve);

console.log(failures === 0 ? "\nALL PASS" : `\n${failures} FAILURE(S)`);
process.exit(failures === 0 ? 0 : 1);
