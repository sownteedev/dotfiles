import { bind, Variable, exec } from "astal";
import { Gtk } from "astal/gtk3";
import Apps from "gi://AstalApps"
import { map } from "../../../utils/common"

interface Window {
	id: number;
	title: string;
	app_id: string;
	pid: number;
	workspace_id: number;
	is_focused: boolean;
	is_floating: boolean;
}

const getNiriMonitors = () => {
	const monitors = JSON.parse(exec("niri msg --json outputs"));

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

	return monitorArray;
}

const getWindowsForWorkspace = () => {
	const windows = JSON.parse(exec("niri msg --json windows"));
	return windows;
}

let previousWorkspaceState: { hash: string; data: any } | null = null;

const getWorkspaceData = () => {
	const workspaces = JSON.parse(exec("niri msg --json workspaces"));

	const windows: Window[] = getWindowsForWorkspace();
	
	const windowsByWorkspace: { [key: number]: Window[] } = {};
	for (const window of windows) {
		if (!windowsByWorkspace[window.workspace_id]) {
			windowsByWorkspace[window.workspace_id] = [];
		}
		windowsByWorkspace[window.workspace_id].push(window);
	}
	
	for (const workspaceId in windowsByWorkspace) {
		windowsByWorkspace[workspaceId].sort((a, b) => a.id - b.id);
	}

	const stateHash = map(workspaces, (w: any) => `${w.output}-${w.idx}-${w.is_active ? "1" : "0"}`).join("|") + 
		JSON.stringify(windows);

	if (previousWorkspaceState && previousWorkspaceState.hash === stateHash) {
		return previousWorkspaceState.data;
	}

	const monitors = getNiriMonitors();
	const outputWorkspaces: { [key: string]: any[] } = {};
	
	for (const workspace of workspaces) {
		if (!outputWorkspaces[workspace.output]) {
			outputWorkspaces[workspace.output] = [];
		}
		outputWorkspaces[workspace.output].push({
			id: workspace.idx,
			is_active: workspace.is_active,
			workspace_id: workspace.idx,
			windows: windowsByWorkspace[workspace.id] || []
		});
	}

	const workspaceData: any[] = [];
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

const getAppInfo = (appId: string) => {
	if (!appId) return null;
	
	const appManager = new Apps.Apps();

	const appList = appManager.get_list();
	for (const app of appList) {
		if (app.entry.toLowerCase().includes(appId.toLowerCase())|| app.icon_name === appId || app.iconName === appId || app.name === appId || app.wm_class === appId) {
			return app;
		}
	}
	
	const commonKeywords = [
		"browser", "web", "music", "media", "video", "audio", "terminal", "editor", 
		"code", "chat", "mail", "photo", "image", "settings", "control"
	];
	
	for (const keyword of commonKeywords) {
		if (appId.toLowerCase().includes(keyword)) {
			const keywordResults = appManager.fuzzy_query(keyword);
			if (keywordResults.length > 0) {
				return keywordResults[0];
			}
		}
	}
	
	return null;
};

const AppIcon = (props: any) => {
	const appId = props.app_id;
	const isFocused = props.is_focused;
	const windowId = props.id;
	
	const app = getAppInfo(appId);
	const appName = app?.name || appId;
	
	return <button
		className={`app-icon ${isFocused ? 'focused' : ''}`}
		onClick={() => {
			exec(`niri msg action focus-window --id ${windowId}`);
		}}
	>
		<box spacing={5}>
			<icon icon={app?.iconName || 'application-x-executable'}/>
			{isFocused && <label className="app-name" label={appName} />}
		</box>
	</button>
}

const WorkspaceButton = (props: any) => {
	return <box	className={`workspace-button${props.is_active ? ' active' : ''}`} spacing={10}>
		<label className={`txt-ws`}>{props.workspace_id}</label>
		{props.windows.length > 0 && (
			<box className="app-icons" orientation={Gtk.Orientation.HORIZONTAL} spacing={5}>
				{map(props.windows, (window: Window) => (
					<AppIcon
						id={window.id}
						app_id={window.app_id}
						title={window.title}
						is_focused={window.is_focused}
					/>
				))}
			</box>
		)}
	</box>
}

const MonitorWorkspaces = (props: any) => {
	let monitorNumber
	if (props.name === "eDP-1") {
		monitorNumber = 1
	} else if (props.name === "HDMI-A-1") {
		monitorNumber = 2
	} else {
		monitorNumber = 1
	}

	const activeWorkspaces = props.workspaces.filter((ws: any) => ws.windows && ws.windows.length > 0);

	return <box className={`monitor-workspaces monitor-${monitorNumber}`} spacing={20}>
		{...(map(activeWorkspaces, (ws: any) => (
			<WorkspaceButton
				id={ws.id}
				monitor={monitorNumber}
				monitor_name={props.name}
				is_active={ws.is_active}
				workspace_id={ws.workspace_id}
				windows={ws.windows}
			/>
		)))}
	</box>
}

export default () => {
	const workspaceData = Variable(getWorkspaceData).poll(250, getWorkspaceData);

	return <box className={"Workspaces"}>
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
