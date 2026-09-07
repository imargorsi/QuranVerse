import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Manifest entry point. Owns the bar icon and the verse model; loads Panel.qml
// for the popup and forwards the panel lifecycle Quattro uses for clicks and
// shell commands. Structure follows Omarchy's built-in clock plugin.
BarWidget {
  id: root
  moduleName: "io.github.imargorsi.quran-verse"

  // The verse model lives here, not in the popup, so today's reference is
  // ready for the tooltip whether or not the popup has been opened.
  VerseModel { id: model }

  // The bar's icon color, with a palette fallback for the brief window before
  // the host injects `bar`.
  readonly property color barForeground: bar ? bar.barForeground : Color.foreground
  readonly property color barIconColor: model.errorText !== "" && !model.ready
    ? Qt.darker(root.barForeground, 1.2)
    : root.barForeground

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // ---- panel lifecycle forwarding (Bar.findPanelWidget needs open/close/
  //      opened on the bar-widget root; the popout coordinator needs the
  //      closeForPopoutSwitch/popoutSwitchClosing pair). Mirrors omarchy.clock.

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
    if ("model" in target) target.model = model
  }

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  // Routes shell.summon / hide / toggle (and any SUPER+CTRL keybind the user
  // assigns) to the panel. Same surface as omarchy.clock.
  IpcHandler {
    target: "io.github.imargorsi.quran-verse"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // nf-fa-book (U+F02D) — a closed book. A font glyph, not an image asset.
    // Written as an escape so no editor or copy step can strip the PUA char.
    text: "\uf02d"
    foreground: root.barIconColor
    tooltipText: model.reference !== ""
      ? (model.surahName + " · " + model.reference)
      : "Quran Verse of the Day"
    onPressed: function (b) { root.togglePanel() }
  }
}
