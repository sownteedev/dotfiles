import { bind, Variable, exec } from "astal";
import { Gtk } from "astal/gtk3";
import { map } from "../../../utils/common"

interface Monitor {
	name: string;
	id: string;
	logical: any;
}

let cached_monitors: {
	timestamp: number;
	data: Monitor[];
} = {
	timestamp: 0,
	data: [],
}

const getNiriMonitors = () => {
	if (cached_monitors && cached_monitors.timestamp && Date.now() - cached_monitors.timestamp < 5000) {
		return cached_monitors.data;
	}

	let out;
	try {
		out = exec("niri msg --json outputs");
	} catch (err) {
		return [];
	}

	let monitors;
	try {
		monitors = JSON.parse(out);
	} catch (err) {
		return [];
	}

	const monitorArray = [];
	const monitorOrder = ["eDP-1", "HDMI-A-1"];

	for (const name of monitorOrder) {
		if (monitors[name]) {
			monitorArray.push({
				name: name,
				id: name.replace("-", "_"),
				logical: monitors[name].logical,
			});
		}
	}

	cached_monitors = {
		timestamp: Date.now(),
		data: monitorArray,
	};

	return monitorArray;
}

let previousWorkspaceState: { hash: string; data: any } | null = null;

const processWorkspaceData = () => {
	let out;
	try {
		out = exec("niri msg --json workspaces");
	} catch (err) {
		return previousWorkspaceState ? previousWorkspaceState : [];
	}

	let workspaces;
	try {
		workspaces = JSON.parse(out);
	} catch (err) {
		return previousWorkspaceState ? previousWorkspaceState : [];
	}

	const stateHash = map(workspaces, (w: any) => `${w.output}-${w.idx}-${w.is_active ? "1" : "0"}`).join("|");

	if (previousWorkspaceState && previousWorkspaceState.hash === stateHash) {
		return previousWorkspaceState.data;
	}

	const monitors = getNiriMonitors();
	const workspaceData: any[] = [];

	const outputWorkspaces: { [key: string]: any[] } = {};
	for (const workspace of workspaces) {
		if (!outputWorkspaces[workspace.output]) {
			outputWorkspaces[workspace.output] = [];
		}
		outputWorkspaces[workspace.output].push({
			id: workspace.idx,
			is_active: workspace.is_active,
			workspace_id: workspace.id,
		});
	}

	for (const monitor of monitors) {
		const monitorWorkspaces = outputWorkspaces[monitor.name] || [];
		monitorWorkspaces.sort((a, b) => a.id - b.id);

		workspaceData.push({
			monitor: monitor.id,
			name: monitor.name,
			workspaces: monitorWorkspaces,
		});
	}

	previousWorkspaceState = {
		hash: stateHash,
		data: workspaceData,
	};

	return workspaceData;
}

const WorkspaceButton = (props: any) => {
	return <button
		className={`workspace-button${props.is_active ? ' active' : ''}`}
		onClick={() => {
			exec(`niri msg action focus-workspace ${props.id}`);
		}}
	>
	</button>
}

const MonitorWorkspaces = (props: any) => {
	let monitorNumber
	if (props.name = "eDP-1") {
		monitorNumber = 1
	} else if (props.name = "HDMI-A-1") {
		monitorNumber = 2
	} else {
		monitorNumber = 1
	}

	return <box
		className={`monitor-workspaces monitor-${monitorNumber}`}
		orientation={Gtk.Orientation.HORIZONTAL}
		spacing={5}>
		<box orientation={Gtk.Orientation.HORIZONTAL} spacing={3}>
			{...(map(props.workspaces, (ws: any) => (
				<WorkspaceButton
					id={ws.id}
					monitor={monitorNumber}
					monitor_name={props.name}
					is_active={ws.is_active}
					workspace_id={ws.workspace_id}
				/>
			)))}
		</box>
	</box>
}

export default () => {
	const workspaceData = Variable(processWorkspaceData).poll(250, processWorkspaceData);

	return <box className={"Workspaces"} orientation={Gtk.Orientation.HORIZONTAL} css={"margin-left: 10px;"}>
		{bind(workspaceData).as((ws: any) => {
			if (!Array.isArray(ws)) {
				return null;
			}
			const monitors = ws.map((monitor: any) => (
				<MonitorWorkspaces
					monitor={monitor.monitor}
					name={monitor.name}
					workspaces={monitor.workspaces}
				/>
			));
			return monitors;
		})}
	</box>
}
