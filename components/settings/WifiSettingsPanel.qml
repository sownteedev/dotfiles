import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../../"
import ".."

Item {
    id: root

    property bool applying: false
    property bool autoConnect: true
    readonly property real bodyFontSize: 14
    readonly property color cardColor: Config.alpha(Config.md3.surface_container, Config.lightTheme ? 0.76 : 0.36)
    readonly property color cardOutlineColor: Config.alpha(Config.md3.outline, Config.lightTheme ? 0.18 : 0.13)
    property real closeSwipeOffset: 0
    readonly property real closeSwipeThreshold: Math.min(120, width * 0.24)
    property string ipMethod: "auto"
    property bool ipv4AutomaticDns: true
    property bool ipv6AutomaticDns: true
    property bool ipv6Expanded: false
    property string ipv6Method: "auto"
    property string networkSsid: ""
    property bool opened: false
    property string saveError: ""
    readonly property real supportingFontSize: 13
    readonly property real titleFontSize: 17

    signal applyRequested(string ssid, var settings)
    signal forgetRequested(string ssid)

    function close() {
        applying = false;
        closeSwipeOffset = 0;
        saveError = "";
        opened = false;
    }
    function dnsValues(value) {
        return String(value || "").trim().split(/[,\s]+/).filter(function (entry) {
            return entry !== "";
        });
    }
    function isValidAddressWithPrefix(value, family) {
        var parts = String(value || "").trim().split("/");
        if (parts.length !== 2 || !/^\d+$/.test(parts[1]))
            return false;
        var prefix = Number(parts[1]);
        return family === 4 ? isValidIpv4(parts[0]) && prefix >= 0 && prefix <= 32 : isValidIpv6(parts[0]) && prefix >= 0 && prefix <= 128;
    }
    function isValidIpv4(value) {
        var parts = String(value || "").split(".");
        if (parts.length !== 4)
            return false;
        for (var i = 0; i < parts.length; ++i) {
            if (!/^\d{1,3}$/.test(parts[i]))
                return false;
            var number = Number(parts[i]);
            if (number < 0 || number > 255 || (String(number) !== parts[i] && parts[i] !== "0"))
                return false;
        }
        return true;
    }
    function isValidIpv6(value) {
        var address = String(value || "").trim().toLowerCase();
        if (address === "" || address.indexOf("%") !== -1 || !/^[0-9a-f:.]+$/.test(address))
            return false;
        if (address.indexOf("::") !== address.lastIndexOf("::"))
            return false;

        var compressed = address.indexOf("::") !== -1;
        var sides = address.split("::");
        var groups = [];
        for (var sideIndex = 0; sideIndex < sides.length; ++sideIndex) {
            if (sides[sideIndex] === "")
                continue;
            var sideGroups = sides[sideIndex].split(":");
            for (var groupIndex = 0; groupIndex < sideGroups.length; ++groupIndex)
                groups.push(sideGroups[groupIndex]);
        }

        var groupCount = 0;
        for (var i = 0; i < groups.length; ++i) {
            var group = groups[i];
            if (group.indexOf(".") !== -1) {
                if (i !== groups.length - 1 || !isValidIpv4(group))
                    return false;
                groupCount += 2;
            } else {
                if (!/^[0-9a-f]{1,4}$/.test(group))
                    return false;
                groupCount++;
            }
        }
        return compressed ? groupCount < 8 : groupCount === 8;
    }
    function loadSettings(ssid, settings) {
        if (ssid !== networkSsid)
            return;
        var ipv4 = settings.ipv4 || {};
        var ipv6 = settings.ipv6 || {};
        ipMethod = ipv4.method === "manual" ? "manual" : "auto";
        ipv4AutomaticDns = ipv4.automaticDns !== false;
        ipv4DnsField.text = ipv4.dns || "";
        ipv4AddressField.text = ipv4.address || "";
        ipv4GatewayField.text = ipv4.gateway || "";
        ipv6Method = ipv6.method === "manual" ? "manual" : ipv6.method === "disabled" ? "disabled" : "auto";
        ipv6AutomaticDns = ipv6.automaticDns !== false;
        ipv6DnsField.text = ipv6.dns || "";
        ipv6AddressField.text = ipv6.address || "";
        ipv6GatewayField.text = ipv6.gateway || "";
        autoConnect = settings.autoConnect !== false;
        saveError = "";
    }
    function markSaveFailed(message) {
        applying = false;
        saveError = message;
    }
    function markSaveSucceeded() {
        applying = false;
        close();
    }
    function openFor(ssid) {
        settingsFlick.contentY = 0;
        closeSwipeOffset = 0;
        networkSsid = ssid;
        ipMethod = "auto";
        ipv4AutomaticDns = true;
        ipv4DnsField.text = "";
        ipv4AddressField.text = "";
        ipv4GatewayField.text = "";
        ipv6Method = "auto";
        ipv6AutomaticDns = true;
        ipv6Expanded = false;
        ipv6DnsField.text = "";
        ipv6AddressField.text = "";
        ipv6GatewayField.text = "";
        autoConnect = true;
        applying = false;
        saveError = "";
        opened = true;
    }
    function validateAndApply() {
        saveError = "";
        if (!ipv4AutomaticDns && !validateDns(ipv4DnsField.text, 4)) {
            saveError = "Enter one or more valid IPv4 DNS servers.";
            return;
        }
        if (ipMethod === "manual") {
            if (!isValidAddressWithPrefix(ipv4AddressField.text, 4)) {
                saveError = "IPv4 address must include a valid /0–32 prefix.";
                return;
            }
            if (ipv4GatewayField.text.trim() !== "" && !isValidIpv4(ipv4GatewayField.text.trim())) {
                saveError = "IPv4 gateway is not valid.";
                return;
            }
        }
        if (ipv6Method !== "disabled" && !ipv6AutomaticDns && !validateDns(ipv6DnsField.text, 6)) {
            saveError = "Enter one or more valid IPv6 DNS servers.";
            ipv6Expanded = true;
            return;
        }
        if (ipv6Method === "manual") {
            if (!isValidAddressWithPrefix(ipv6AddressField.text, 6)) {
                saveError = "IPv6 address must include a valid /0–128 prefix.";
                ipv6Expanded = true;
                return;
            }
            if (ipv6GatewayField.text.trim() !== "" && !isValidIpv6(ipv6GatewayField.text.trim())) {
                saveError = "IPv6 gateway is not valid.";
                ipv6Expanded = true;
                return;
            }
        }

        applying = true;
        applyRequested(networkSsid, {
            "autoConnect": autoConnect,
            "ipv4": {
                "method": ipMethod,
                "automaticDns": ipv4AutomaticDns,
                "dns": ipv4DnsField.text.trim(),
                "address": ipv4AddressField.text.trim(),
                "gateway": ipv4GatewayField.text.trim()
            },
            "ipv6": {
                "method": ipv6Method,
                "automaticDns": ipv6AutomaticDns,
                "dns": ipv6DnsField.text.trim(),
                "address": ipv6AddressField.text.trim(),
                "gateway": ipv6GatewayField.text.trim()
            }
        });
    }
    function validateDns(value, family) {
        var values = dnsValues(value);
        if (values.length === 0)
            return false;
        for (var i = 0; i < values.length; ++i) {
            if (family === 4 ? !isValidIpv4(values[i]) : !isValidIpv6(values[i]))
                return false;
        }
        return true;
    }

    opacity: opened ? 1 : 0
    visible: opened || opacity > 0
    z: 1

    Behavior on opacity {
        NumberAnimation {
            duration: 180
        }
    }
    transform: Translate {
        y: root.opened ? 0 : 36

        Behavior on y {
            NumberAnimation {
                duration: 280
                easing.type: Easing.OutCubic
            }
        }
    }

    DragHandler {
        id: closeSwipe

        enabled: root.opened && !root.applying
        target: null
        xAxis.enabled: true
        yAxis.enabled: false

        onActiveChanged: {
            if (!active) {
                if (root.closeSwipeOffset >= root.closeSwipeThreshold)
                    root.close();
                else
                    root.closeSwipeOffset = 0;
            }
        }
        onTranslationChanged: {
            if (active)
                root.closeSwipeOffset = Math.max(0, translation.x);
        }
    }
    Flickable {
        id: settingsFlick

        anchors.fill: parent
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        contentHeight: panelContent.implicitHeight
        contentWidth: width
        flickableDirection: Flickable.VerticalFlick
        maximumFlickVelocity: 1800

        ScrollBar.vertical: SlimScrollBar {
        }

        ColumnLayout {
            id: panelContent

            spacing: 16
            width: settingsFlick.width
            x: 0

            Rectangle {
                Layout.fillWidth: true
                border.color: Config.alpha(Config.md3.primary, Config.lightTheme ? 0.22 : 0.18)
                border.width: 1
                color: Config.alpha(Config.md3.surface_container_high, Config.lightTheme ? 0.82 : 0.46)
                implicitHeight: 84
                radius: 18

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 12
                    spacing: 12

                    Rectangle {
                        color: Config.md3.primary_container
                        implicitHeight: 48
                        implicitWidth: 48
                        radius: 16

                        WifiSignalIcon {
                            anchors.centerIn: parent
                            color: Config.md3.on_primary_container
                            connected: true
                            height: 25
                            signalStrength: 100
                            width: 25
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            color: Config.md3.on_surface
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.pixelSize: root.titleFontSize
                            font.weight: Font.Bold
                            text: root.networkSsid
                        }
                        Text {
                            Layout.fillWidth: true
                            color: Config.alpha(Config.md3.on_surface, 0.58)
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.pixelSize: root.supportingFontSize
                            text: root.applying ? "Saving profile and reconnecting…" : "Saved Wi-Fi network"
                        }
                    }
                    Rectangle {
                        Layout.preferredHeight: 42
                        Layout.preferredWidth: 42
                        border.color: Config.alpha(Config.md3.error, 0.18)
                        border.width: 1
                        color: forgetPointer.containsMouse ? Config.alpha(Config.md3.error, 0.18) : Config.alpha(Config.md3.error, 0.08)
                        enabled: !root.applying
                        opacity: enabled ? 1 : 0.45
                        radius: 13

                        IconImage {
                            anchors.centerIn: parent
                            height: 18
                            layer.enabled: true
                            source: Quickshell.iconPath("user-trash-symbolic")
                            width: 18

                            layer.effect: ColorOverlay {
                                color: Config.md3.error
                            }
                        }
                        MouseArea {
                            id: forgetPointer

                            anchors.fill: parent
                            cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            enabled: parent.enabled
                            hoverEnabled: true

                            onClicked: {
                                root.forgetRequested(root.networkSsid);
                                root.close();
                            }
                        }
                    }
                    Rectangle {
                        Layout.preferredHeight: 42
                        Layout.preferredWidth: 42
                        color: root.applying ? Config.alpha(Config.md3.primary, 0.68) : savePointer.containsMouse ? Qt.lighter(Config.md3.primary, 1.08) : Config.md3.primary
                        radius: 13

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 8

                            AnimatedSpinner {
                                color: Config.md3.on_primary
                                height: 17
                                lineWidth: 2
                                running: root.applying
                                visible: root.applying
                                width: 17
                            }
                            IconImage {
                                height: 17
                                layer.enabled: true
                                source: Quickshell.iconPath("document-save-symbolic")
                                visible: !root.applying
                                width: 17

                                layer.effect: ColorOverlay {
                                    color: Config.md3.on_primary
                                }
                            }
                        }
                        MouseArea {
                            id: savePointer

                            anchors.fill: parent
                            cursorShape: root.applying ? Qt.ArrowCursor : Qt.PointingHandCursor
                            enabled: !root.applying
                            hoverEnabled: true

                            onClicked: root.validateAndApply()
                        }
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                border.color: Config.alpha(Config.md3.error, 0.22)
                border.width: 1
                color: Config.alpha(Config.md3.error_container, 0.58)
                implicitHeight: root.saveError === "" ? 0 : errorRow.implicitHeight + 24
                opacity: root.saveError === "" ? 0 : 1
                radius: 14
                visible: implicitHeight > 0

                Behavior on implicitHeight {
                    NumberAnimation {
                        duration: 180
                    }
                }

                RowLayout {
                    id: errorRow

                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    IconImage {
                        height: 18
                        layer.enabled: true
                        source: Quickshell.iconPath("dialog-error-symbolic")
                        width: 18

                        layer.effect: ColorOverlay {
                            color: Config.md3.on_error_container
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        color: Config.md3.on_error_container
                        font.family: Config.fontName
                        font.pixelSize: root.bodyFontSize
                        text: root.saveError
                        wrapMode: Text.Wrap
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                border.color: root.cardOutlineColor
                border.width: 1
                color: root.cardColor
                implicitHeight: ipv4Content.implicitHeight + 36
                radius: 18

                ColumnLayout {
                    id: ipv4Content

                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Rectangle {
                            Layout.preferredHeight: 38
                            Layout.preferredWidth: 38
                            color: Config.md3.primary_container
                            radius: 12

                            Text {
                                anchors.centerIn: parent
                                color: Config.md3.on_primary_container
                                font.family: Config.fontName
                                font.pixelSize: 18
                                font.weight: Font.Black
                                text: "4"
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                color: Config.md3.on_surface
                                font.family: Config.fontName
                                font.pixelSize: root.titleFontSize
                                font.weight: Font.Bold
                                text: "IPv4"
                            }
                            Text {
                                Layout.fillWidth: true
                                color: Config.alpha(Config.md3.on_surface, 0.58)
                                elide: Text.ElideRight
                                font.family: Config.fontName
                                font.pixelSize: root.supportingFontSize
                                text: root.ipMethod === "auto" ? "Address and gateway are assigned by DHCP" : "Use a fixed address for this network"
                            }
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 16
                        spacing: 8

                        Text {
                            color: Config.md3.on_surface
                            font.family: Config.fontName
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            text: "IP assignment"
                        }
                        SettingsSegmentedControl {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            backgroundColor: Config.alpha(Config.md3.surface_container_highest, Config.lightTheme ? 0.70 : 0.46)
                            enabled: !root.applying
                            fontPixelSize: 15
                            options: [
                                {
                                    "label": "Automatic (DHCP)",
                                    "value": "auto"
                                },
                                {
                                    "label": "Manual",
                                    "value": "manual"
                                }
                            ]
                            selectedValue: root.ipMethod

                            onSelected: value => root.ipMethod = value
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.topMargin: 16
                        border.color: Config.alpha(Config.md3.primary, 0.16)
                        border.width: 1
                        color: Config.alpha(Config.md3.primary, Config.lightTheme ? 0.09 : 0.075)
                        implicitHeight: 68
                        radius: 15

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            spacing: 16

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    color: Config.md3.on_surface
                                    font.family: Config.fontName
                                    font.pixelSize: 15
                                    font.weight: Font.Bold
                                    text: "DNS assignment"
                                }
                                Text {
                                    color: Config.alpha(Config.md3.on_surface, 0.58)
                                    font.family: Config.fontName
                                    font.pixelSize: root.supportingFontSize
                                    text: root.ipv4AutomaticDns ? "Automatic (from DHCP)" : "Custom servers below"
                                }
                            }
                            ToggleSwitch {
                                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                Layout.maximumWidth: 40
                                Layout.minimumWidth: 40
                                Layout.preferredWidth: 40
                                accessibleName: "Use automatic IPv4 DNS"
                                checked: root.ipv4AutomaticDns
                                checkedColor: Config.alpha(Config.md3.primary, 0.26)
                                enabled: !root.applying
                                thumbCheckedColor: Config.md3.primary

                                onToggled: checked => root.ipv4AutomaticDns = checked
                            }
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.ipv4AutomaticDns ? 0 : ipv4DnsField.implicitHeight
                        Layout.topMargin: root.ipv4AutomaticDns ? 0 : 14
                        clip: true
                        opacity: root.ipv4AutomaticDns ? 0 : 1

                        Behavior on Layout.preferredHeight {
                            NumberAnimation {
                                duration: 180
                                easing.type: Easing.OutCubic
                            }
                        }

                        SettingsTextField {
                            id: ipv4DnsField

                            editable: !root.applying
                            label: "Custom DNS servers"
                            placeholder: "8.8.8.8 8.8.4.4"
                            width: parent.width
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.ipMethod === "manual" ? ipv4ManualFields.implicitHeight : 0
                        Layout.topMargin: root.ipMethod === "manual" ? 14 : 0
                        clip: true
                        opacity: root.ipMethod === "manual" ? 1 : 0

                        Behavior on Layout.preferredHeight {
                            NumberAnimation {
                                duration: 180
                                easing.type: Easing.OutCubic
                            }
                        }

                        ColumnLayout {
                            id: ipv4ManualFields

                            spacing: 12
                            width: parent.width

                            SettingsTextField {
                                id: ipv4AddressField

                                Layout.fillWidth: true
                                editable: !root.applying
                                label: "Address / prefix"
                                placeholder: "192.168.1.100/24"
                            }
                            SettingsTextField {
                                id: ipv4GatewayField

                                Layout.fillWidth: true
                                editable: !root.applying
                                label: "Gateway (optional)"
                                placeholder: "192.168.1.1"
                            }
                        }
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                border.color: root.cardOutlineColor
                border.width: 1
                color: root.cardColor
                implicitHeight: ipv6Header.implicitHeight + (root.ipv6Expanded ? ipv6Body.implicitHeight + 16 : 0) + 36
                radius: 18

                Behavior on implicitHeight {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 16

                    Item {
                        id: ipv6Header

                        Layout.fillWidth: true
                        implicitHeight: 52

                        RowLayout {
                            anchors.fill: parent
                            spacing: 12

                            Rectangle {
                                Layout.preferredHeight: 38
                                Layout.preferredWidth: 38
                                color: Config.alpha(Config.md3.secondary_container, 0.92)
                                radius: 12

                                Text {
                                    anchors.centerIn: parent
                                    color: Config.md3.on_secondary_container
                                    font.family: Config.fontName
                                    font.pixelSize: 18
                                    font.weight: Font.Black
                                    text: "6"
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    Layout.fillWidth: true
                                    color: Config.md3.on_surface
                                    font.family: Config.fontName
                                    font.pixelSize: root.titleFontSize
                                    font.weight: Font.Bold
                                    text: "IPv6"
                                }
                                Text {
                                    Layout.fillWidth: true
                                    color: Config.alpha(Config.md3.on_surface, 0.58)
                                    elide: Text.ElideRight
                                    font.family: Config.fontName
                                    font.pixelSize: root.supportingFontSize
                                    text: root.ipv6Method === "manual" ? "Manual address" : root.ipv6Method === "disabled" ? "Disabled" : "Automatic configuration"
                                }
                            }
                            Rectangle {
                                Layout.preferredHeight: 38
                                Layout.preferredWidth: 38
                                color: ipv6HeaderMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.09) : Config.alpha(Config.md3.on_surface, 0.045)
                                radius: 12

                                IconImage {
                                    id: ipv6ExpandIcon

                                    anchors.centerIn: parent
                                    height: 20
                                    layer.enabled: true
                                    rotation: root.ipv6Expanded ? 180 : 0
                                    source: Quickshell.iconPath("pan-down-symbolic")
                                    width: 20

                                    layer.effect: ColorOverlay {
                                        color: Config.md3.on_surface_variant
                                    }
                                    Behavior on rotation {
                                        NumberAnimation {
                                            duration: 180
                                        }
                                    }
                                }
                            }
                        }
                        MouseArea {
                            id: ipv6HeaderMouse

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true

                            onClicked: root.ipv6Expanded = !root.ipv6Expanded
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.ipv6Expanded ? ipv6Body.implicitHeight : 0
                        clip: true
                        opacity: root.ipv6Expanded ? 1 : 0

                        ColumnLayout {
                            id: ipv6Body

                            spacing: 14
                            width: parent.width

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Text {
                                    color: Config.md3.on_surface
                                    font.family: Config.fontName
                                    font.pixelSize: 15
                                    font.weight: Font.DemiBold
                                    text: "IP assignment"
                                }
                                SettingsSegmentedControl {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 44
                                    backgroundColor: Config.alpha(Config.md3.surface_container_highest, Config.lightTheme ? 0.70 : 0.46)
                                    enabled: !root.applying
                                    fontPixelSize: 15
                                    options: [
                                        {
                                            "label": "Automatic",
                                            "value": "auto"
                                        },
                                        {
                                            "label": "Manual",
                                            "value": "manual"
                                        },
                                        {
                                            "label": "Disabled",
                                            "value": "disabled"
                                        }
                                    ]
                                    selectedValue: root.ipv6Method

                                    onSelected: value => root.ipv6Method = value
                                }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                border.color: Config.alpha(Config.md3.primary, 0.16)
                                border.width: 1
                                color: Config.alpha(Config.md3.primary, Config.lightTheme ? 0.09 : 0.075)
                                implicitHeight: root.ipv6Method === "disabled" ? 0 : 68
                                opacity: root.ipv6Method === "disabled" ? 0 : 1
                                radius: 15
                                visible: root.ipv6Method !== "disabled"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 16
                                    spacing: 16

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Text {
                                            color: Config.md3.on_surface
                                            font.family: Config.fontName
                                            font.pixelSize: 15
                                            font.weight: Font.Bold
                                            text: "DNS assignment"
                                        }
                                        Text {
                                            color: Config.alpha(Config.md3.on_surface, 0.58)
                                            font.family: Config.fontName
                                            font.pixelSize: root.supportingFontSize
                                            text: root.ipv6AutomaticDns ? "Automatic (from the network)" : "Custom servers below"
                                        }
                                    }
                                    ToggleSwitch {
                                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                        Layout.maximumWidth: 40
                                        Layout.minimumWidth: 40
                                        Layout.preferredWidth: 40
                                        accessibleName: "Use automatic IPv6 DNS"
                                        checked: root.ipv6AutomaticDns
                                        checkedColor: Config.alpha(Config.md3.primary, 0.26)
                                        enabled: !root.applying
                                        thumbCheckedColor: Config.md3.primary

                                        onToggled: checked => root.ipv6AutomaticDns = checked
                                    }
                                }
                            }
                            SettingsTextField {
                                id: ipv6DnsField

                                Layout.fillWidth: true
                                editable: !root.applying
                                label: "Custom IPv6 DNS servers"
                                placeholder: "2606:4700:4700::1111"
                                visible: root.ipv6Method !== "disabled" && !root.ipv6AutomaticDns
                            }
                            SettingsTextField {
                                id: ipv6AddressField

                                Layout.fillWidth: true
                                editable: !root.applying
                                label: "Address / prefix"
                                placeholder: "2001:db8::10/64"
                                visible: root.ipv6Method === "manual"
                            }
                            SettingsTextField {
                                id: ipv6GatewayField

                                Layout.fillWidth: true
                                editable: !root.applying
                                label: "Gateway (optional)"
                                placeholder: "2001:db8::1"
                                visible: root.ipv6Method === "manual"
                            }
                        }
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                border.color: root.cardOutlineColor
                border.width: 1
                color: root.cardColor
                implicitHeight: 76
                radius: 18

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 14

                    Rectangle {
                        Layout.preferredHeight: 42
                        Layout.preferredWidth: 42
                        color: Config.alpha(Config.md3.tertiary_container, 0.90)
                        radius: 13

                        IconImage {
                            anchors.centerIn: parent
                            height: 21
                            layer.enabled: true
                            source: Quickshell.iconPath("network-wireless-symbolic")
                            width: 21

                            layer.effect: ColorOverlay {
                                color: Config.md3.on_tertiary_container
                            }
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            color: Config.md3.on_surface
                            font.family: Config.fontName
                            font.pixelSize: 16
                            font.weight: Font.Bold
                            text: "Connect automatically"
                        }
                        Text {
                            Layout.fillWidth: true
                            color: Config.alpha(Config.md3.on_surface, 0.58)
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.pixelSize: root.supportingFontSize
                            text: root.autoConnect ? "Join this network when it is available" : "Connect only when requested"
                        }
                    }
                    ToggleSwitch {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        Layout.maximumWidth: 40
                        Layout.minimumWidth: 40
                        Layout.preferredWidth: 40
                        accessibleName: "Connect automatically"
                        checked: root.autoConnect
                        checkedColor: Config.alpha(Config.md3.primary, 0.26)
                        enabled: !root.applying
                        thumbCheckedColor: Config.md3.primary

                        onToggled: checked => root.autoConnect = checked
                    }
                }
            }
        }
    }
}
