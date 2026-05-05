import Wp from "gi://AstalWp";
import { bind, timeout, Variable } from "astal";
import { Astal, Gdk, Gtk } from "astal/gtk3";
import Brightness from "./brightness";

const SHOW_TIME: number = 2000;

interface SliderIndicatorProps {
    label: string;
    icon: any;
    value: any;
    onDragged: (slider: any) => void;
    className: string;
    sliderClassName: string;
}

const createSliderIndicator = ({
    label,
    icon,
    value,
    onDragged,
    className,
    sliderClassName,
}: SliderIndicatorProps) => {
    return (
        <box className={className} visible={false} horizontal={true}>
            <icon icon={icon} />

            <box className={"indicator"} vertical={true}>
                <box className="indicator-text">
                    <label
                        label={label}
                        className="indicator-label"
                        hexpand={true}
                        xalign={0}
                    />
                    <label
                        label={value.as(
                            (val: any) => `${Math.floor((val ? val : 0) * 100)}`
                        )}
                        className="indicator-value"
                        xalign={1}
                    />
                </box>
                <box className="slider-container">
                    <slider
                        className={sliderClassName}
                        hexpand={true}
                        onDragged={onDragged}
                        value={value}
                    />
                </box>
            </box>
        </box>
    );
};

const createVolumeIndicator = (device: any, class_name: any) => {
    return createSliderIndicator({
        label: "Volume",
        icon: bind(device, "volume-icon"),
        value: bind(device, "volume"),
        onDragged: (slider: any) => (device.volume = slider.value),
        className: class_name,
        sliderClassName: "volume-slider",
    });
};

const createMicIndicator = (device: any, class_name: any) => {
    return createSliderIndicator({
        label: "Microphone",
        icon: "audio-input-microphone-symbolic",
        value: bind(device, "volume"),
        onDragged: (slider: any) => (device.volume = slider.value),
        className: class_name,
        sliderClassName: "mic-slider",
    });
};

const createMuteIndicator = (device: any, class_name: any) => {
    return (
        <box className={`${class_name}-mute`} visible={false}>
            <icon icon={bind(device, "volume-icon")} />
        </box>
    );
};

const createBrightnessIndicator = (brightness: any) => {
    return createSliderIndicator({
        label: "Brightness",
        icon: "display-brightness-symbolic",
        value: bind(brightness, "screen"),
        onDragged: (slider: any) => (brightness.screen = slider.value),
        className: "brightness-indicator",
        sliderClassName: "brightness-slider",
    });
};

const createOSDWidget = (current_timeout_ref: any, visibleVar: any) => {
    const speaker = Wp.get_default()!.defaultSpeaker;
    const mic = Wp.get_default()!.defaultMicrophone;
    const brightness = Brightness.get_default();

    return (
        <box
            className={"OSD"}
            vertical={true}
            setup={(self: any) => {
                const speaker_vol = self.children[0];
                const speaker_mute = self.children[1];
                const mic_vol = self.children[2];
                const mic_mute = self.children[3];
                const brightness_indicator = self.children[4];

                const showOSD = (widget: any) => {
                    speaker_vol.visible = false;
                    mic_vol.visible = false;
                    speaker_mute.visible = false;
                    mic_mute.visible = false;
                    brightness_indicator.visible = false;

                    widget.visible = true;
                    visibleVar.set(true);
                    if (current_timeout_ref.timer) {
                        current_timeout_ref.timer.cancel();
                    }

                    current_timeout_ref.timer = timeout(SHOW_TIME, () => {
                        visibleVar.set(false);
                        current_timeout_ref.timer = null;
                    });
                };

                let is_clicked_speaker = false;
                let is_clicked_mic = false;
                let is_clicked_brightness = false;
                let is_clicked_speaker_mute = false;
                let is_clicked_mic_mute = false;

                const subscriptions: any[] = [];

                subscriptions.push(
                    bind(speaker, "volume").subscribe(() => {
                        if (is_clicked_speaker) {
                            showOSD(speaker_vol);
                        }
                        is_clicked_speaker = true;
                    })
                );

                subscriptions.push(
                    bind(speaker, "mute").subscribe((muted: any) => {
                        if (is_clicked_speaker_mute) {
                            showOSD(muted ? speaker_mute : speaker_vol);
                        }
                        is_clicked_speaker_mute = true;
                    })
                );

                subscriptions.push(
                    bind(mic, "volume").subscribe(() => {
                        if (is_clicked_mic) {
                            showOSD(mic_vol);
                        }
                        is_clicked_mic = true;
                    })
                );

                subscriptions.push(
                    bind(mic, "mute").subscribe((muted: any) => {
                        if (is_clicked_mic_mute) {
                            showOSD(muted ? mic_mute : mic_vol);
                        }
                        is_clicked_mic_mute = true;
                    })
                );

                subscriptions.push(
                    bind(brightness, "screen").subscribe(() => {
                        if (is_clicked_brightness) {
                            showOSD(brightness_indicator);
                        }
                        is_clicked_brightness = true;
                    })
                );

                // Cleanup function
                const cleanup = () => {
                    // Cancel any active timeout
                    if (current_timeout_ref.timer) {
                        current_timeout_ref.timer.cancel();
                        current_timeout_ref.timer = null;
                    }
                    // Unsubscribe all handlers
                    subscriptions.forEach((unsub) => {
                        if (typeof unsub === "function") {
                            unsub();
                        }
                    });
                };

                // Set cleanup on widget destroy
                self.connect("destroy", cleanup);
            }}
        >
            {createVolumeIndicator(speaker, "volume-indicator")}
            {createMuteIndicator(speaker, "volume-indicator")}
            {createMicIndicator(mic, "mic-indicator")}
            {createMuteIndicator(mic, "mic-indicator")}
            {createBrightnessIndicator(brightness)}
        </box>
    );
};

export default function OSD(gdkmonitor: Gdk.Monitor) {
    const current_timeout_ref: any = { timer: null };
    const visible = Variable(false);

    return (
        <window
            gdkmonitor={gdkmonitor}
            className="OSDWindow"
            anchor={Astal.WindowAnchor.BOTTOM}
            css={bind(visible).as((v) => (v ? "" : "pointer-events: none;"))}
        >
            <revealer
                transitionType={Gtk.RevealerTransitionType.SLIDE_UP}
                transitionDuration={300}
                revealChild={bind(visible)}
            >
                {createOSDWidget(current_timeout_ref, visible)}
            </revealer>
        </window>
    );
}
