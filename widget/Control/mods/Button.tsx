import { bind, Variable, exec, execAsync } from "astal";
import { Gtk } from "astal/gtk3";
import Network from "gi://AstalNetwork"
import Bluetooth from "gi://AstalBluetooth"

const WifiButtonToggle = () => {
    const network = Network.get_default()
    const wifiState = Variable.derive([bind(network, "wifi")], (wifi) => wifi)
	return <button className={bind(network.wifi, "enabled").as((v) => v ? "active" : "")}
		onClick={() => {
			network.wifi.enabled = !network.wifi.enabled
		}}>
		{
			bind(wifiState).as((w) => {
				return <icon
                    icon={bind(w, "iconName")}
                />
            })
        }
    </button>
}

const BluetoothButtonToggle = () => {
    const bluetooth = Bluetooth.get_default()
    const bluetoothState = Variable.derive([bind(bluetooth, "isPowered")], (isPowered) => isPowered)
    return <button className={bind(bluetoothState).as((v) => v ? "active" : "")}
        onClick={() => {
            exec(`bluetoothctl power ${bluetoothState.get() ? "off" : "on"}`)
        }}>
        <icon icon="bluetooth-symbolic" />
    </button>
}

const AirplaneModeButtonToggle = () => {
    const airplaneMode = Variable(false)
    execAsync("rfkill list | sed -n 5p").then((v) => airplaneMode.set(v.includes("yes")))
    
    return <button className={bind(airplaneMode).as((v) => v ? "active" : "")}
        onClick={() => {
            const newState = !airplaneMode.get()
            airplaneMode.set(newState)
            exec(`rfkill ${newState ? "block" : "unblock"} all`)
        }}>
        <icon icon="airplane-mode-symbolic" />
    </button>
}

const AdjustsColorScreenButtonToggle = () => {
    const gammastep = Variable(false)
    return <button className={bind(gammastep).as((v) => v ? "active" : "")}
        onClick={() => {
            execAsync(`${gammastep.get() ? "killall gammastep" : "gammastep -O 4000"}`)
            gammastep.set(!gammastep.get())
        }}>
        <icon icon="night-light" />
    </button>
}

const DarkModeButtonToggle = () => {
    const darkMode = Variable(exec("gsettings get org.gnome.desktop.interface gtk-theme").includes("phocus"))
    return <button className={bind(darkMode).as((v) => v ? "active" : "")}
        onClick={() => {
            execAsync(`${darkMode.get() ? "gsettings set org.gnome.desktop.interface gtk-theme phocus" : "gsettings set org.gnome.desktop.interface gtk-theme Adwaita"}`)
            darkMode.set(!darkMode.get())
        }}>
        <icon icon="weather-clear-night-symbolic" />
    </button>
}

export default () => (
	<box className="control-buttons" spacing={20} halign={Gtk.Align.CENTER}>
		<WifiButtonToggle />
		<BluetoothButtonToggle />
		<AirplaneModeButtonToggle />
		<AdjustsColorScreenButtonToggle />
		<DarkModeButtonToggle />
	</box>
);
