import { bind, Variable } from "astal";
import { Astal, Gdk } from "astal/gtk3";
import { isImage } from "../utils/file";
import Global from "../Global";

const desktopWall = Variable(Global.Wallpaper);

export const Desktop = (gdkmonitor: Gdk.Monitor) => {
	const windowName = `desktop-${gdkmonitor.display.get_n_monitors()}`;
	const Anchor = Astal.WindowAnchor;

	return (
		<window
			gdkmonitor={gdkmonitor}
			namespace={windowName}
			anchor={Anchor.TOP | Anchor.LEFT | Anchor.RIGHT | Anchor.BOTTOM}
			name={windowName}
			layer={Astal.Layer.BACKGROUND}
			exclusivity={Astal.Exclusivity.IGNORE}
			keymode={Astal.Keymode.EXCLUSIVE}
			className="desktop"
		>
			{bind(desktopWall).as((wallpaper) => {
				if (wallpaper && isImage(wallpaper)) {
					return (
						<box
							hexpand={true}
							vexpand={true}
							className="wallpaper"
							css={`background-image: url('${wallpaper}'); background-size: cover;`}
						/>
					);
				}
				return (
					<box
						hexpand={true}
						vexpand={true}
						className="default-background"
					/>
				);
			})}
		</window>
	);
};

export default Desktop;
