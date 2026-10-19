import "../.."
import ".."
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    required property int currentPage
    readonly property int displayedPage: pendingPage > 0 ? pendingPage : currentPage
    property bool editing: false
    required property int lastPage
    property bool loading: false
    property int pendingPage: 0

    signal nextRequested
    signal pageRequested(int page)
    signal previousRequested

    function beginEdit() {
        if (loading || !visible || !enabled)
            return;
        pageInput.text = String(currentPage);
        editing = true;
        pageInput.forceActiveFocus();
        pageInput.selectAll();
    }
    function cancelEdit() {
        editing = false;
        pageInput.focus = false;
    }
    function settlePendingPage() {
        if (!loading)
            pendingPage = 0;
    }
    function submitPage() {
        if (!editing || loading || !pageInput.acceptableInput)
            return;
        var requestedPage = Number(pageInput.text);
        if (!Number.isInteger(requestedPage) || requestedPage < 1 || requestedPage > lastPage)
            return;
        if (requestedPage !== currentPage)
            pendingPage = requestedPage;
        cancelEdit();
        if (requestedPage !== currentPage) {
            pageRequested(requestedPage);
            Qt.callLater(root.settlePendingPage);
        }
    }

    spacing: 6

    onCurrentPageChanged: {
        pendingPage = 0;
        cancelEdit();
    }
    onLastPageChanged: cancelEdit()
    onLoadingChanged: {
        if (loading)
            cancelEdit();
        else
            Qt.callLater(root.settlePendingPage);
    }
    onVisibleChanged: {
        if (!visible) {
            pendingPage = 0;
            cancelEdit();
        }
    }

    Rectangle {
        Accessible.name: qsTr("Previous page")
        Accessible.role: Accessible.Button
        Layout.preferredHeight: 36
        Layout.preferredWidth: 36
        activeFocusOnTab: true
        border.color: "transparent"
        border.width: 0
        color: previousMouse.containsMouse ? Config.alpha(Config.md3.on_surface, Md3.state.hover) : Config.alpha(Config.md3.on_surface, 0.05)
        enabled: !root.loading && root.currentPage > 1
        opacity: enabled ? 1 : 0.35
        radius: Md3.shape.full

        Behavior on color {
            ColorAnimation {
                duration: Config.animationDuration(Md3.motion.short2)
            }
        }

        Accessible.onPressAction: root.previousRequested()
        Keys.onReturnPressed: root.previousRequested()
        Keys.onSpacePressed: root.previousRequested()

        Md3Icon {
            anchors.centerIn: parent
            color: Config.md3.on_surface_variant
            name: "go-previous-symbolic"
            size: 18
        }
        MouseArea {
            id: previousMouse

            anchors.fill: parent
            cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            enabled: parent.enabled
            hoverEnabled: true

            onClicked: root.previousRequested()
        }
    }
    Rectangle {
        Accessible.name: qsTr("Go to page")
        Accessible.role: Accessible.Button
        Layout.preferredHeight: 36
        Layout.preferredWidth: Math.max(8, pageNumberMetrics.advanceWidth) + pageSuffix.implicitWidth + 24
        activeFocusOnTab: !root.loading && !root.editing
        color: Config.alpha(Config.md3.on_surface, 0.05)
        radius: Md3.shape.full

        Accessible.onPressAction: root.beginEdit()
        Keys.onReturnPressed: root.beginEdit()
        Keys.onSpacePressed: root.beginEdit()

        TextMetrics {
            id: pageNumberMetrics

            font: pageLabel.font
            text: "8".repeat(String(root.lastPage).length)
        }
        Text {
            id: pageLabel

            anchors.centerIn: parent
            color: Config.md3.on_surface_variant
            font.family: Config.fontName
            font.pixelSize: 12
            font.weight: Font.DemiBold
            text: qsTr("%1 / %2").arg(root.displayedPage).arg(root.lastPage)
            visible: !root.editing
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            enabled: !root.loading && !root.editing

            onDoubleClicked: root.beginEdit()
        }
        Row {
            id: pageEditor

            anchors.centerIn: parent
            visible: root.editing

            TextInput {
                id: pageInput

                Accessible.name: qsTr("Page number, from 1 to %1").arg(root.lastPage)
                clip: true
                color: acceptableInput ? Config.md3.on_surface_variant : Config.md3.error
                font: pageLabel.font
                height: 36
                selectByMouse: true
                selectedTextColor: Config.md3.on_primary
                selectionColor: Config.md3.primary
                verticalAlignment: TextInput.AlignVCenter
                width: Math.min(Math.max(8, implicitWidth), Math.max(8, pageNumberMetrics.advanceWidth))

                validator: IntValidator {
                    bottom: 1
                    locale: "C"
                    top: root.lastPage
                }

                Keys.onEnterPressed: root.submitPage()
                Keys.onEscapePressed: root.cancelEdit()
                Keys.onReturnPressed: root.submitPage()
                onActiveFocusChanged: {
                    if (!activeFocus && root.editing)
                        root.cancelEdit();
                }
            }
            Text {
                id: pageSuffix

                anchors.verticalCenter: parent.verticalCenter
                color: Config.md3.on_surface_variant
                font: pageLabel.font
                text: qsTr(" / %1").arg(root.lastPage)
            }
        }
    }
    Rectangle {
        Accessible.name: qsTr("Next page")
        Accessible.role: Accessible.Button
        Layout.preferredHeight: 36
        Layout.preferredWidth: 36
        activeFocusOnTab: true
        border.color: "transparent"
        border.width: 0
        color: nextMouse.containsMouse ? Config.alpha(Config.md3.on_surface, Md3.state.hover) : Config.alpha(Config.md3.on_surface, 0.05)
        enabled: !root.loading && root.currentPage < root.lastPage
        opacity: enabled ? 1 : 0.35
        radius: Md3.shape.full

        Behavior on color {
            ColorAnimation {
                duration: Config.animationDuration(Md3.motion.short2)
            }
        }

        Accessible.onPressAction: root.nextRequested()
        Keys.onReturnPressed: root.nextRequested()
        Keys.onSpacePressed: root.nextRequested()

        Md3Icon {
            anchors.centerIn: parent
            color: Config.md3.on_surface_variant
            name: "go-next-symbolic"
            size: 18
        }
        MouseArea {
            id: nextMouse

            anchors.fill: parent
            cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            enabled: parent.enabled
            hoverEnabled: true

            onClicked: root.nextRequested()
        }
    }
}
