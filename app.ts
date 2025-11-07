import { App } from "astal/gtk3"
import style from "./scss/style.scss"
import { execAsync } from "astal/process"
import Global from "./Global"

App.start({
	icons: "./icons",
	css: style,
	instanceName: "sownteeastal",
	requestHandler(request, res) {
		console.log(request)
		res("ok")
	},
	async main() {
		const monitors = App.get_monitors()

		const Bar = await import("./widget/Bar/app").then(m => m.default)
		monitors.map(Bar)

		const [Desktop, OSD, NotificationPopups] = await Promise.all([
			import("./widget/Wallpaper/Desktop").then(m => m.default),
			import("./widget/OSD/app").then(m => m.default),
			import("./widget/Notification/app").then(m => m.default),
		])
		monitors.map(Desktop)
		monitors.map(OSD)
		monitors.map(NotificationPopups)

		const [AppLauncher, Power, LockScreen] = await Promise.all([
			import("./widget/Launcher/AppLauncher").then(m => m.default),
			import("./widget/Power").then(m => m.default),
			import("./widget/LockScreen").then(m => m.default),
		])
		monitors.map(AppLauncher)
		monitors.map(Power)
		monitors.map(LockScreen)

		const Control = await import("./widget/Control/app").then(m => m.default)
		monitors.map(Control)
		
		await execAsync(`magick ${Global.Wallpaper} -blur 0x8 /tmp/backdrop.png`)
		const [Backdrop] = await Promise.all([
			import("./widget/Wallpaper/Backdrop").then(m => m.default),
		])
		monitors.map(Backdrop)
	},
})
