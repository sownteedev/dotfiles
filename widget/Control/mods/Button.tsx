import { bind, Variable, exec, execAsync, GLib } from "astal";
import { Gtk } from "astal/gtk3";
import Network from "gi://AstalNetwork"
import Bluetooth from "gi://AstalBluetooth"
import Notifd from "gi://AstalNotifd"
import { getIPAddress, IPAddress } from "./Content";

const WifiButtonToggle = () => {
    const network = Network.get_default()
    const wifiState = Variable.derive([bind(network, "wifi")], (wifi) => wifi)
	return <button className={bind(network.wifi, "enabled").as((v) => v ? "active" : "")}
		onClick={() => {
			network.wifi.enabled = !network.wifi.enabled
		}}
		cursor={"hand1"}
		>
		{
			bind(wifiState).as((w) => <icon icon={bind(w, "iconName")} />)
        }
    </button>
}

const BluetoothButtonToggle = () => {
    const bluetooth = Bluetooth.get_default()
    const bluetoothState = Variable.derive([bind(bluetooth, "isPowered")], (isPowered) => isPowered)
    return <button className={bind(bluetoothState).as((v) => v ? "active" : "")}
        onClick={() => {
            exec(`bluetoothctl power ${bluetoothState.get() ? "off" : "on"}`)
        }}
		cursor={"hand1"}
		>
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
        }}
		cursor={"hand1"}
		>
        <icon icon="airplane-mode-symbolic" />
    </button>
}

const AdjustsColorScreenButtonToggle = () => {
    const gammastep = Variable(false)
    execAsync("pgrep gammastep").then((v) => gammastep.set(v !== ""))
    
    return <button className={bind(gammastep).as((v) => v ? "active" : "")}
        onClick={() => {
            execAsync(`${gammastep.get() ? "killall gammastep" : "gammastep -O 4000"}`)
            gammastep.set(!gammastep.get())
        }}
		cursor={"hand1"}
		>
        <icon icon="night-light" />
    </button>
}

const DarkModeButtonToggle = () => {
    const darkMode = Variable(exec("gsettings get org.gnome.desktop.interface gtk-theme").includes("phocus"))
    return <button className={bind(darkMode).as((v) => v ? "active" : "")}
        onClick={() => {
            execAsync(`${darkMode.get() ? "gsettings set org.gnome.desktop.interface gtk-theme phocus" : "gsettings set org.gnome.desktop.interface gtk-theme Adwaita"}`)
            darkMode.set(!darkMode.get())
        }}
		cursor={"hand1"}
		>
        <icon icon="weather-clear-night-symbolic" />
    </button>
}

const SlienceNotification = () => {
    const notifd = Notifd.get_default()
    return <button className={bind(notifd, "dontDisturb").as((v) => v ? "active" : "")}
        onClick={() => {
            notifd.set_dont_disturb(!notifd.get_dont_disturb())
        }}
		cursor={"hand1"}
		>
        <icon icon="dnd-symbolic" />
    </button>
}

const CloudflareTunnelButton = () => {
    const cloudflareTunnel = Variable(exec("warp-cli status").includes("Connected"))
    return <button className={bind(cloudflareTunnel).as((v) => v ? "active" : "")}
        onClick={() => {
            exec(`warp-cli ${cloudflareTunnel.get() ? "disconnect" : "connect"}`)
            cloudflareTunnel.set(!cloudflareTunnel.get())
            
            // Update IP address after changing Cloudflare status
            GLib.timeout_add(GLib.PRIORITY_DEFAULT, 2000, () => {
                getIPAddress().then(ip => IPAddress.set(ip));
                return false; // Don't repeat the timeout
            });
        }}
		cursor={"hand1"}
		>
        <icon icon={bind(cloudflareTunnel).as((v) => v ? "cloudflare-active" : "cloudflare")} />
    </button>
}

export default () => (
	<box className="control-buttons" spacing={20} halign={Gtk.Align.CENTER}>
		<WifiButtonToggle />
		<BluetoothButtonToggle />
		<AirplaneModeButtonToggle />
		<AdjustsColorScreenButtonToggle />
		<DarkModeButtonToggle />
		<SlienceNotification />
		<CloudflareTunnelButton />
	</box>
);
