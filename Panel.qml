import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bar icon + popup. All layout, typography, and theme colors live here; the
// verse itself comes from Service.qml already normalized. The popup is built
// from the same qs.Ui primitives the first-party bar panels use, so it
// inherits the active Omarchy theme with no colors of its own.
Panel {
  id: root
  moduleName: "io.github.imargorsi.quran-verse"
  ipcTarget: "io.github.imargorsi.quran-verse"
  manageIpc: false

  // Guarded with a palette fallback so the widget still renders if it is
  // instantiated before the bar injects itself.
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color muted: Qt.darker(foreground, 1.5)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Service { id: verse }

  onOpenedChanged: if (opened) Qt.callLater(function () { keyCatcher.forceActiveFocus() })

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function status(): string {
      return verse.reference !== "" ? (verse.surahName + " " + verse.reference) : "Quran Verse of the Day"
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // nf-fa-book (U+F02D) — a closed book; a font glyph, not an image asset.
    text: ""
    foreground: verse.errorText !== "" && !verse.ready
      ? Qt.darker(root.barForeground, 1.2)
      : root.barForeground
    tooltipText: verse.reference !== ""
      ? (verse.surahName + " · " + verse.reference)
      : "Quran Verse of the Day"
    onPressed: function (b) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(460))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function (direction) { root.switchPanel(direction) }

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: column
          anchors.left: parent.left
          anchors.right: parent.right
          spacing: Style.space(14)

          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "Quran Verse of the Day"
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.letterSpacing: 1.2
            font.capitalization: Font.AllUppercase
          }

          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            textFormat: Text.PlainText
            text: verse.errorText !== ""
              ? "Unable to load Quran data."
              : (verse.verseText !== "" ? "“" + verse.verseText + "”" : "")
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
            lineHeight: 1.35
            wrapMode: Text.WordWrap
          }

          Text {
            visible: verse.errorText === "" && verse.reference !== ""
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            textFormat: Text.PlainText
            text: verse.surahName + " · " + verse.reference
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }
      }
    }
  }
}
