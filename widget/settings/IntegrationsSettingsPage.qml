import "../../"
import "../../components"
import "../../service"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property string baselineState: ""
    readonly property bool headerActionEnabled: !SettingsHubService.busy
    readonly property string headerActionIcon: "document-save-symbolic"
    readonly property string headerActionText: SettingsHubService.busy ? "Saving…" : "Apply & save"
    readonly property bool headerActionVisible: true
    readonly property bool headerResetVisible: baselineState !== "" && JSON.stringify(currentState()) !== baselineState
    property bool revealApiKey: false
    property bool revealGoogleToken: false
    property bool revealKlipyApiKey: false
    property bool revealSteamApiKey: false
    property bool revealWallhavenApiKey: false

    function currentState() {
        return {
            "latLon": locationField.text,
            "apiWeather": apiField.text,
            "launcherKlipyApiKey": klipyApiKeyField.text,
            "steamUsername": steamUsernameField.text,
            "steamWebApiKey": steamApiKeyField.text,
            "wallhavenUsername": wallhavenUsernameField.text,
            "wallhavenApiKey": wallhavenApiKeyField.text,
            "wallpaperEngineAssetsDirPath": engineAssetsField.text,
            "wallpaperEngineWorkshopDirPath": engineWorkshopField.text
        };
    }
    function refreshIntegrations() {
        GoogleService.checkAuthentication();
        EngineWallpaperService.checkAvailability();
        SettingsHubService.refresh();
    }
    function resetPage() {
        syncFields();
    }
    function syncFields() {
        var settings = SettingsHubService.quickshellSettings || ({});
        locationField.text = settings.latLon || Config.latLon;
        apiField.text = settings.apiWeather || Config.apiWeather;
        klipyApiKeyField.text = settings.launcherKlipyApiKey || Config.launcherKlipyApiKey;
        steamUsernameField.text = settings.steamUsername || Config.steamUsername;
        steamApiKeyField.text = settings.steamWebApiKey || Config.steamWebApiKey;
        wallhavenUsernameField.text = settings.wallhavenUsername || Config.wallhavenUsername;
        wallhavenApiKeyField.text = settings.wallhavenApiKey || Config.wallhavenApiKey;
        engineAssetsField.text = settings.wallpaperEngineAssetsDirPath || Config.wallpaperEngineAssetsDirPath;
        engineWorkshopField.text = settings.wallpaperEngineWorkshopDirPath || Config.wallpaperEngineWorkshopDirPath;
        baselineState = JSON.stringify(currentState());
    }
    function triggerHeaderAction() {
        SettingsHubService.saveQuickshell(currentState());
    }

    Component.onCompleted: {
        syncFields();
        Qt.callLater(root.refreshIntegrations);
    }

    Connections {
        function onQuickshellSettingsChanged() {
            root.syncFields();
        }

        target: SettingsHubService
    }
    Connections {
        function onLocationDetected(coordinates) {
            locationField.text = coordinates;
        }

        target: WeatherService
    }
    ScrollView {
        id: scroll

        anchors.fill: parent
        contentHeight: content.implicitHeight
        contentWidth: availableWidth

        ScrollBar.horizontal: SlimScrollBar {
            accentColor: Config.md3.error
        }
        ScrollBar.vertical: SlimScrollBar {
            accentColor: Config.md3.error
        }

        GridLayout {
            id: content

            columnSpacing: 12
            columns: 1
            rowSpacing: 12
            uniformCellWidths: true
            width: scroll.availableWidth
            x: (scroll.availableWidth - width) / 2

            SettingsIntegrationCard {
                id: weatherIntegration

                accentColor: Config.md3.primary
                actionIcon: WeatherService.detectingLocation ? "process-stop-symbolic" : "find-location-symbolic"
                actionText: WeatherService.detectingLocation ? qsTr("Cancel location detection") : qsTr("Detect location")
                actionVisible: true
                iconName: "weather-clear-symbolic"
                note: qsTr("OpenWeatherMap coordinates and credentials")
                statusColor: WeatherService.locationDetectionError ? Config.md3.error : locationField.text !== "" && apiField.text !== "" ? Config.md3.secondary : Config.md3.tertiary
                statusIcon: WeatherService.detectingLocation ? "process-working-symbolic" : WeatherService.locationDetectionError ? "dialog-error-symbolic" : locationField.text !== "" && apiField.text !== "" ? "emblem-ok-symbolic" : "dialog-information-symbolic"
                statusText: WeatherService.detectingLocation ? qsTr("Detecting") : WeatherService.locationDetectionError ? qsTr("Location error") : locationField.text !== "" && apiField.text !== "" ? qsTr("Ready") : qsTr("Setup")
                title: qsTr("Weather")

                onActionClicked: {
                    if (WeatherService.detectingLocation)
                        WeatherService.cancelLocationDetection();
                    else
                        WeatherService.detectLocation();
                }

                GridLayout {
                    id: weatherFields

                    Layout.fillWidth: true
                    columnSpacing: 12
                    columns: width >= 720 ? 2 : 1
                    rowSpacing: 10
                    uniformCellWidths: true

                    SettingsTextField {
                        id: locationField

                        Layout.fillWidth: true
                        label: qsTr("Location")
                        placeholder: "21.03,105.85"
                    }
                    SettingsTextField {
                        id: apiField

                        Layout.fillWidth: true
                        actionIcon: root.revealApiKey ? "view-conceal-symbolic" : "view-reveal-symbolic"
                        echoMode: root.revealApiKey ? TextInput.Normal : TextInput.Password
                        label: qsTr("OpenWeatherMap API key")
                        placeholder: qsTr("Enter API key")

                        onActionClicked: root.revealApiKey = !root.revealApiKey
                    }
                    Text {
                        Layout.columnSpan: weatherFields.columns
                        Layout.fillWidth: true
                        color: WeatherService.locationDetectionError ? Config.md3.error : Config.alpha(Config.md3.on_surface, 0.58)
                        font.family: Config.fontName
                        font.pixelSize: 12
                        text: WeatherService.locationDetectionStatus
                        visible: text !== ""
                        wrapMode: Text.Wrap
                    }
                }
            }
            SettingsIntegrationCard {
                id: googleIntegration

                property bool confirmingRemoval: false
                property Timer removalTimer: Timer {
                    interval: 3000

                    onTriggered: googleIntegration.confirmingRemoval = false
                }

                accentColor: Config.md3.secondary
                actionEnabled: !GoogleService.disconnecting
                actionIcon: confirmingRemoval ? "dialog-warning-symbolic" : "user-trash-symbolic"
                actionText: GoogleService.disconnecting ? qsTr("Removing account") : confirmingRemoval ? qsTr("Confirm account removal") : qsTr("Remove account")
                actionVisible: GoogleService.authenticated || GoogleService.disconnecting
                iconName: "x-office-calendar-symbolic"
                note: GoogleService.authenticated ? (GoogleService.connectedAccount !== "" ? qsTr("Connected as %1").arg(GoogleService.connectedAccount) : qsTr("Connected Google Tasks account")) : GoogleService.authStatus || qsTr("Connect your account from Todo")
                statusColor: GoogleService.authenticated ? Config.md3.secondary : Config.md3.tertiary
                statusIcon: GoogleService.disconnecting ? "process-working-symbolic" : GoogleService.authenticated ? "emblem-ok-symbolic" : "dialog-information-symbolic"
                statusText: GoogleService.disconnecting ? qsTr("Disconnecting") : GoogleService.authenticated ? qsTr("Connected") : qsTr("Not connected")
                title: qsTr("Google Tasks")

                onActionClicked: {
                    if (!confirmingRemoval) {
                        confirmingRemoval = true;
                        removalTimer.restart();
                    } else {
                        confirmingRemoval = false;
                        removalTimer.stop();
                        GoogleService.disconnectAccount();
                    }
                }

                GridLayout {
                    id: googleCredentialFields

                    Layout.fillWidth: true
                    columnSpacing: 12
                    columns: width >= 720 ? 2 : 1
                    rowSpacing: 10
                    uniformCellWidths: true

                    SettingsTextField {
                        Layout.fillWidth: true
                        inputItem.readOnly: true
                        label: qsTr("App ID (Client ID)")
                        placeholder: qsTr("No App ID stored")
                        text: GoogleService.oauthClientId
                    }
                    SettingsTextField {
                        Layout.fillWidth: true
                        actionIcon: GoogleService.oauthClientSecret !== "" ? (root.revealGoogleToken ? "view-conceal-symbolic" : "view-reveal-symbolic") : ""
                        echoMode: root.revealGoogleToken ? TextInput.Normal : TextInput.Password
                        inputItem.readOnly: true
                        label: qsTr("Token (Client Secret)")
                        placeholder: qsTr("No token stored")
                        text: GoogleService.oauthClientSecret

                        onActionClicked: root.revealGoogleToken = !root.revealGoogleToken
                    }
                }
            }
            SettingsIntegrationCard {
                id: klipyIntegration

                accentColor: Config.md3.primary
                actionIcon: "external-link-symbolic"
                actionText: qsTr("Get KLIPY API key")
                actionVisible: true
                iconName: "applications-internet-symbolic"
                note: qsTr("GIF and sticker provider for Launcher; the key is stored in private runtime settings")
                statusColor: klipyApiKeyField.text !== "" ? Config.md3.secondary : Config.md3.tertiary
                statusIcon: klipyApiKeyField.text !== "" ? "emblem-ok-symbolic" : "dialog-information-symbolic"
                statusText: klipyApiKeyField.text !== "" ? qsTr("Configured") : qsTr("Setup required")
                title: qsTr("KLIPY")

                onActionClicked: Qt.openUrlExternally("https://partner.klipy.com")

                SettingsTextField {
                    id: klipyApiKeyField

                    Layout.fillWidth: true
                    actionIcon: root.revealKlipyApiKey ? "view-conceal-symbolic" : "view-reveal-symbolic"
                    echoMode: root.revealKlipyApiKey ? TextInput.Normal : TextInput.Password
                    label: qsTr("API key")
                    placeholder: qsTr("Enter KLIPY API key")

                    onActionClicked: root.revealKlipyApiKey = !root.revealKlipyApiKey
                }
            }
            SettingsIntegrationCard {
                id: engineIntegration

                accentColor: Config.md3.error
                actionIcon: "view-refresh-symbolic"
                actionText: qsTr("Rescan Wallpaper Engine")
                actionVisible: true
                iconName: "applications-games-symbolic"
                note: EngineWallpaperService.errorMessage || qsTr("Steam Workshop paths and account access")
                statusColor: EngineWallpaperService.availabilityKnown ? (EngineWallpaperService.available ? Config.md3.secondary : Config.md3.error) : Config.md3.tertiary
                statusIcon: EngineWallpaperService.availabilityKnown ? (EngineWallpaperService.available ? "emblem-ok-symbolic" : "dialog-error-symbolic") : "process-working-symbolic"
                statusText: EngineWallpaperService.availabilityKnown ? (EngineWallpaperService.available ? qsTr("Ready") : qsTr("Unavailable")) : qsTr("Checking")
                title: qsTr("Wallpaper Engine")

                onActionClicked: EngineWallpaperService.refresh()

                GridLayout {
                    id: engineFields

                    Layout.fillWidth: true
                    columnSpacing: 12
                    columns: width >= 760 ? 2 : 1
                    rowSpacing: 10
                    uniformCellWidths: true

                    SettingsTextField {
                        id: engineAssetsField

                        Layout.fillWidth: true
                        actionIcon: "folder-open-symbolic"
                        label: qsTr("Wallpaper Engine assets")
                        placeholder: "~/.local/share/Steam/steamapps/common/wallpaper_engine/assets"

                        onActionClicked: SettingsHubService.filePickerDialog.open(engineAssetsField, "file://" + Config.expandHomePath("~"), true)
                    }
                    SettingsTextField {
                        id: engineWorkshopField

                        Layout.fillWidth: true
                        actionIcon: "folder-open-symbolic"
                        label: qsTr("Workshop folder")
                        placeholder: "~/.local/share/Steam/steamapps/workshop/content/431960"

                        onActionClicked: SettingsHubService.filePickerDialog.open(engineWorkshopField, "file://" + Config.expandHomePath("~"), true)
                    }
                    SettingsTextField {
                        id: steamUsernameField

                        Layout.fillWidth: true
                        label: qsTr("Steam username")
                        placeholder: qsTr("Account name used by SteamCMD")
                    }
                    SettingsTextField {
                        id: steamApiKeyField

                        Layout.fillWidth: true
                        actionIcon: root.revealSteamApiKey ? "view-conceal-symbolic" : "view-reveal-symbolic"
                        echoMode: root.revealSteamApiKey ? TextInput.Normal : TextInput.Password
                        label: qsTr("Steam Web API key")
                        placeholder: qsTr("Required for Workshop search")

                        onActionClicked: root.revealSteamApiKey = !root.revealSteamApiKey
                    }
                }
            }
            SettingsIntegrationCard {
                id: wallhavenIntegration

                accentColor: Config.md3.tertiary
                iconName: "preferences-desktop-wallpaper-symbolic"
                note: qsTr("Optional account access for collections and NSFW results")
                statusColor: wallhavenApiKeyField.text !== "" ? Config.md3.secondary : Config.md3.tertiary
                statusIcon: wallhavenApiKeyField.text !== "" ? "emblem-ok-symbolic" : "dialog-information-symbolic"
                statusText: wallhavenApiKeyField.text !== "" ? qsTr("Configured") : qsTr("Optional")
                title: qsTr("Wallhaven")

                GridLayout {
                    id: wallhavenFields

                    Layout.fillWidth: true
                    columnSpacing: 12
                    columns: width >= 720 ? 2 : 1
                    rowSpacing: 10
                    uniformCellWidths: true

                    SettingsTextField {
                        id: wallhavenUsernameField

                        Layout.fillWidth: true
                        label: qsTr("Wallhaven username")
                        placeholder: qsTr("Required for Collections")
                    }
                    SettingsTextField {
                        id: wallhavenApiKeyField

                        Layout.fillWidth: true
                        actionIcon: root.revealWallhavenApiKey ? "view-conceal-symbolic" : "view-reveal-symbolic"
                        echoMode: root.revealWallhavenApiKey ? TextInput.Normal : TextInput.Password
                        label: qsTr("Wallhaven API key")
                        placeholder: qsTr("Optional for Browse, required for account access")

                        onActionClicked: root.revealWallhavenApiKey = !root.revealWallhavenApiKey
                    }
                }
            }
        }
    }
}
