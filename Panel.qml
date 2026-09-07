import QtQuick
import qs.Commons
import qs.Ui

// The popup: layout, typography, and theme colors only. The verse comes in
// already normalized on `model` (a VerseModel owned by BarWidget.qml). Built
// from the same qs.Ui primitives as the first-party bar panels, so it inherits
// the active Omarchy theme and has no colors of its own.
Panel {
  id: root
  moduleName: "io.github.imargorsi.quran-verse"
  ipcTarget: "io.github.imargorsi.quran-verse"
  manageIpc: false

  // Injected by BarWidget.injectPanel().
  property var anchorItem: null
  property var hostWidget: null
  property var model: null
  readonly property var barIdentity: hostWidget || root

  // Guarded with a palette fallback so the popup still renders if it is
  // instantiated before the bar injects itself.
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color muted: Qt.darker(foreground, 1.5)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property string verseText: model ? model.verseText : ""
  readonly property string errorText: model ? model.errorText : ""
  readonly property string reference: model ? model.reference : ""
  readonly property string surahName: model ? model.surahName : ""

  function open() {
    if (model) model.recompute()   // catch a midnight rollover before showing
    setCenterHoverRevealSuppressed(false)
    root.controller.show()
    Qt.callLater(function () {
      if (root.opened) setCenterHoverRevealSuppressed(true)
    })
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  // Summoning by hotkey moves no pointer, so a hover the bar was still holding
  // must not keep the center indicators revealed behind the panel.
  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && typeof root.bar.setCenterHoverRevealSuppressed === "function")
      root.bar.setCenterHoverRevealSuppressed(value)
    else if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  onOpenedChanged: if (opened) Qt.callLater(function () { keyCatcher.forceActiveFocus() })

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
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
            text: root.errorText !== ""
              ? "Unable to load Quran data."
              : (root.verseText !== "" ? "“" + root.verseText + "”" : "")
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
            lineHeight: 1.35
            wrapMode: Text.WordWrap
          }

          Text {
            visible: root.errorText === "" && root.reference !== ""
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            textFormat: Text.PlainText
            text: root.surahName + " · " + root.reference
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }
      }
    }
  }
}
