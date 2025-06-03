import { App, Astal, Gdk, Gtk } from "astal/gtk3";
import { bind, Variable, exec, GLib } from "astal";
import Auth from "gi://AstalAuth";
import Global from "../Global";
import { isImage } from "../utils/file";

const passwordVar = Variable("");
const authenticating = Variable(false);
const errorMessage = Variable("");
const lockScreenWall = Variable(Global.LockScreenWall);
const css = lockScreenWall.get() !== "" && isImage(lockScreenWall.get()) ? `background-image: url('${lockScreenWall.get()}'); background-size: cover;` : "";

function hide() {
	App.get_window("lock-screen")!.hide()
}

const Time = ({ format = "%H : %M" }) => {
	const time = Variable<string>("").poll(1000, () =>
		GLib.DateTime.new_now_local().format(format)!)

	return <label
		className="TimeLockScreen"
		onDestroy={() => time.drop()}
		label={time()}
	/>
}

const Date = ({ format = "%A, %d %B %Y" }) => {
	const date = Variable<string>("").poll(1000, () =>
		GLib.DateTime.new_now_local().format(format)!)

	return <label
		className={"DateLockScreen"}
		onDestroy={() => date.drop()}
		label={date()}
	/>
}

const MediaPlayer = () => {

}

export const LockScreen = () => {
	const authenticate = () => {
		if (passwordVar.get() === "") return;

		authenticating.set(true);
		errorMessage.set("");

		Auth.Pam.authenticate(passwordVar.get(), (_, task) => {
			try {
				Auth.Pam.authenticate_finish(task);
				console.log("Authentication successful");
				hide();
			} catch (error) {
				exec(`notify-send "Authentication failed" "${error}"`);
			} finally {
				authenticating.set(false);
				passwordVar.set("");
			}
		});

		
	};

	const cleanup = () => {
		passwordVar.drop();
		authenticating.drop();
		errorMessage.drop();
		lockScreenWall.drop();
	};

	return (
		<window
			name="lock-screen"
			layer={Astal.Layer.OVERLAY}
			anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.LEFT | Astal.WindowAnchor.RIGHT | Astal.WindowAnchor.BOTTOM}
			keymode={Astal.Keymode.EXCLUSIVE}
			application={App}
			className="lock-screen"
			css={css}
			exclusivity={Astal.Exclusivity.IGNORE}
			visible={false}
			onDestroy={cleanup}
		>
			<centerbox vertical>
				<box halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER} vertical>
					<Time />
					<Date />
				</box>
				<box halign={Gtk.Align.CENTER}>
					{/* <MediaPlayer /> */}
				</box>
				<box halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER}>
					<box className="password-entry-box">
						<entry
							className={"password-entry"}
							visibility={false}
							onActivate={authenticate}
							xalign={0.5}
							placeholderText="Enter your password"
							onChanged={(self: Gtk.Entry) => {
								passwordVar.set(self.text);
								if (self.text.length > 0) {
									self.get_style_context()?.add_class("has-text");
								} else {
									self.get_style_context()?.remove_class("has-text");
								}
							}}
							text={bind(passwordVar)}
						/>
					</box>
				</box>
			</centerbox>
		</window>
	);
};

export default LockScreen;
