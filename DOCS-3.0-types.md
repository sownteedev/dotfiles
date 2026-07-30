# Quickshell v0.3.0 — Type usage checklist

Nguồn type: [Quickshell v0.3.0 types](https://quickshell.org/docs/v0.3.0/types/).

Checklist này được đối chiếu với code trong thư mục `quickshell/` ngày 17/07/2026.

- `[x]`: đang được dùng trực tiếp hoặc qua object mà API trả về.
- `[ ]`: chưa dùng, nhưng vẫn có thể hữu ích cho một tính năng sau này.
- `⛔`: không cần cho setup Niri hiện tại, đã có giải pháp khác hoặc chỉ là type nội bộ cấp thấp.

## Quickshell core

- [x] Quickshell
    - ⛔ BoundComponent
    - ⛔ ColorQuantizer — màu giao diện đã được Matugen sinh từ wallpaper.
    - ⛔ DesktopAction
    - [x] DesktopEntries
    - [x] DesktopEntry — dùng cho launcher, workspace, notification và audio stream icon.
    - ⛔ EasingCurve — animation hiện dùng trực tiếp các giá trị `Easing.*`.
    - [x] Edges — neo popup menu của System Tray.
    - ⛔ ElapsedTimer — countdown đang dùng deadline thực với `Date.now()`.
    - [x] ExclusionMode
    - ⛔ FloatingWindow
    - ⛔ Intersection
    - [x] LazyLoader
    - ⛔ ObjectModel — các model hiện dùng `ListModel`, `ScriptModel` hoặc model native.
    - [x] PanelWindow
    - [ ] PersistentProperties — không còn cần; state DND/Caffeine đã chuyển sang `JsonAdapter`.
    - ⛔ PopupAdjustment
    - [x] PopupAnchor — dùng qua `PopupWindow.anchor`.
    - [x] PopupWindow — menu System Tray.
    - ⛔ QsMenuAnchor
    - [x] QsMenuButtonType — dùng qua trạng thái checkbox/radio của menu.
    - [x] QsMenuEntry — các entry do `QsMenuOpener` trả về.
    - [x] QsMenuHandle — menu của System Tray item.
    - [x] QsMenuOpener
    - [x] Quickshell
    - [x] QuickshellSettings — `settings.watchFiles` trong shell chính.
    - ⛔ Region
    - ⛔ RegionShape
    - ⛔ Reloadable
    - ⛔ Retainable
    - ⛔ RetainableLock
    - [x] Scope — tạo backdrop theo từng màn hình.
    - [x] ScriptModel — lọc/sắp xếp danh sách Wi-Fi.
    - [x] ShellRoot
    - [x] ShellScreen — các object trong `Quickshell.screens`.
    - [x] Singleton — Config và toàn bộ service.
    - [x] SystemClock — đồng hồ trên bar.
    - ⛔ TransformWatcher
    - [x] Variants — Bar, OSD, notification, screenshot editor, wallpaper và backdrop theo màn hình.

## Bluetooth

- [x] Quickshell.Bluetooth
    - [x] Bluetooth
    - [x] BluetoothAdapter
    - [x] BluetoothAdapterState
    - [x] BluetoothDevice
    - [x] BluetoothDeviceState

## DBus menu

- ⛔ Quickshell.DBusMenu — không import trực tiếp; menu DBus của tray đã được `SystemTray` + `QsMenuOpener` bọc lại.
    - ⛔ DBusMenuHandle
    - ⛔ DBusMenuItem

## Compositor-specific modules

- ⛔ Quickshell.Hyprland — compositor hiện tại là Niri.
    - ⛔ GlobalShortcut
    - ⛔ Hyprland
    - ⛔ HyprlandEvent
    - ⛔ HyprlandFocusGrab
    - ⛔ HyprlandMonitor
    - ⛔ HyprlandToplevel
    - ⛔ HyprlandWindow
    - ⛔ HyprlandWorkspace

- ⛔ Quickshell.I3 — workspace/window được lấy từ Niri event stream.
    - ⛔ I3
    - ⛔ I3Event
    - ⛔ I3IpcListener
    - ⛔ I3Monitor
    - ⛔ I3Workspace

## I/O and processes

- [x] Quickshell.Io
    - ⛔ DataStream
    - ⛔ DataStreamParser
    - [x] FileView
    - [x] FileViewAdapter — được `FileView` sử dụng nội bộ.
    - [x] FileViewError — xử lý qua các signal load failure.
    - [x] IpcHandler — launcher, power, wallpaper và capture IPC.
    - [x] JsonAdapter — lưu settings runtime và state DND/Caffeine theo schema cố định, không còn parse/stringify JSON thủ công.
    - [ ] JsonObject
    - [x] Process
    - ⛔ Socket
    - ⛔ SocketServer
    - [x] SplitParser
    - [x] StdioCollector

## Networking

- [x] Quickshell.Networking
    - [x] ConnectionFailReason
    - [x] ConnectionState
    - [x] DeviceType
    - [x] NMSettings — đọc/ghi IPv4, DNS và autoconnect trực tiếp trên profile Wi-Fi; chỉ còn telemetry dùng lệnh hệ thống.
    - [x] Network
    - ⛔ NetworkBackendType
    - [x] NetworkConnectivity — trạng thái Internet đầy đủ, limited, offline và captive portal trên Bar/trang Wi-Fi.
    - [x] NetworkDevice
    - [x] Networking
    - [x] WifiDevice
    - ⛔ WifiDeviceMode
    - [x] WifiNetwork
    - [x] WifiSecurityType
    - [x] WiredDevice — phát hiện Ethernet trên bar.

## Login and authentication

- ⛔ Quickshell.Services.Greetd — chỉ cần nếu viết cả greeter/login manager.
    - ⛔ Greetd
    - ⛔ GreetdState

- [x] Quickshell.Services.Pam
    - [x] PamContext — xác thực lock screen.
    - [x] PamError — nhận lỗi PAM qua signal.
    - [x] PamResult

- [x] Quickshell.Services.Polkit
    - [x] AuthFlow — prompt, submit/cancel và trạng thái xác thực.
    - [x] PolkitAgent — thay `polkit-gnome-authentication-agent`.

## Media

- [x] Quickshell.Services.Mpris
    - [x] Mpris
    - [x] MprisLoopState — chuyển repeat off/playlist/track trong trang Music.
    - [x] MprisPlaybackState
    - [x] MprisPlayer

## Notifications

- [x] Quickshell.Services.Notifications
    - [x] Notification
    - [x] NotificationAction
    - [ ] NotificationCloseReason — chưa cần hiển thị lý do đóng.
    - [x] NotificationServer
    - [x] NotificationUrgency

## PipeWire audio

- [x] Quickshell.Services.Pipewire
    - [ ] PwAudioChannel — balance hiện thao tác trực tiếp trên mảng volume.
    - [x] PwLink — tìm thiết bị đích của từng application stream.
    - [x] PwLinkGroup — các kết nối microphone do `PwNodeLinkTracker` trả về.
    - ⛔ PwLinkState
    - [x] PwNode
    - [x] PwNodeAudio
    - [x] PwNodeLinkTracker — privacy indicator và danh sách ứng dụng đang dùng microphone.
    - [x] PwNodePeakMonitor — peak meter realtime cho từng application recording stream; chỉ enable khi popup microphone mở.
    - [x] PwNodeType — phân biệt stream, sink và source qua node metadata.
    - [x] PwObjectTracker — giữ node audio cho OSD và Volume page.

## System tray

- [x] Quickshell.Services.SystemTray
    - [x] Category — metadata của tray item.
    - [x] Status — metadata của tray item.
    - [x] SystemTray
    - [x] SystemTrayItem

## Battery and power

- [x] Quickshell.Services.UPower
    - [x] PerformanceDegradationReason — cảnh báo khi profile hiệu năng bị giới hạn vì nhiệt độ cao hoặc đặt máy trên đùi.
    - ⛔ PowerProfile — setup ưu tiên auto-cpufreq; power-profiles-daemon chỉ là fallback.
    - ⛔ PowerProfiles
    - [x] UPower
    - [x] UPowerDevice
    - [x] UPowerDeviceState
    - [x] UPowerDeviceType — nhận dạng pin laptop qua display device.

## Wayland

- [x] Quickshell.Wayland
    - ⛔ BackgroundEffect — blur hiện do rule/layer namespace của Niri xử lý.
    - [x] IdleInhibitor — Caffeine.
    - ⛔ IdleMonitor — timeout lock/screen-off đã do `swayidle` quản lý.
    - ⛔ ScreencopyView — không dùng để tránh thêm full-screen texture/RAM.
    - ⛔ ShortcutInhibitor
    - [x] Toplevel
    - [x] ToplevelManager — ActiveClient trên bar.
    - [x] WlSessionLock
    - [x] WlSessionLockSurface
    - [x] WlrKeyboardFocus — Settings Hub dùng `Exclusive` để bắt tổ hợp phím khi chỉnh keybind.
    - [x] WlrLayer
    - [x] WlrLayershell

## Widgets

- [x] Quickshell.Widgets
    - [x] ClippingRectangle — cắt artwork media thành hình tròn.
    - ⛔ ClippingWrapperRectangle
    - [x] IconImage
    - ⛔ MarginWrapperManager
    - ⛔ WrapperItem
    - ⛔ WrapperManager
    - ⛔ WrapperMouseArea
    - ⛔ WrapperRectangle

## Generic WindowManager

- ⛔ Quickshell.WindowManager — Niri workspace dùng event stream riêng; active window đã dùng Wayland `ToplevelManager`.
    - ⛔ ScreenProjection
    - ⛔ WindowManager
    - ⛔ Windowset
    - ⛔ WindowsetProjection

## Các type còn đáng cân nhắc

1. `JsonObject`: chưa cần dùng riêng; các state JSON có schema cố định đã được chuẩn hóa bằng `JsonAdapter`.
