import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../../"
import ".."

Item {
    id: root

    property bool applying: false
    property bool autoConnect: true
    property string ipMethod: "auto"
    property string networkSsid: ""
    property bool opened: false

    signal applyRequested(string ssid, string method, string dns, string address, string gateway, bool autoConnect)
    signal forgetRequested(string ssid)

    function close() {
        applying = false;
        opened = false;
    }
    function loadSettings(ssid, method, dns, address, gateway, shouldAutoConnect) {
        if (ssid !== networkSsid)
            return;
        ipMethod = method;
        dnsField.text = dns;
        ipField.text = address;
        gatewayField.text = gateway;
        autoConnect = shouldAutoConnect;
    }
    function openFor(ssid) {
        networkSsid = ssid;
        ipMethod = "auto";
        dnsField.text = "";
        ipField.text = "";
        gatewayField.text = "";
        autoConnect = true;
        applying = false;
        opened = true;
    }

    opacity: opened ? 1 : 0
    visible: opened || opacity > 0
    z: 1

    Behavior on opacity {
        NumberAnimation {
            duration: 200
        }
    }
    transform: Translate {
        y: root.opened ? 0 : 40

        Behavior on y {
            NumberAnimation {
                duration: 350
                easing.type: Easing.OutBack
            }
        }
    }

    DragHandler {
        target: null
        xAxis.enabled: true
        yAxis.enabled: false

        onTranslationChanged: {
            if (translation.x > 150)
                root.close();
        }
    }
    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                color: Config.alpha(Config.md3.primary, 0.12)
                height: 35
                radius: 16
                width: 35

                IconImage {
                    anchors.centerIn: parent
                    height: 20
                    layer.enabled: true
                    source: Quickshell.iconPath("network-wireless-signal-excellent-symbolic")
                    width: 20

                    layer.effect: ColorOverlay {
                        color: Config.md3.primary
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    color: Config.alpha(Config.md3.on_surface, 0.40)
                    font.family: Config.fontName
                    font.pixelSize: 14
                    renderType: Text.NativeRendering
                    text: "Network Settings"
                }
                Text {
                    Layout.fillWidth: true
                    color: Config.md3.on_surface
                    elide: Text.ElideRight
                    font.family: Config.fontName
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                    text: root.networkSsid
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            border.color: Config.alpha(Config.md3.on_surface, 0.06)
            border.width: 1
            color: Config.md3.surface_container
            implicitHeight: settingsContent.implicitHeight + 36
            radius: 14

            Behavior on implicitHeight {
                NumberAnimation {
                    duration: 250
                    easing.type: Easing.OutQuad
                }
            }

            ColumnLayout {
                id: settingsContent

                anchors.fill: parent
                anchors.margins: 18
                spacing: 0

                RowLayout {
                    Layout.bottomMargin: 14
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 10

                    ColumnLayout {
                        spacing: 2

                        Text {
                            color: Config.md3.on_surface
                            font.family: Config.fontName
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            renderType: Text.NativeRendering
                            text: "IP Method"
                        }
                        Text {
                            color: Config.alpha(Config.md3.on_surface, 0.38)
                            font.family: Config.fontName
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            renderType: Text.NativeRendering
                            text: root.ipMethod === "auto" ? "Automatic (DHCP)" : "Manual (Static IP)"
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    Rectangle {
                        color: Config.alpha(Config.md3.on_surface, 0.07)
                        height: 28
                        radius: 9
                        width: 138

                        Rectangle {
                            color: Config.md3.primary
                            height: 22
                            radius: 7
                            width: 64
                            x: 3 + (root.ipMethod === "manual" ? 66 : 0)
                            y: 3

                            Behavior on x {
                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.OutQuad
                                }
                            }
                        }
                        Row {
                            anchors.fill: parent
                            anchors.margins: 3
                            spacing: 2

                            Repeater {
                                model: [
                                    {
                                        label: "DHCP",
                                        value: "auto"
                                    },
                                    {
                                        label: "Static",
                                        value: "manual"
                                    }
                                ]

                                delegate: Item {
                                    required property var modelData

                                    height: parent.height
                                    width: 64

                                    Text {
                                        anchors.centerIn: parent
                                        color: root.ipMethod === modelData.value ? Config.md3.background : Config.alpha(Config.md3.on_surface, 0.50)
                                        font.family: Config.fontName
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        renderType: Text.NativeRendering
                                        text: modelData.label
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor

                                        onClicked: root.ipMethod = modelData.value
                                    }
                                }
                            }
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    color: Config.alpha(Config.md3.on_surface, 0.06)
                    height: 1
                }
                SettingsTextField {
                    id: dnsField

                    Layout.bottomMargin: 14
                    Layout.fillWidth: true
                    Layout.topMargin: 14
                    editable: !root.applying
                    fieldHeight: 44
                    label: "DNS Servers"
                    placeholder: "8.8.8.8 8.8.4.4"
                }
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.ipMethod === "manual" ? manualFields.implicitHeight + 12 : 0
                    clip: true
                    opacity: root.ipMethod === "manual" ? 1 : 0

                    Behavior on Layout.preferredHeight {
                        NumberAnimation {
                            duration: 250
                            easing.type: Easing.OutQuad
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
                        }
                    }

                    ColumnLayout {
                        id: manualFields

                        spacing: 10
                        width: parent.width

                        Rectangle {
                            Layout.fillWidth: true
                            color: Config.alpha(Config.md3.on_surface, 0.06)
                            height: 1
                        }
                        SettingsTextField {
                            id: ipField

                            Layout.fillWidth: true
                            editable: !root.applying
                            fieldHeight: 38
                            label: "IP Address (CIDR)"
                            placeholder: "e.g.  192.168.1.100/24"
                        }
                        SettingsTextField {
                            id: gatewayField

                            Layout.fillWidth: true
                            editable: !root.applying
                            fieldHeight: 36
                            label: "Gateway"
                            placeholder: "e.g.  192.168.1.1"
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    color: Config.alpha(Config.md3.on_surface, 0.06)
                    height: 1
                }
                RowLayout {
                    Layout.bottomMargin: 8
                    Layout.fillWidth: true
                    Layout.topMargin: 14
                    spacing: 12

                    ColumnLayout {
                        spacing: 2

                        Text {
                            color: Config.md3.on_surface
                            font.family: Config.fontName
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            renderType: Text.NativeRendering
                            text: "Auto-connect"
                        }
                        Text {
                            color: Config.alpha(Config.md3.on_surface, 0.38)
                            font.family: Config.fontName
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            renderType: Text.NativeRendering
                            text: root.autoConnect ? "Connects automatically" : "Manual connection only"
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    ToggleSwitch {
                        checked: root.autoConnect
                        height: 28
                        thumbMargin: 3
                        width: 50

                        onToggled: checked => root.autoConnect = checked
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 20

            Rectangle {
                Layout.fillWidth: true
                border.color: Config.alpha(Config.md3.error, 0.20)
                border.width: 1
                color: forgetPointer.containsMouse ? Config.alpha(Config.md3.error, 0.18) : Config.alpha(Config.md3.error, 0.10)
                height: 44
                radius: 10

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    IconImage {
                        height: 13
                        layer.enabled: true
                        source: Quickshell.iconPath("user-trash-symbolic")
                        width: 13

                        layer.effect: ColorOverlay {
                            color: Config.alpha(Config.md3.error, 0.80)
                        }
                    }
                    Text {
                        color: Config.alpha(Config.md3.error, 0.80)
                        font.family: Config.fontName
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        text: "Forget"
                    }
                }
                MouseArea {
                    id: forgetPointer

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: {
                        root.forgetRequested(root.networkSsid);
                        root.close();
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                border.color: Config.alpha("#ffffff", 0.10)
                border.width: 1
                color: root.applying ? Config.alpha(Config.md3.primary, 0.70) : applyPointer.containsMouse ? Qt.lighter(Config.md3.primary, 1.10) : Config.md3.primary
                height: 44
                radius: 10

                IconImage {
                    anchors.centerIn: parent
                    height: 16
                    layer.enabled: true
                    source: Quickshell.iconPath("process-working-symbolic")
                    visible: root.applying
                    width: 16

                    layer.effect: ColorOverlay {
                        color: "white"
                    }
                    RotationAnimation on rotation {
                        duration: 900
                        from: 0
                        loops: Animation.Infinite
                        running: root.applying
                        to: 360
                    }
                }
                Text {
                    anchors.centerIn: parent
                    color: Config.md3.surface_container
                    font.family: Config.fontName
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    text: "Apply"
                    visible: !root.applying
                }
                MouseArea {
                    id: applyPointer

                    anchors.fill: parent
                    cursorShape: root.applying ? Qt.ArrowCursor : Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: {
                        if (root.applying)
                            return;
                        root.applying = true;
                        root.applyRequested(root.networkSsid, root.ipMethod, dnsField.text.trim().replace(/ +/g, ","), ipField.text.trim(), gatewayField.text.trim(), root.autoConnect);
                        closeTimer.restart();
                    }
                }
            }
        }
    }
    Timer {
        id: closeTimer

        interval: 5000
        repeat: false

        onTriggered: root.close()
    }
}
