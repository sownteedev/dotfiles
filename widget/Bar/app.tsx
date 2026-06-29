import { App, Astal, Gtk, Gdk } from "astal/gtk3";
import { Variable, bind, GLib, execAsync } from "astal";
import Mpris from "gi://AstalMpris";
import Battery from "gi://AstalBattery";
import Network from "gi://AstalNetwork";
import Tray from "gi://AstalTray";
import ActiveClient from "./mods/ActiveClient";
import Workspace from "./mods/Workspace";
import { truncateText } from "../../utils/common";
import { toggleControlMenu } from "../Control/app";

const SysTray = () => {
    const tray = Tray.get_default();
    return (
        <box spacing={25}>
            {bind(tray, "items").as((items) =>
                items.map((item: any) => (
                    <menubutton
                        tooltipMarkup={bind(item, "tooltipMarkup")}
                        usePopover={false}
                        actionGroup={bind(item, "actionGroup").as((ag) => [
                            "dbusmenu",
                            ag,
                        ])}
                        menuModel={bind(item, "menuModel")}
                    >
                        <icon
                            className={"SysTrayIcon"}
                            gicon={bind(item, "gicon")}
                        />
                    </menubutton>
                )),
            )}
        </box>
    );
};

const KhoangTrang = () => {
    return <label className={"Chia"} label={"│"} />;
};

const Date = ({ format = "%a, %d %b %Y" }) => {
    const date = Variable<string>("").poll(
        60000,
        () => GLib.DateTime.new_now_local().format(format)!,
    );

    return (
        <label
            className={"Date"}
            halign={Gtk.Align.END}
            onDestroy={() => date.drop()}
            label={date()}
        />
    );
};

const Time = ({ format = "%I : %M %p" }) => {
    const time = Variable<string>("").poll(
        10000,
        () => GLib.DateTime.new_now_local().format(format)!,
    );

    return (
        <label
            className="Time"
            halign={Gtk.Align.END}
            onDestroy={() => time.drop()}
            label={time()}
        />
    );
};

const BatteryLevel = () => {
    const bat = Battery.get_default();
    const showBatteryName = Variable(false);

    const cleanup = () => {
        showBatteryName.drop();
    };

    return (
        <eventbox
            onHover={() => showBatteryName.set(true)}
            onHoverLost={() => showBatteryName.set(false)}
            onDestroy={cleanup}
        >
            <box className="Battery">
                <icon icon={bind(bat, "battery_icon_name")} />
                <revealer
                    transitionDuration={200}
                    transitionType={Gtk.RevealerTransitionType.SLIDE_LEFT}
                    revealChild={bind(showBatteryName)}
                >
                    <label
                        label={bind(bat, "percentage").as(
                            (p) => Math.floor(p * 100) + "%",
                        )}
                    />
                </revealer>
            </box>
        </eventbox>
    );
};

const Wifi = () => {
    const network = Network.get_default();
    const wifi = network.wifi;
    const showWifiName = Variable(false);

    const cleanup = () => {
        showWifiName.drop();
    };

    const NameWifi = () => {
        return bind(wifi, "state").as((state) => {
            if (state === Network.DeviceState.ACTIVATED) {
                return (
                    <revealer
                        transitionDuration={200}
                        transitionType={Gtk.RevealerTransitionType.SLIDE_LEFT}
                        revealChild={bind(showWifiName)}
                    >
                        <label
                            label={bind(wifi, "ssid").as((ssid) => ssid || "")}
                        />
                    </revealer>
                );
            }
            return <box />;
        });
    };

    return (
        <eventbox
            onHover={() => showWifiName.set(true)}
            onHoverLost={() => showWifiName.set(false)}
            onDestroy={cleanup}
        >
            <box className="Wifi">
                <icon icon={bind(wifi, "iconName")} />
                {NameWifi()}
            </box>
        </eventbox>
    );
};

const Media = () => {
    const mpris = Mpris.get_default();

    const showMediaPlayer = Variable(false);
    const showPlayButton = Variable(false);

    const cleanup = () => {
        showMediaPlayer.drop();
        showPlayButton.drop();
    };

    // Function to prioritize players: Spotify > Web (SoundCloud, Youtube) > Others
    const getPrioritizedPlayer = (
        players: Mpris.Player[],
    ): Mpris.Player | null => {
        if (!players || players.length === 0) return null;

        // Sort players by priority
        const sorted = [...players].sort((a, b) => {
            const aIdentity = a.identity.toLowerCase();
            const bIdentity = b.identity.toLowerCase();

            // Priority 1: Spotify
            const aIsSpotify = aIdentity.includes("spotify");
            const bIsSpotify = bIdentity.includes("spotify");
            if (aIsSpotify && !bIsSpotify) return -1;
            if (!aIsSpotify && bIsSpotify) return 1;

            // Priority 2: Web players (SoundCloud, Youtube)
            const webPlayers = ["soundcloud", "youtube"];
            const aIsWeb = webPlayers.some((wp) => aIdentity.includes(wp));
            const bIsWeb = webPlayers.some((wp) => bIdentity.includes(wp));
            if (aIsWeb && !bIsWeb) return -1;
            if (!aIsWeb && bIsWeb) return 1;

            // Priority 3: Others (keep original order)
            return 0;
        });

        return sorted[0];
    };

    return (
        <box className="Media" onDestroy={cleanup}>
            {bind(mpris, "players").as((arr) => {
                const player = getPrioritizedPlayer(arr);
                return player ? (
                    <box spacing={5}>
                        <eventbox
                            onHover={() => {
                                showPlayButton.set(true);
                                showMediaPlayer.set(true);
                                return false;
                            }}
                            onHoverLost={() => {
                                showPlayButton.set(false);
                                showMediaPlayer.set(false);
                                return false;
                            }}
                            cursor={"hand1"}
                        >
                            <circularprogress
                                className={bind(player, "length").as(
                                    (length) =>
                                        length >= 3600
                                            ? "progress-media live"
                                            : "progress-media",
                                )}
                                endAt={bind(player, "identity").as(
                                    (identity) => {
                                        const laggyPlayers = ["spotify"];
                                        const isLaggy = laggyPlayers.some((p) =>
                                            identity.toLowerCase().includes(p),
                                        );
                                        return isLaggy || player.length >= 3600
                                            ? 1
                                            : player.length >= 0
                                              ? player.length
                                              : 1;
                                    },
                                )}
                                rounded={true}
                                value={bind(player, "position").as(
                                    (position) => {
                                        const identity = player.identity;
                                        const length = player.length;
                                        const laggyPlayers = ["spotify"];
                                        const isLaggy = laggyPlayers.some((p) =>
                                            identity.toLowerCase().includes(p),
                                        );
                                        return isLaggy || length >= 3600
                                            ? 1
                                            : length > 0
                                              ? position / length
                                              : 1;
                                    },
                                )}
                                child={
                                    <overlay>
                                        <box
                                            className="cover-art"
                                            css={bind(player, "coverArt").as(
                                                (c) => {
                                                    if (!c || c === "")
                                                        return "background-color: rgba(255, 255, 255, 0.1);";
                                                    return `background-image: url('${c}'); background-size: cover; background-position: center;`;
                                                },
                                            )}
                                        />
                                        <revealer
                                            transitionType={
                                                Gtk.RevealerTransitionType
                                                    .CROSSFADE
                                            }
                                            transitionDuration={200}
                                            revealChild={bind(showPlayButton)}
                                        >
                                            <button
                                                className="play-pause-bar"
                                                onClicked={() =>
                                                    player.play_pause()
                                                }
                                                visible={bind(
                                                    player,
                                                    "canPause",
                                                )}
                                            >
                                                <icon
                                                    icon={bind(
                                                        player,
                                                        "playbackStatus",
                                                    ).as((s) =>
                                                        s ===
                                                        Mpris.PlaybackStatus
                                                            .PLAYING
                                                            ? "media-playback-pause-symbolic"
                                                            : "media-playback-start-symbolic",
                                                    )}
                                                />
                                            </button>
                                        </revealer>
                                    </overlay>
                                }
                            />
                        </eventbox>
                        <revealer
                            transitionDuration={200}
                            transitionType={
                                Gtk.RevealerTransitionType.SLIDE_LEFT
                            }
                            revealChild={bind(showMediaPlayer)}
                        >
                            <box vertical valign={Gtk.Align.CENTER}>
                                <label
                                    className="title"
                                    halign={Gtk.Align.START}
                                    label={bind(player, "title").as((t) =>
                                        truncateText(t || "Unknown Track", 50),
                                    )}
                                />
                                <label
                                    className="artist"
                                    halign={Gtk.Align.START}
                                    label={bind(player, "artist").as((a) =>
                                        truncateText(a || "Unknown Artist", 50),
                                    )}
                                />
                            </box>
                        </revealer>
                    </box>
                ) : (
                    <label label="" />
                );
            })}
        </box>
    );
};

export default function Bar(gdkmonitor: Gdk.Monitor) {
    const { TOP, LEFT, RIGHT } = Astal.WindowAnchor;

    return (
        <window
            className="Bar"
            gdkmonitor={gdkmonitor}
            exclusivity={Astal.Exclusivity.EXCLUSIVE}
            anchor={TOP | LEFT | RIGHT}
            application={App}
        >
            <centerbox>
                <box halign={Gtk.Align.START} spacing={25}>
                    <ActiveClient />
                    {/* <Media /> */}
                    {/* <MediaCava /> */}
                </box>
                <box>
                    <Workspace />
                </box>
                <box
                    halign={Gtk.Align.END}
                    spacing={25}
                    css={"margin-right: 20px"}
                >
                    <SysTray />
                    <Wifi />
                    <BatteryLevel />
                    <KhoangTrang />
                    <button
                        onClick={toggleControlMenu}
                    >
                        <box vertical>
                            <Time />
                            <Date />
                        </box>
                    </button>
                </box>
            </centerbox>
        </window>
    );
}
