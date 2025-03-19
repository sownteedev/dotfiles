import { App } from "astal/gtk3"
import style from "./scss/style.scss"
import Bar from "./widget/Bar/app"
import OSD from "./widget/OSD/app"
import NotificationPopups from "./widget/Notification/app"

App.start({
	css: style,
	instanceName: "sownteeastal",
	requestHandler(request, res) {
		print(request)
		res("ok")
	},
	main() {
		App.get_monitors().map(Bar)
		App.get_monitors().map(OSD)
		App.get_monitors().map(NotificationPopups)
	},
})
