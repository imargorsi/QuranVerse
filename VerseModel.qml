import QtQuick
import Quickshell
import Quickshell.Io
import "Selection.js" as Selection

// The verse model: date, context detection, deterministic pick, the tiny
// recent-history cache, and local data access. No layout — BarWidget.qml and
// Panel.qml read the normalized result off these properties:
//
//   ready       true once a verse is available
//   errorText   non-empty when the local data could not be loaded
//   reference   "surah:ayah", e.g. "94:6"
//   surahName   "Ash-Sharh"
//   ayah        6
//   verseText   the English (Saheeh International) translation, verbatim
//   themeName   the theme the pick came from, e.g. "hardship"
//
// Everything is local. There is no network path anywhere in this file.
Item {
  id: root

  property bool ready: false
  property string errorText: ""
  property string reference: ""
  property string surahName: ""
  property int ayah: 0
  property string verseText: ""
  property string themeName: ""

  readonly property string statePath: Quickshell.env("HOME") + "/.local/state/omarchy/quran-verse.json"

  // Recomputation is cheap when the day hasn't rolled over (a date compare and
  // a cache read), so an hourly tick is enough to move the verse on at local
  // midnight. Panel.qml also calls recompute() when the popup opens, so a
  // popup opened just after midnight is never stale.
  Timer {
    interval: 3600000
    repeat: true
    running: true
    onTriggered: root.recompute()
  }

  Component.onCompleted: Qt.callLater(function () {
    // FileView with a declarative path preloads, but an explicit reload makes
    // first-run (file absent -> onLoadFailed) fire reliably regardless of
    // startup ordering.
    themesFile.reload()
    stateFile.reload()
  })

  // ---- data files ------------------------------------------------------
  //
  // verse-themes.json is small and always needed. quran.json is ~1.2 MB, so
  // its FileView has no path until something actually needs the verse text
  // (ensureQuranLoading); a day whose verse is already in the state cache
  // never pays that parse.

  property var _themesData: null
  property bool _themesReady: false

  property FileView themesFile: FileView {
    path: Qt.resolvedUrl("verse-themes.json")
    watchChanges: false
    printErrors: false
    onLoaded: {
      if (!root._themesReady) {
        try {
          root._themesData = JSON.parse(text())
          root._themesReady = true
        } catch (e) {
          root._fail()
        }
      }
      root.recompute()
    }
    onLoadFailed: root._fail()
  }

  property var _quranData: null
  property bool _quranReady: false
  property bool _quranWanted: false

  property FileView quranFile: FileView {
    watchChanges: false
    printErrors: false
    onLoaded: {
      if (root._quranReady) return   // FileView can fire onLoaded more than once
      try {
        root._quranData = JSON.parse(text())
        root._quranReady = true
      } catch (e) {
        root._fail()
        return
      }
      root.recompute()
    }
    onLoadFailed: root._fail()
  }

  function ensureQuranLoading() {
    if (root._quranReady || root._quranWanted) return
    root._quranWanted = true
    quranFile.path = Qt.resolvedUrl("quran.json")
  }

  // ---- recent-history / today's-pick cache ----------------------------
  //
  // One tiny JSON object: today's chosen verse plus a short list of recent
  // references so the picker can avoid immediate repeats. Missing or
  // unreadable just means "recompute from scratch" — it is never fatal, and
  // this file is the plugin's only write.

  property var _state: null
  property bool _stateChecked: false

  property FileView stateFile: FileView {
    path: root.statePath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: {
      try {
        root._state = JSON.parse(text())
      } catch (e) {
        root._state = null
      }
      root._stateChecked = true
      root.recompute()
    }
    onLoadFailed: {
      root._state = null
      root._stateChecked = true
      root.recompute()
    }
  }

  function _saveState() {
    try {
      stateFile.setText(JSON.stringify(root._state, null, 2) + "\n")
    } catch (e) {
      // A write failure (e.g. missing state dir) only costs a recompute
      // tomorrow — the verse on screen is unaffected.
    }
  }

  // ---- selection -----------------------------------------------------

  function _fail() {
    if (root.ready) return   // keep a verse already on screen
    root.errorText = "Unable to load Quran data."
  }

  function _apply(ref, surah, ayahNum, txt, theme) {
    root.reference = ref
    root.surahName = surah
    root.ayah = ayahNum
    root.verseText = txt
    root.themeName = theme || ""
    root.errorText = ""
    root.ready = true
  }

  function recompute() {
    if (!root._themesReady || !root._stateChecked) return

    var now = new Date()
    var today = Selection.isoDate(now)

    // Same day, verse already chosen — reuse it. This is what makes opening
    // the popup repeatedly show the same verse, with no parsing of the large
    // dataset.
    if (root._state && root._state.date === today && root._state.text) {
      _apply(root._state.reference, root._state.surah, root._state.ayah,
             root._state.text, root._state.theme)
      return
    }

    if (!root._quranReady) {
      ensureQuranLoading()
      return   // recompute() runs again from quranFile.onLoaded
    }

    var recent = (root._state && root._state.recent) || []
    var pick = Selection.pickVerse(now, root._themesData, recent)
    if (!pick) { _fail(); return }

    var v = root._quranData[pick.reference]
    if (!v || !v.text) { _fail(); return }

    _apply(pick.reference, v.surah, v.ayah, v.text, pick.theme)

    root._state = {
      date: today,
      reference: pick.reference,
      surah: v.surah,
      ayah: v.ayah,
      text: v.text,
      theme: pick.theme,
      recent: Selection.pushRecent(recent, pick.reference, 24)
    }
    _saveState()
  }
}
