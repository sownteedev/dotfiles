import { bind, exec, execAsync, GLib, Variable } from "astal";
import { Gtk, Gdk } from "astal/gtk3";
import Battery from "gi://AstalBattery";
import PowerProfiles from "gi://AstalPowerProfiles";

const BatteryInfo = () => {
    const getBatteryDevice = () => {
        const upower = Battery.UPower.new();
        if (!upower) {
            console.error("Battery: Failed to initialize UPower");
            return null;
        }

        const devices = upower.get_devices();
        if (!devices) {
            console.error("Battery: Failed to get battery devices");
            return null;
        }

        for (const device of devices) {
            if (device.get_is_battery() && device.get_power_supply()) {
                return device;
            }
        }

        const display_device = upower.get_display_device();
        if (!display_device) {
            console.error("Battery: No battery device found");
            return null;
        }
        return display_device;
    };

    const BatteryInfo = () => {
        const bat = getBatteryDevice();
        if (!bat) {
            console.error(
                "Battery: Cannot create BatteryInfo: no battery device",
            );
            return <box />;
        }

        const gpuPower = Variable("N/A");
        let gpuPowerTimeoutId: number | null = null;

        // Locate Nvidia GPU runtime status path dynamically
        let gpuStatusPath = "/sys/bus/pci/devices/0000:01:00.0/power/runtime_status";
        try {
            const dir = GLib.Dir.open("/sys/bus/pci/drivers/nvidia", 0);
            let name;
            while ((name = dir.read_name())) {
                if (name.startsWith("0000:")) {
                    gpuStatusPath = `/sys/bus/pci/devices/${name}/power/runtime_status`;
                    break;
                }
            }
            dir.close();
        } catch {
            // Fallback to default
        }

        const refreshGpuPower = () => {
            if (!GLib.file_test(gpuStatusPath, GLib.FileTest.EXISTS)) {
                gpuPower.set("N/A");
                return;
            }

            execAsync(`cat ${gpuStatusPath}`)
                .then((status) => {
                    if (status.toString().trim() !== "active") {
                        gpuPower.set("Suspended");
                        return;
                    }

                    execAsync(
                        "nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits",
                    )
                        .then((value) => {
                            const powerDraw = value
                                .toString()
                                .trim()
                                .split(/\r?\n/)
                                .find((line) => line.trim().length > 0);

                            if (!powerDraw) {
                                gpuPower.set("N/A");
                                return;
                            }

                            const parsedPower = Number.parseFloat(powerDraw);
                            gpuPower.set(
                                Number.isFinite(parsedPower)
                                    ? `${parsedPower.toFixed(1)} W`
                                    : "N/A",
                            );
                        })
                        .catch(() => {
                            gpuPower.set("N/A");
                        });
                })
                .catch(() => {
                    gpuPower.set("N/A");
                });
        };

        refreshGpuPower();
        gpuPowerTimeoutId = GLib.timeout_add(
            GLib.PRIORITY_DEFAULT,
            5000,
            () => {
                refreshGpuPower();
                return true;
            },
        );

        return (
            <box
                className="battery-info-container"
                vertical
                spacing={10}
                hexpand
                onDestroy={() => {
                    if (gpuPowerTimeoutId) {
                        GLib.source_remove(gpuPowerTimeoutId);
                        gpuPowerTimeoutId = null;
                    }
                    gpuPower.drop();
                }}
            >
                <box>
                    <label
                        label="Battery Information"
                        xalign={0}
                        className="battery-info-section-title"
                    />
                    <label
                        label={bind(bat, "model").as((model) => {
                            if (!model) return "N/A";
                            return `${model}`;
                        })}
                        valign={Gtk.Align.START}
                        xalign={1}
                        hexpand
                    />
                </box>

                <box
                    vertical
                    spacing={5}
                    className="battery-percentage-container"
                >
                    <slider
                        className={bind(bat, "percentage").as((percentage) => {
                            if (!percentage)
                                return "battery-percentage-slider-red";
                            const percent = Math.floor(percentage * 100);
                            if (percent >= 100)
                                return "battery-percentage-slider-green";
                            if (percent >= 80)
                                return "battery-percentage-slider-blue";
                            if (percent >= 20)
                                return "battery-percentage-slider-yellow";
                            return "battery-percentage-slider-red";
                        })}
                        hexpand
                        value={bind(bat, "percentage")}
                    />
                    <box hexpand>
                        <label
                            label={bind(
                                Variable.derive(
                                    [
                                        bind(bat, "state"),
                                        bind(bat, "timeToFull"),
                                        bind(bat, "timeToEmpty"),
                                    ],
                                    (
                                        state: any,
                                        timeToFull: any,
                                        timeToEmpty: any,
                                    ) => {
                                        if (!state) return "Unknown";

                                        if (state === Battery.State.CHARGING) {
                                            if (timeToFull > 0) {
                                                const hours = Math.floor(
                                                    timeToFull / 3600,
                                                );
                                                const minutes = Math.floor(
                                                    (timeToFull % 3600) / 60,
                                                );
                                                return `${hours}h ${minutes}m to full`;
                                            }
                                            return "Charging";
                                        } else if (
                                            state === Battery.State.DISCHARGING
                                        ) {
                                            if (timeToEmpty > 0) {
                                                const hours = Math.floor(
                                                    timeToEmpty / 3600,
                                                );
                                                const minutes = Math.floor(
                                                    (timeToEmpty % 3600) / 60,
                                                );
                                                return `${hours}h ${minutes}m remaining`;
                                            }
                                            return "Discharging";
                                        }

                                        const stateMap = {
                                            [Battery.State.EMPTY]: "Empty",
                                            [Battery.State.FULLY_CHARGED]:
                                                "Full",
                                            [Battery.State.PENDING_CHARGE]:
                                                "Pending",
                                            [Battery.State.PENDING_DISCHARGE]:
                                                "Pending Discharge",
                                        };
                                        return stateMap[state] || String(state);
                                    },
                                ),
                            )}
                            xalign={0}
                            hexpand
                        />
                        <label
                            label={bind(bat, "percentage").as((percentage) => {
                                if (!percentage) return "N/A";
                                return `${Math.floor(percentage * 100)}%`;
                            })}
                            xalign={1}
                            hexpand
                        />
                    </box>
                </box>

                <box hexpand>
                    <label label="Energy Rate:" />
                    <label
                        label={bind(bat, "energyRate").as((rate) => {
                            if (!rate) return "N/A";
                            return `${rate.toFixed(1)} W`;
                        })}
                        xalign={1}
                        hexpand
                    />
                </box>

                <box hexpand>
                    <label label="Design Energy:" />
                    <label
                        label={bind(bat, "energyFullDesign").as(
                            (energyFullDesign) => {
                                if (!energyFullDesign) return "N/A";
                                return `${energyFullDesign.toFixed(1)} Wh`;
                            },
                        )}
                        xalign={1}
                        hexpand
                    />
                </box>

                <box hexpand>
                    <label label="Health:" />
                    <label
                        label={bind(bat, "capacity").as((capacity) => {
                            if (!capacity) {
                                return "N/A";
                            }
                            return `${(capacity * 100).toFixed(1)}%`;
                        })}
                        xalign={1}
                        hexpand
                    />
                </box>

                <box hexpand>
                    <label label="Change cycles:" />
                    <label
                        label={bind(bat, "chargeCycles").as((chargeCycles) => {
                            if (!chargeCycles) {
                                return "N/A";
                            }
                            return `${chargeCycles}`;
                        })}
                        xalign={1}
                        hexpand
                    />
                </box>

                <box hexpand>
                    <label label="Temperature:" />
                    <label
                        label={bind(bat, "temperature").as((temp) => {
                            if (!temp) return "N/A";
                            return `${temp.toFixed(1)}°C`;
                        })}
                        xalign={1}
                        hexpand
                    />
                </box>

                <box hexpand>
                    <label label="Voltage:" />
                    <label
                        label={bind(bat, "voltage").as((voltage) => {
                            if (!voltage) {
                                return "N/A";
                            }
                            return `${voltage.toFixed(1)} V`;
                        })}
                        xalign={1}
                        hexpand
                    />
                </box>

                <box hexpand>
                    <label label="GPU Power:" />
                    <label label={bind(gpuPower)} xalign={1} hexpand />
                </box>
            </box>
        );
    };

    const PowerProfile = () => {
        const power = PowerProfiles.get_default();
        if (!power) {
            console.error("Battery: Failed to initialize PowerProfiles");
            return <box />;
        }

        const getProfileDisplayName = (profile: string) => {
            switch (profile) {
                case "power-saver":
                    return "Power Saver";
                case "balanced":
                    return "Balanced";
                case "performance":
                    return "Performance";
                default:
                    return "Unknown";
            }
        };

        return (
            <box
                className="power-profile-container"
                vertical
                spacing={10}
                hexpand
            >
                <label
                    label="Power Mode"
                    xalign={0}
                    className="power-profile-title"
                />
                <box spacing={5}>
                    <button
                        className="device-dropdown-button"
                        cursor={"hand1"}
                        onClicked={(self: Gtk.Button) => {
                            const menu = new Gtk.Menu();

                            const profiles = [
                                "power-saver",
                                "balanced",
                                "performance",
                            ];
                            profiles.forEach((profile) => {
                                const menuItem = new Gtk.MenuItem();
                                menuItem.set_label(
                                    getProfileDisplayName(profile),
                                );

                                menuItem.connect("activate", () => {
                                    power.activeProfile = profile;
                                    menu.hide();
                                });

                                menu.append(menuItem);
                            });

                            menu.show_all();
                            menu.popup_at_widget(
                                self,
                                Gdk.Gravity.SOUTH_WEST,
                                Gdk.Gravity.NORTH_WEST,
                                null,
                            );
                        }}
                    >
                        <box spacing={10} className="power-profile-button">
                            <box hexpand vertical spacing={5}>
                                <label
                                    label={bind(power, "activeProfile").as(
                                        (profile) =>
                                            getProfileDisplayName(profile),
                                    )}
                                    xalign={0}
                                />
                                <label
                                    label={bind(power, "activeProfile").as(
                                        (profile) =>
                                            profile === "power-saver"
                                                ? "Lowest power consumption, highest battery life"
                                                : profile === "balanced"
                                                  ? "Default power consumption, good battery life"
                                                  : "Highest performance, lowest battery life",
                                    )}
                                    xalign={0}
                                />
                            </box>
                            <icon icon="pan-down-symbolic" />
                        </box>
                    </button>
                </box>
            </box>
        );
    };

    const BatteryCharging = () => {
        const chargeMode = Variable("");
        execAsync(
            "cat /sys/class/power_supply/BAT0/charge_control_end_threshold",
        ).then((v) => {
            if (v === "80") {
                chargeMode.set("preserve");
            } else {
                chargeMode.set("maximize");
            }
        });

        const setBatteryChargeMode = async (mode: string) => {
            try {
                if (mode === "preserve") {
                    await exec(
                        `pkexec bash -c "echo 80 > /sys/class/power_supply/BAT0/charge_control_end_threshold && echo 75 > /sys/class/power_supply/BAT0/charge_control_start_threshold"`,
                    );
                    chargeMode.set("preserve");
                } else {
                    await exec(
                        `pkexec bash -c "echo 100 > /sys/class/power_supply/BAT0/charge_control_end_threshold && echo 50 > /sys/class/power_supply/BAT0/charge_control_start_threshold"`,
                    );
                    chargeMode.set("maximize");
                }
            } catch (error) {
                console.error("Failed to set battery charge mode:", error);
            }
        };

        const getChargeModeDisplayName = (mode: string) => {
            return mode === "preserve"
                ? "Preserve Battery Health"
                : "Maximize Charge";
        };

        return (
            <box
                className="battery-charging-container"
                vertical
                spacing={10}
                hexpand
                onDestroy={() => {
                    chargeMode.drop();
                }}
            >
                <label
                    label="Battery Charging"
                    xalign={0}
                    className="battery-charging-title"
                />
                <box spacing={5}>
                    <button
                        className="device-dropdown-button"
                        cursor={"hand1"}
                        onClicked={(self: any) => {
                            const menu = new Gtk.Menu();

                            const modes = [
                                { name: "Maximize Charge", value: "maximize" },
                                {
                                    name: "Preserve Battery Health",
                                    value: "preserve",
                                },
                            ];

                            modes.forEach((mode) => {
                                const menuItem = new Gtk.MenuItem();
                                menuItem.set_label(mode.name);

                                menuItem.connect("activate", () => {
                                    setBatteryChargeMode(mode.value);
                                    menu.hide();
                                });

                                menu.append(menuItem);
                            });

                            menu.show_all();
                            menu.popup_at_widget(
                                self,
                                Gdk.Gravity.SOUTH_WEST,
                                Gdk.Gravity.NORTH_WEST,
                                null,
                            );
                        }}
                    >
                        <box spacing={10} className="battery-charging-button">
                            <box hexpand vertical spacing={5}>
                                <label
                                    label={bind(chargeMode).as((mode) =>
                                        getChargeModeDisplayName(mode),
                                    )}
                                    xalign={0}
                                />
                                <label
                                    label={bind(chargeMode).as((mode) =>
                                        mode === "preserve"
                                            ? "Increases battery longevity by maintaining lower charge levels"
                                            : "Uses full battery capacity. Degrades batteries more quickly",
                                    )}
                                    xalign={0}
                                />
                            </box>
                            <icon icon="pan-down-symbolic" />
                        </box>
                    </button>
                </box>
            </box>
        );
    };

    return (
        <box vertical spacing={30} className="battery-container">
            <BatteryInfo />
            <PowerProfile />
            <BatteryCharging />
        </box>
    );
};

export default BatteryInfo;
