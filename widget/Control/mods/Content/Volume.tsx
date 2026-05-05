import { bind, Variable } from "astal";
import { Gtk, Gdk } from "astal/gtk3";
import Wp from "gi://AstalWp";
import { sanitizeUtf8, truncateText } from "../../../../utils/common";
import { getIcon } from "../../../../utils/icon";

const InputOutputList = () => {
    const wp = Wp.get_default()!;
    const audio = wp.audio;

    const defaultSpeaker = audio.defaultSpeaker;
    const defaultMicrophone = audio.defaultMicrophone;

    const streams = Variable(audio.get_streams())
        .observe(audio, "stream-added", () => audio.get_streams())
        .observe(audio, "stream-removed", () => audio.get_streams());

    const cleanup = () => {
        streams.drop();
    };

    const ApplicationItem = () => {
        return (
            <box vertical spacing={10} className="application-volume-container">
                <label
                    label="Applications"
                    className="application-title"
                    xalign={0}
                />
                <box vertical spacing={10}>
                    {bind(streams).as((streams) => {
                        if (!streams || streams.length === 0) {
                            return (
                                <label
                                    label="No active audio applications"
                                    xalign={0.5}
                                    className="no-applications"
                                />
                            );
                        }

                        return streams?.map((stream: any) => {
                            const appInfo = getIcon(stream.description);
                            const streamIcon =
                                appInfo?.icon_name ||
                                stream.icon ||
                                "audio-volume-high-symbolic";

                            return (
                                <box
                                    vertical
                                    className={"application-volume-item"}
                                >
                                    <centerbox>
                                        <box spacing={10}>
                                            <icon
                                                icon={streamIcon}
                                                className="application-icon"
                                            />
                                            <label
                                                label={truncateText(
                                                    sanitizeUtf8(
                                                        stream.description +
                                                            ": " +
                                                            stream.name
                                                    ),
                                                    45
                                                )}
                                                halign={Gtk.Align.START}
                                                className="application-name"
                                            />
                                        </box>
                                        <box />
                                        <box spacing={5} halign={Gtk.Align.END}>
                                            <button
                                                className="action-button"
                                                onClicked={() =>
                                                    (stream.mute = !stream.mute)
                                                }
                                                cursor={"hand1"}
                                            >
                                                <icon
                                                    icon={bind(
                                                        stream,
                                                        "mute"
                                                    ).as((muted) =>
                                                        muted
                                                            ? "audio-volume-muted-symbolic"
                                                            : "audio-volume-high-symbolic"
                                                    )}
                                                />
                                            </button>
                                            <label
                                                label={bind(
                                                    stream,
                                                    "volume"
                                                ).as(
                                                    (vol) =>
                                                        `${Math.floor(
                                                            (vol ? vol : 0) *
                                                                100
                                                        )}%`
                                                )}
                                                xalign={1}
                                            />
                                        </box>
                                    </centerbox>
                                    <slider
                                        className="volume-slider-application"
                                        hexpand
                                        value={bind(stream, "volume")}
                                        onValueChanged={(slider: any) =>
                                            (stream.volume = slider.value)
                                        }
                                        cursor={"hand1"}
                                    />
                                </box>
                            );
                        });
                    })}
                </box>
            </box>
        );
    };

    const VolumeSlider = ({
        endpoint,
        label,
    }: {
        endpoint: any;
        label: string;
    }) => {
        if (!endpoint) return null;

        const isInputDevice = label.includes("Input");

        return (
            <box className="volume-slider-control" vertical spacing={5}>
                <box spacing={10}>
                    <button
                        className={bind(endpoint, "mute").as(
                            (muted) => `mute-button ${muted ? "muted" : ""}`
                        )}
                        onClicked={() => (endpoint.mute = !endpoint.mute)}
                        cursor={"hand1"}
                    >
                        <icon
                            icon={bind(endpoint, "mute").as((muted) => {
                                if (isInputDevice) {
                                    return muted
                                        ? "microphone-sensitivity-muted-symbolic"
                                        : "audio-input-microphone-symbolic";
                                } else {
                                    return muted
                                        ? "audio-volume-muted-symbolic"
                                        : "audio-volume-high-symbolic";
                                }
                            })}
                        />
                    </button>
                    <label
                        label={bind(endpoint, "volume").as(
                            (vol) => `${Math.floor((vol ? vol : 0) * 100)}%`
                        )}
                        className="volume-percentage"
                    />
                </box>
                <slider
                    className="volume-slider"
                    hexpand
                    onValueChanged={(slider: any) =>
                        (endpoint.volume = slider.value)
                    }
                    value={bind(endpoint, "volume")}
                    cursor={"hand1"}
                />
            </box>
        );
    };

    return (
        <scrollable
            onDestroy={cleanup}
            vscrollbarPolicy={Gtk.PolicyType.AUTOMATIC}
            hscrollbarPolicy={Gtk.PolicyType.NEVER}
            className="audio-container"
        >
            <box vertical spacing={20}>
                <ApplicationItem />

                <Gtk.Separator visible />

                {/* Output Devices Section */}
                <box vertical spacing={10}>
                    <box vertical spacing={15}>
                        <label
                            label="Output Devices"
                            className="section-title"
                            xalign={0}
                        />
                        <box spacing={5}>
                            {defaultSpeaker ? (
                                <box vertical>
                                    <button
                                        className="device-dropdown-button"
                                        cursor={"hand1"}
                                        onClicked={(self: any) => {
                                            const menu = new Gtk.Menu();

                                            audio.speakers.forEach(
                                                (speaker: any) => {
                                                    const menuItem =
                                                        new Gtk.MenuItem();
                                                    menuItem.set_label(
                                                        speaker.description
                                                    );

                                                    menuItem.connect(
                                                        "activate",
                                                        () => {
                                                            speaker.isDefault =
                                                                true;
                                                            menu.hide();
                                                        }
                                                    );

                                                    menu.append(menuItem);
                                                }
                                            );

                                            menu.show_all();
                                            menu.popup_at_widget(
                                                self,
                                                Gdk.Gravity.SOUTH_WEST,
                                                Gdk.Gravity.NORTH_WEST,
                                                null
                                            );
                                        }}
                                    >
                                        <box spacing={10}>
                                            <box hexpand>
                                                <label
                                                    label={bind(
                                                        defaultSpeaker,
                                                        "description"
                                                    ).as((desc) =>
                                                        truncateText(
                                                            sanitizeUtf8(
                                                                desc || ""
                                                            ),
                                                            60
                                                        )
                                                    )}
                                                    wrap
                                                    xalign={0}
                                                />
                                            </box>
                                            <icon icon="pan-down-symbolic" />
                                        </box>
                                    </button>
                                </box>
                            ) : (
                                <label
                                    label="No default output device"
                                    xalign={0.5}
                                    className="no-devices"
                                />
                            )}
                        </box>
                    </box>

                    {/* Default Output Volume Control */}
                    {defaultSpeaker ? (
                        <VolumeSlider
                            endpoint={defaultSpeaker}
                            label="Output Volume"
                        />
                    ) : (
                        <label
                            label="No default output device"
                            xalign={0.5}
                            className="no-devices"
                        />
                    )}
                </box>

                <Gtk.Separator visible />

                {/* Input Devices Section */}
                <box vertical spacing={10}>
                    <box vertical spacing={15}>
                        <label
                            label="Input Devices"
                            className="section-title"
                            xalign={0}
                        />
                        <box spacing={5}>
                            {defaultMicrophone ? (
                                <box vertical>
                                    <button
                                        className="device-dropdown-button"
                                        cursor={"hand1"}
                                        onClicked={(self: any) => {
                                            const menu = new Gtk.Menu();

                                            audio.microphones.forEach(
                                                (mic: any) => {
                                                    const menuItem =
                                                        new Gtk.MenuItem();
                                                    menuItem.set_label(
                                                        mic.description
                                                    );

                                                    menuItem.connect(
                                                        "activate",
                                                        () => {
                                                            mic.isDefault =
                                                                true;
                                                            menu.hide();
                                                        }
                                                    );

                                                    menu.append(menuItem);
                                                }
                                            );

                                            menu.show_all();
                                            menu.popup_at_widget(
                                                self,
                                                Gdk.Gravity.SOUTH_WEST,
                                                Gdk.Gravity.NORTH_WEST,
                                                null
                                            );
                                        }}
                                    >
                                        <box spacing={10}>
                                            <box vertical hexpand>
                                                <label
                                                    label={bind(
                                                        defaultMicrophone,
                                                        "description"
                                                    ).as((desc) =>
                                                        truncateText(
                                                            sanitizeUtf8(
                                                                desc || ""
                                                            ),
                                                            60
                                                        )
                                                    )}
                                                    wrap
                                                    xalign={0}
                                                    className="device-name"
                                                />
                                            </box>
                                            <icon icon="pan-down-symbolic" />
                                        </box>
                                    </button>
                                </box>
                            ) : (
                                <label
                                    label="No default input device"
                                    xalign={0.5}
                                    className="no-devices"
                                />
                            )}
                        </box>
                    </box>

                    {/* Default Input Volume Control */}
                    {defaultMicrophone ? (
                        <VolumeSlider
                            endpoint={defaultMicrophone}
                            label="Input Volume"
                        />
                    ) : (
                        <label
                            label="No default input device"
                            xalign={0.5}
                            className="no-devices"
                        />
                    )}
                </box>
            </box>
        </scrollable>
    );
};

export default InputOutputList;