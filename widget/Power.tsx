import { Astal, Gtk, App, Gdk } from "astal/gtk3";
import { execAsync, Variable } from "astal";

function hide() {
	App.get_window("power-menu")!.hide()
}

const PowerAction = ({ command, icon, ref }: { command: string, icon: string, ref?: (button: Gtk.Button) => void }) => {
  return (
    <button
      onClicked={() => {
        execAsync(command)
        hide()
      }}
      canFocus={true}
      setup={ref}
      focusOnClick={true}
      className="power-button"
      cursor={"hand1"}
    >
      <icon icon={icon} />
    </button>
  );
};

export const PowerMenu = ({ firstButtonRef }: { firstButtonRef: (button: Gtk.Button) => void }) => {
  const secondButtonRef = (button: Gtk.Button) => { };
  const thirdButtonRef = (button: Gtk.Button) => { };
  const fourthButtonRef = (button: Gtk.Button) => { };
  const fifthButtonRef = (button: Gtk.Button) => { };
  const sixthButtonRef = (button: Gtk.Button) => { };
  return (
    <box spacing={20} className="power-popup">
      <PowerAction command="poweroff" icon="system-shutdown-symbolic" ref={firstButtonRef} />
      <PowerAction command="reboot" icon="system-reboot-symbolic" ref={secondButtonRef} />
      <PowerAction command="astal -i sownteeastal -t lock-screen" icon="system-lock-screen-symbolic" ref={thirdButtonRef} />
      <PowerAction command="systemctl suspend" icon="system-suspend-symbolic" ref={fourthButtonRef} />
      <PowerAction command="systemctl hibernate" icon="system-hibernate-symbolic" ref={fifthButtonRef} />
      <PowerAction command="niri msg action quit" icon="system-log-out-symbolic" ref={sixthButtonRef} />
    </box>
  );
};

export default function Power() {
  let firstButton: Gtk.Button | null = null;

  const firstButtonRef = (button: Gtk.Button) => {
    firstButton = button;
  };

  const width = Variable(2000)

  // Cleanup function
  const cleanup = () => {
    width.drop();
  };

  return <window
    name="power-menu"
    exclusivity={Astal.Exclusivity.IGNORE}
    layer={Astal.Layer.TOP}
    visible={false}
    keymode={Astal.Keymode.ON_DEMAND}
    application={App}
    className="power-menu"
    onShow={() => {
      if (firstButton) {
        firstButton.grab_focus();
      }
    }}
    onKeyPressEvent={function (self, event: Gdk.Event) {
      const keyval = event.get_keyval()[1];
      if (keyval === Gdk.KEY_Escape) {
        self.hide();
      }
    }}
    onDestroy={cleanup}
  >
    <box>
      <eventbox widthRequest={width(w => w / 2)} expand onClick={hide} />
      <PowerMenu firstButtonRef={firstButtonRef} />
      <eventbox widthRequest={width(w => w / 2)} expand onClick={hide} />
    </box>
  </window>
}