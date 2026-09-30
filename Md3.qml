pragma Singleton
import QtQuick

QtObject {
    id: root

    readonly property QtObject elevation: QtObject {
        function blur(level) {
            return [0, 3, 6, 12, 16, 24][Math.max(0, Math.min(5, level))];
        }
        function offsetY(level) {
            return [0, 1, 2, 3, 4, 6][Math.max(0, Math.min(5, level))];
        }
        function opacity(level) {
            return [0, 0.16, 0.19, 0.22, 0.24, 0.28][Math.max(0, Math.min(5, level))];
        }
        function spread(level) {
            return [0, 0, 0, 0, 0, 1][Math.max(0, Math.min(5, level))];
        }
    }
    readonly property var iconAliases: ({
            "accessories-calculator-symbolic": "calculate",
            "airplane-mode-symbolic": "flight",
            "am-cpu-symbolic": "memory",
            "application-x-executable-symbolic": "deployed_code",
            "applications-engineering-symbolic": "construction",
            "applications-games-symbolic": "sports_esports",
            "applications-graphics-symbolic": "palette",
            "applications-internet-symbolic": "language",
            "applications-multimedia-symbolic": "perm_media",
            "applications-system-symbolic": "settings_applications",
            "appointment-new-symbolic": "event_available",
            "appointment-soon-symbolic": "upcoming",
            "arrow-right-symbolic": "arrow_forward",
            "audio-input-microphone-symbolic": "mic",
            "audio-volume-high-symbolic": "volume_up",
            "audio-volume-low-symbolic": "volume_mute",
            "audio-volume-medium-symbolic": "volume_down",
            "audio-volume-muted-symbolic": "volume_off",
            "audio-x-generic-symbolic": "audio_file",
            "avatar-default-symbolic": "account_circle",
            "battery-caution-symbolic": "battery_alert",
            "battery-full-charging-symbolic": "battery_charging_full",
            "battery-good-symbolic": "battery_full",
            "battery-low-symbolic": "battery_2_bar",
            "battery-symbolic": "battery_full",
            "bell-outline-symbolic": "notifications",
            "bluetooth-acquiring-symbolic": "bluetooth_searching",
            "bluetooth-active-symbolic": "bluetooth_connected",
            "bluetooth-disabled-symbolic": "bluetooth_disabled",
            "bluetooth-disconnected-symbolic": "bluetooth_disabled",
            "bluetooth-hardware-disabled-symbolic": "bluetooth_disabled",
            "bluetooth-symbolic": "bluetooth",
            "caffeine-cup-empty-symbolic": "coffee",
            "caffeine-cup-full-symbolic": "coffee",
            "camera-photo-symbolic": "photo_camera",
            "camera-web-symbolic": "videocam",
            "changes-allow-symbolic": "toggle_on",
            "changes-prevent-symbolic": "lock",
            "checkbox-checked-symbolic": "task_alt",
            "checkbox-symbolic": "check_box_outline_blank",
            "checkmark-symbolic": "check",
            "color-select-symbolic": "colorize",
            "computer-laptop-symbolic": "laptop_mac",
            "contact-new-symbolic": "person_add",
            "content-loading-symbolic": "progress_activity",
            "dark-mode-symbolic": "dark_mode",
            "dialog-error-symbolic": "error",
            "dialog-information-symbolic": "info",
            "dialog-password-symbolic": "key",
            "dialog-warning-symbolic": "warning",
            "display-brightness-symbolic": "brightness_6",
            "document-edit-symbolic": "edit_document",
            "document-import-symbolic": "upload_file",
            "document-open-symbolic": "file_open",
            "document-properties-symbolic": "description",
            "document-save-symbolic": "save",
            "document-send-symbolic": "send",
            "draw-eraser-symbolic": "ink_eraser",
            "drive-harddisk-symbolic": "hard_drive",
            "edit-clear-all-symbolic": "clear_all",
            "edit-clear-symbolic": "backspace",
            "edit-copy-symbolic": "content_copy",
            "edit-paste-symbolic": "content_paste",
            "edit-redo-symbolic": "redo",
            "edit-undo-symbolic": "undo",
            "emblem-ok-symbolic": "check_circle",
            "emblem-synchronizing-symbolic": "sync",
            "emblem-system-symbolic": "tune",
            "emojichooser-symbolic": "mood",
            "external-link-symbolic": "open_in_new",
            "face-smile-symbolic": "sentiment_satisfied",
            "find-location-symbolic": "my_location",
            "focus-windows-symbolic": "center_focus_strong",
            "folder-download-symbolic": "folder_zip",
            "folder-open-symbolic": "folder_open",
            "folder-symbolic": "folder",
            "go-down-symbolic": "keyboard_arrow_down",
            "go-home-symbolic": "home",
            "go-jump-symbolic": "keyboard_double_arrow_right",
            "go-next-symbolic": "chevron_right",
            "go-previous-symbolic": "chevron_left",
            "go-up-symbolic": "keyboard_arrow_up",
            "goa-account-google-symbolic": "account_circle",
            "image-crop-symbolic": "crop",
            "image-missing-symbolic": "hide_image",
            "image-x-generic-symbolic": "image",
            "input-keyboard-symbolic": "keyboard",
            "input-mouse-symbolic": "mouse",
            "input-touchpad-symbolic": "touch_app",
            "insert-image-symbolic": "add_photo_alternate",
            "insert-object-symbolic": "add_box",
            "internet-services-symbolic": "cloud",
            "internet-web-browser-symbolic": "public",
            "link-symbolic": "link",
            "list-add-symbolic": "add",
            "mail-message-new-symbolic": "mail",
            "mark-location-symbolic": "pin_drop",
            "media-playback-pause-symbolic": "pause",
            "media-playback-start-symbolic": "play_arrow",
            "media-playlist-repeat-symbolic": "repeat",
            "media-playlist-shuffle-symbolic": "shuffle",
            "media-record-symbolic": "fiber_manual_record",
            "media-skip-backward-symbolic": "skip_previous",
            "media-skip-forward-symbolic": "skip_next",
            "media-view-subtitles-symbolic": "lyrics",
            "microphone-sensitivity-high-symbolic": "mic",
            "microphone-sensitivity-muted-symbolic": "mic_off",
            "multimedia-audio-player-symbolic": "music_note",
            "network-error-symbolic": "signal_wifi_bad",
            "network-offline-symbolic": "wifi_off",
            "network-wired-symbolic": "lan",
            "network-wireless-encrypted-symbolic": "wifi_password",
            "network-wireless-hotspot-symbolic": "wifi_tethering",
            "network-wireless-signal-excellent-symbolic": "signal_wifi_4_bar",
            "network-wireless-signal-good-symbolic": "network_wifi_3_bar",
            "network-wireless-signal-none-symbolic": "signal_wifi_0_bar",
            "network-wireless-signal-ok-symbolic": "network_wifi_2_bar",
            "network-wireless-signal-weak-symbolic": "network_wifi_1_bar",
            "network-wireless-symbolic": "wifi",
            "network-workgroup-symbolic": "hub",
            "night-light-symbolic": "nightlight",
            "non-starred-symbolic": "star",
            "notifications-disabled-symbolic": "notifications_off",
            "object-locked-symbolic": "lock",
            "object-rotate-right-symbolic": "rotate_right",
            "object-select-symbolic": "select_check_box",
            "package-x-generic-symbolic": "package_2",
            "pan-down-symbolic": "expand_more",
            "power-profile-balanced-symbolic": "balance",
            "preferences-desktop-display-symbolic": "monitor",
            "preferences-desktop-effects-symbolic": "animation",
            "preferences-desktop-font-symbolic": "font_download",
            "preferences-desktop-keyboard-shortcuts-symbolic": "keyboard_command_key",
            "preferences-desktop-theme-symbolic": "format_paint",
            "preferences-desktop-wallpaper-symbolic": "wallpaper",
            "preferences-desktop-workspaces-symbolic": "view_carousel",
            "preferences-other-symbolic": "more_horiz",
            "preferences-system-notifications-symbolic": "notifications",
            "preferences-system-power-symbolic": "power_settings_new",
            "preferences-system-symbolic": "settings",
            "preferences-system-time-symbolic": "schedule",
            "preferences-system-windows-symbolic": "select_window",
            "process-stop-symbolic": "stop_circle",
            "process-working-symbolic": "progress_activity",
            "qrscanner-symbolic": "qr_code_scanner",
            "screenshot-ui-show-pointer-symbolic": "ads_click",
            "selection-mode-symbolic": "select_all",
            "software-update-available-symbolic": "system_update_alt",
            "speedometer-symbolic": "speed",
            "starred-symbolic": "star",
            "steam-symbolic": "sports_esports",
            "system-file-manager-symbolic": "folder_copy",
            "system-hibernate-symbolic": "bedtime",
            "system-lock-screen-symbolic": "lock",
            "system-log-out-symbolic": "logout",
            "system-reboot-symbolic": "restart_alt",
            "system-run-symbolic": "rocket_launch",
            "system-search-symbolic": "search",
            "system-shutdown-symbolic": "power_settings_new",
            "system-software-update-symbolic": "system_update_alt",
            "system-suspend-symbolic": "mode_standby",
            "text-x-generic-symbolic": "text_fields",
            "user-trash-symbolic": "delete",
            "utilities-system-monitor-symbolic": "monitoring",
            "utilities-terminal-symbolic": "terminal",
            "video-display-symbolic": "desktop_windows",
            "video-x-generic-symbolic": "video_library",
            "view-column-symbolic": "view_column",
            "view-conceal-symbolic": "visibility_off",
            "view-dual-symbolic": "vertical_split",
            "view-filter-symbolic": "filter_alt",
            "view-grid-symbolic": "grid_view",
            "view-list-symbolic": "view_list",
            "view-more-horizontal-symbolic": "more_horiz",
            "view-refresh-symbolic": "refresh",
            "view-restore-symbolic": "history",
            "view-reveal-symbolic": "visibility",
            "view-sort-descending-symbolic": "sort",
            "view-visible-symbolic": "visibility",
            "weather-clear-night-symbolic": "nightlight",
            "weather-clear-symbolic": "sunny",
            "weather-clouds-night-symbolic": "partly_cloudy_night",
            "weather-clouds-symbolic": "partly_cloudy_day",
            "weather-few-clouds-night-symbolic": "partly_cloudy_night",
            "weather-few-clouds-symbolic": "partly_cloudy_day",
            "weather-fog-symbolic": "foggy",
            "weather-none-available-symbolic": "help",
            "weather-overcast-night-symbolic": "cloudy_snowing",
            "weather-overcast-symbolic": "cloud",
            "weather-severe-alert-symbolic": "thunderstorm",
            "weather-showers-scattered-symbolic": "rainy_light",
            "weather-showers-symbolic": "rainy",
            "weather-snow-night-symbolic": "weather_snowy",
            "weather-snow-symbolic": "weather_snowy",
            "weather-storm-symbolic": "thunderstorm",
            "weather-windy-symbolic": "air",
            "web-browser-symbolic": "language",
            "window-close-symbolic": "close",
            "window-maximize-symbolic": "fullscreen",
            "window-new-symbolic": "open_in_new",
            "window-restore-symbolic": "fullscreen_exit",
            "x-office-calendar-symbolic": "calendar_month",
            "zoom-fit-best-symbolic": "fit_screen"
        })
    // Generated from the Material Symbols Rounded codepoint catalog. Qt does
    // not shape the font's ligature names reliably, so render the glyphs by
    // their stable private-use codepoints instead.
    readonly property var iconCodepoints: ({
            "account_circle": 0xf20b,
            "add": 0xe145,
            "add_box": 0xe146,
            "add_photo_alternate": 0xe43e,
            "ads_click": 0xe762,
            "air": 0xefd8,
            "animation": 0xe71c,
            "arrow_forward": 0xe5c8,
            "audio_file": 0xeb82,
            "backspace": 0xe14a,
            "balance": 0xeaf6,
            "battery_2_bar": 0xf09d,
            "battery_alert": 0xe19c,
            "battery_charging_full": 0xe1a3,
            "battery_full": 0xe1a5,
            "bedtime": 0xf159,
            "bluetooth": 0xe1a7,
            "bluetooth_connected": 0xe1a8,
            "bluetooth_disabled": 0xe1a9,
            "bluetooth_searching": 0xe60f,
            "brightness_6": 0xe3ab,
            "calculate": 0xea5f,
            "calendar_month": 0xebcc,
            "center_focus_strong": 0xe3b4,
            "check": 0xe5ca,
            "check_box": 0xe9de,
            "check_box_outline_blank": 0xe835,
            "check_circle": 0xf0be,
            "chevron_left": 0xe5cb,
            "chevron_right": 0xe5cc,
            "clear_all": 0xe0b8,
            "close": 0xe5cd,
            "cloud": 0xf15c,
            "cloudy_snowing": 0xe810,
            "coffee": 0xefef,
            "colorize": 0xe3b8,
            "construction": 0xea3c,
            "content_copy": 0xe14d,
            "content_paste": 0xe14f,
            "crop": 0xe3be,
            "dark_mode": 0xe51c,
            "delete": 0xe92e,
            "deployed_code": 0xf720,
            "description": 0xe873,
            "desktop_windows": 0xe30c,
            "edit_document": 0xf88c,
            "error": 0xf8b6,
            "event_available": 0xe614,
            "expand_more": 0xe5cf,
            "fiber_manual_record": 0xe061,
            "file_open": 0xeaf3,
            "filter_alt": 0xef4f,
            "fit_screen": 0xea10,
            "flight": 0xe539,
            "foggy": 0xe818,
            "folder": 0xe2c7,
            "folder_copy": 0xebbd,
            "folder_open": 0xe2c8,
            "folder_zip": 0xeb2c,
            "font_download": 0xe167,
            "format_paint": 0xe243,
            "fullscreen": 0xe5d0,
            "fullscreen_exit": 0xe5d1,
            "grid_view": 0xe9b0,
            "hard_drive": 0xf80e,
            "help": 0xe8fd,
            "hide_image": 0xf022,
            "history": 0xe8b3,
            "home": 0xe9b2,
            "hub": 0xe9f4,
            "image": 0xe3f4,
            "info": 0xe88e,
            "ink_eraser": 0xe6d0,
            "key": 0xe73c,
            "keyboard": 0xe312,
            "keyboard_arrow_down": 0xe313,
            "keyboard_arrow_up": 0xe316,
            "keyboard_command_key": 0xeae7,
            "keyboard_double_arrow_right": 0xeac9,
            "lan": 0xeb2f,
            "language": 0xea07,
            "laptop_mac": 0xe320,
            "link": 0xe250,
            "lock": 0xe899,
            "logout": 0xe9ba,
            "lyrics": 0xec0b,
            "mail": 0xe159,
            "memory": 0xe322,
            "mic": 0xe31d,
            "mic_off": 0xe02b,
            "mode_standby": 0xf037,
            "monitor": 0xef5b,
            "monitoring": 0xf190,
            "mood": 0xea22,
            "more_horiz": 0xe5d3,
            "mouse": 0xe323,
            "music_note": 0xe405,
            "my_location": 0xe55c,
            "network_wifi_1_bar": 0xebe4,
            "network_wifi_2_bar": 0xebd6,
            "network_wifi_3_bar": 0xebe1,
            "nightlight": 0xf03d,
            "notifications": 0xe7f5,
            "notifications_off": 0xe7f6,
            "open_in_new": 0xe89e,
            "package_2": 0xf569,
            "palette": 0xe40a,
            "pan_tool_alt": 0xebb9,
            "partly_cloudy_day": 0xf172,
            "partly_cloudy_night": 0xf174,
            "pause": 0xe034,
            "perm_media": 0xe8a7,
            "person_add": 0xea4d,
            "photo_camera": 0xe412,
            "pin_drop": 0xe55e,
            "play_arrow": 0xe037,
            "power_settings_new": 0xf8c7,
            "progress_activity": 0xe9d0,
            "public": 0xe80b,
            "qr_code_scanner": 0xf206,
            "rainy": 0xf176,
            "rainy_light": 0xf61e,
            "redo": 0xe15a,
            "refresh": 0xe5d5,
            "repeat": 0xe040,
            "repeat_one": 0xe041,
            "restart_alt": 0xf053,
            "rocket_launch": 0xeb9b,
            "rotate_right": 0xe41a,
            "save": 0xe161,
            "schedule": 0xefd6,
            "search": 0xe8b6,
            "select_all": 0xe162,
            "select_check_box": 0xf1fe,
            "select_window": 0xe6fa,
            "send": 0xe163,
            "sentiment_satisfied": 0xe813,
            "settings": 0xe8b8,
            "settings_applications": 0xe8b9,
            "shuffle": 0xe043,
            "signal_wifi_0_bar": 0xf0b0,
            "signal_wifi_4_bar": 0xf065,
            "signal_wifi_bad": 0xf064,
            "skip_next": 0xe044,
            "skip_previous": 0xe045,
            "sort": 0xe164,
            "speed": 0xe9e4,
            "sports_esports": 0xea28,
            "star": 0xf09a,
            "stop_circle": 0xef71,
            "sunny": 0xe81a,
            "sync": 0xe627,
            "system_update_alt": 0xe8d7,
            "task_alt": 0xe2e6,
            "terminal": 0xeb8e,
            "text_fields": 0xe262,
            "thunderstorm": 0xebdb,
            "toggle_off": 0xe9f5,
            "toggle_on": 0xe9f6,
            "touch_app": 0xe913,
            "tune": 0xe429,
            "undo": 0xe166,
            "upcoming": 0xf07e,
            "upload_file": 0xe9fc,
            "vertical_split": 0xe949,
            "video_library": 0xe04a,
            "videocam": 0xe04b,
            "view_carousel": 0xe8eb,
            "view_column": 0xe8ec,
            "view_list": 0xe8ef,
            "visibility": 0xe8f4,
            "visibility_off": 0xe8f5,
            "volume_down": 0xe04d,
            "volume_mute": 0xe04e,
            "volume_off": 0xe04f,
            "volume_up": 0xe050,
            "wallpaper": 0xe1bc,
            "warning": 0xf083,
            "weather_snowy": 0xe2cd,
            "wifi": 0xe63e,
            "wifi_off": 0xe648,
            "wifi_password": 0xeb6b,
            "wifi_tethering": 0xe1e2
        })
    readonly property var iconFallbackAliases: ({
            "check": "checkmark-symbolic",
            "chevron_right": "go-next-symbolic",
            "close": "window-close-symbolic",
            "expand_more": "go-down-symbolic",
            "repeat_one": "media-playlist-repeat-symbolic",
            "search": "system-search-symbolic"
        })
    readonly property FontLoader iconFont: FontLoader {
        source: "file:///usr/share/fonts/TTF/MaterialSymbolsRounded%5BFILL,GRAD,opsz,wght%5D.ttf"
    }
    readonly property string iconFontFamily: iconFont.status === FontLoader.Ready ? iconFont.name : "Material Symbols Rounded"
    readonly property bool iconsAvailable: iconFont.status === FontLoader.Ready || Qt.fontFamilies().indexOf("Material Symbols Rounded") !== -1
    readonly property QtObject motion: QtObject {

        // Semantic motion roles. Widgets should use these names instead of
        // choosing their own durations/easings so the shell feels like one
        // expressive system.
        readonly property int componentEnter: medium3
        readonly property int componentExit: short4
        readonly property int containerTransform: medium3

        // Qt's easing enum is the portable approximation used by QML
        // transitions. Keep these in one place so components do not drift
        // between unrelated curves.
        readonly property int emphasized: Easing.InOutCubic
        readonly property int emphasizedAccelerate: Easing.InCubic
        readonly property int emphasizedDecelerate: Easing.OutCubic
        readonly property int emphasizedSpatial: Easing.OutBack
        readonly property int enterEasing: emphasizedDecelerate
        readonly property int exitEasing: emphasizedAccelerate
        readonly property int extraLong1: 700
        readonly property int extraLong2: 800
        readonly property int extraLong3: 900
        readonly property int extraLong4: 1000
        readonly property int listReflow: medium2
        readonly property int long1: 450
        readonly property int long2: 500
        readonly property int long3: 550
        readonly property int long4: 600
        readonly property int medium1: 250
        readonly property int medium2: 300
        readonly property int medium3: 350
        readonly property int medium4: 400
        readonly property int short1: 50
        readonly property int short2: 100
        readonly property int short3: 150
        readonly property int short4: 200
        readonly property int standard: Easing.InOutCubic
        readonly property int standardAccelerate: Easing.InQuad
        readonly property int standardDecelerate: Easing.OutQuad
        readonly property int stateChange: short3
        readonly property int transformEasing: emphasized

        function durationFor(role) {
            if (role === "enter")
                return componentEnter;
            if (role === "exit")
                return componentExit;
            if (role === "transform" || role === "spatial")
                return containerTransform;
            if (role === "microSpatial")
                return stateChange;
            if (role === "reflow")
                return listReflow;
            return stateChange;
        }
        function easingFor(role) {
            if (role === "enter")
                return enterEasing;
            if (role === "exit")
                return exitEasing;
            if (role === "spatial" || role === "microSpatial")
                return emphasizedSpatial;
            if (role === "transform")
                return transformEasing;
            return standard;
        }
    }
    readonly property QtObject shape: QtObject {
        readonly property real extraLarge: 28
        readonly property real extraLargeIncreased: 32
        readonly property real extraSmall: 4
        readonly property real full: 999
        readonly property real large: 16
        readonly property real largeIncreased: 20
        readonly property real medium: 12
        readonly property real none: 0
        readonly property real small: 8
    }
    readonly property QtObject spacing: QtObject {
        readonly property real lg: 24
        readonly property real md: 16
        readonly property real sm: 12
        readonly property real xl: 32
        readonly property real xs: 8
        readonly property real xxl: 48
        readonly property real xxs: 4
    }
    readonly property QtObject state: QtObject {
        readonly property real disabledContainer: 0.12
        readonly property real disabledContent: 0.38
        readonly property real dragged: 0.16
        readonly property real focus: 0.10
        readonly property real hover: 0.08
        readonly property real pressed: 0.10
    }
    // Complete MD3 type roles for components that need more than a font size.
    // The legacy numeric properties above remain available for compatibility.
    readonly property var typeScale: ({
            "bodyLarge": {
                "letterSpacing": 0.5,
                "lineHeight": 20,
                "size": 14,
                "weight": 400
            },
            "bodyMedium": {
                "letterSpacing": 0.25,
                "lineHeight": 18,
                "size": 13,
                "weight": 400
            },
            "bodySmall": {
                "letterSpacing": 0.4,
                "lineHeight": 16,
                "size": 11,
                "weight": 400
            },
            "displayLarge": {
                "letterSpacing": -0.25,
                "lineHeight": 58,
                "size": 51,
                "weight": 400
            },
            "displayMedium": {
                "letterSpacing": 0,
                "lineHeight": 47,
                "size": 41,
                "weight": 400
            },
            "displaySmall": {
                "letterSpacing": 0,
                "lineHeight": 40,
                "size": 32,
                "weight": 400
            },
            "headlineLarge": {
                "letterSpacing": 0,
                "lineHeight": 36,
                "size": 29,
                "weight": 400
            },
            "headlineMedium": {
                "letterSpacing": 0,
                "lineHeight": 32,
                "size": 25,
                "weight": 400
            },
            "headlineSmall": {
                "letterSpacing": 0,
                "lineHeight": 28,
                "size": 22,
                "weight": 400
            },
            "labelLarge": {
                "emphasizedWeight": 600,
                "letterSpacing": 0.1,
                "lineHeight": 18,
                "size": 13,
                "weight": 500
            },
            "labelMedium": {
                "letterSpacing": 0.5,
                "lineHeight": 16,
                "size": 11,
                "weight": 500
            },
            "labelSmall": {
                "letterSpacing": 0.5,
                "lineHeight": 14,
                "size": 10,
                "weight": 500
            },
            "titleLarge": {
                "emphasizedWeight": 600,
                "letterSpacing": 0,
                "lineHeight": 24,
                "size": 20,
                "weight": 400
            },
            "titleMedium": {
                "emphasizedWeight": 600,
                "letterSpacing": 0.15,
                "lineHeight": 20,
                "size": 14,
                "weight": 500
            },
            "titleSmall": {
                "letterSpacing": 0.1,
                "lineHeight": 18,
                "size": 13,
                "weight": 500
            }
        })
    // Explicit desktop type values shared by every shell surface. Keep these
    // concrete so the rendered size is visible directly while debugging.
    readonly property QtObject typography: QtObject {
        readonly property real bodyLarge: 14
        readonly property real bodyMedium: 13
        readonly property real bodySmall: 11
        readonly property real displayLarge: 51
        readonly property real displayMedium: 41
        readonly property real displaySmall: 32
        readonly property real headlineLarge: 29
        readonly property real headlineMedium: 25
        readonly property real headlineSmall: 22
        readonly property real labelLarge: 13
        readonly property real labelMedium: 11
        readonly property real labelSmall: 10
        readonly property real titleLarge: 20
        readonly property real titleMedium: 14
        readonly property real titleSmall: 13
    }

    function iconCodepoint(name) {
        const symbol = iconName(name);
        return symbol === "" ? 0 : (iconCodepoints[symbol] || 0);
    }
    function iconFallbackName(name) {
        const key = String(name || "");
        if (key === "")
            return "";
        return iconFallbackAliases[key] || key;
    }
    function iconName(name) {
        const key = String(name || "");
        if (key === "")
            return "";
        return iconAliases[key] || key.replace(/-symbolic$/, "").replace(/-/g, "_");
    }
    function iconText(name) {
        const codepoint = iconCodepoint(name);
        return codepoint > 0 ? String.fromCodePoint(codepoint) : "";
    }
}
