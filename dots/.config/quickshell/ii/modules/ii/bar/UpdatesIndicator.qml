import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

MouseArea {
    id: root

    readonly property color contentColor: Updates.updateStronglyAdvised ? Appearance.colors.colError : rightSidebarButton.colText

    implicitWidth: rowLayout.implicitWidth
    implicitHeight: rowLayout.implicitHeight
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    onClicked: Quickshell.execDetached(["bash", "-c", Config.options.apps.update])

    RowLayout {
        id: rowLayout
        anchors.centerIn: parent

        MaterialSymbol {
            text: "deployed_code_update"
            iconSize: Appearance.font.pixelSize.larger
            color: root.contentColor
            Layout.alignment: Qt.AlignVCenter
        }

        StyledText {
            font.pixelSize: Appearance.font.pixelSize.small
            color: root.contentColor
            text: Updates.count
        }
    }

    PopupToolTip {
        extraVisibleCondition: root.containsMouse
        alternativeVisibleCondition: extraVisibleCondition
        anchorEdges: (!Config.options.bar.bottom && !Config.options.bar.vertical) ? Edges.Bottom : Edges.Top
        text: Translation.tr("Pending updates: %1").arg(Updates.count)
    }
}
