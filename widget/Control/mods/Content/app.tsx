import { bind, Variable } from "astal";
import { Gtk } from "astal/gtk3";
import NotificationList from "./Notification";
import WifiList from "./Wifi";
import BluetoothList from "./Bluetooth";
import InputOutputList from "./Volume";
import BatteryInfo from "./Battery";

export default () => {
    const buttons = [
        {
            label: "Notifications",
            icon: "notification-symbolic",
        },
        {
            label: "Wi-Fi",
            icon: "network-wireless-symbolic",
        },
        {
            label: "Bluetooth",
            icon: "bluetooth-symbolic",
        },
        {
            label: "Volume",
            icon: "audio-volume-high-symbolic",
        },
        {
            label: "Battery",
            icon: "battery-symbolic",
        },
    ];

    const content = Variable(<NotificationList />);
    const buttonSelected = Variable(0);

    const cleanup = () => {
        content.drop();
        buttonSelected.drop();
    };

    return (
        <box
            vertical
            className="content-container"
            spacing={30}
            onDestroy={cleanup}
        >
            <box
                spacing={10}
                className="button-container"
                halign={Gtk.Align.CENTER}
            >
                {buttons.map((button, index) => (
                    <button
                        cursor={"hand1"}
                        className={bind(buttonSelected).as((selected) => {
                            if (selected === index) {
                                return "active";
                            }
                            return "";
                        })}
                        onClicked={() => {
                            if (button.label === "Wi-Fi") {
                                content.set(<WifiList />);
                                buttonSelected.set(index);
                            } else if (button.label === "Notifications") {
                                content.set(<NotificationList />);
                                buttonSelected.set(index);
                            } else if (button.label === "Bluetooth") {
                                content.set(<BluetoothList />);
                                buttonSelected.set(index);
                            } else if (button.label === "Volume") {
                                content.set(<InputOutputList />);
                                buttonSelected.set(index);
                            } else if (button.label === "Battery") {
                                content.set(<BatteryInfo />);
                                buttonSelected.set(index);
                            }
                        }}
                    >
                        {bind(buttonSelected).as((selected) => {
                            if (selected === index) {
                                return (
                                    <box spacing={10}>
                                        <icon icon={button.icon} />
                                        <label label={button.label} />
                                    </box>
                                );
                            }
                            return <icon icon={button.icon} />;
                        })}
                    </button>
                ))}
            </box>
            <box vertical spacing={10}>
                {bind(content).as((content) => {
                    return content;
                })}
            </box>
        </box>
    );
};
