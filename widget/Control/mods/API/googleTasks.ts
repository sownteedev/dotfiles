import { execAsync } from "astal";
import Global from "../../../../Global";
import { getGoogleAccessToken } from "./Calendar";

const TASKS_API = "https://tasks.googleapis.com/tasks/v1";

export type GoogleTaskApiItem = {
    id: string;
    title: string;
    status?: string;
    /** RFC3339 (Google Tasks) */
    due?: string | null;
    /** Ghi chú / chi tiết */
    notes?: string | null;
};

let cachedTaskListId: string | null = null;

export const clearGoogleTasksCache = () => {
    cachedTaskListId = null;
};

const getTaskListId = async (): Promise<string | null> => {
    const fromConfig = Global.Todo?.taskListId?.trim();
    if (fromConfig) return fromConfig;

    if (cachedTaskListId) return cachedTaskListId;

    const token = await getGoogleAccessToken();
    if (!token) return null;

    try {
        const res = await execAsync([
            "curl",
            "-s",
            "-H",
            `Authorization: Bearer ${token}`,
            `${TASKS_API}/users/@me/lists`,
        ]);
        const data = JSON.parse(res);
        if (data.error) {
            console.error("Google Tasks list error:", data.error);
            return null;
        }
        const first = data.items?.[0];
        if (!first?.id) return null;
        cachedTaskListId = first.id;
        return cachedTaskListId;
    } catch (e) {
        console.error("getTaskListId failed:", e);
        return null;
    }
};

export const fetchGoogleTasks = async (): Promise<GoogleTaskApiItem[]> => {
    const token = await getGoogleAccessToken();
    if (!token) return [];

    const listId = await getTaskListId();
    if (!listId) return [];

    try {
        const url = `${TASKS_API}/lists/${encodeURIComponent(
            listId,
        )}/tasks?maxResults=100&showCompleted=true&showHidden=true`;
        const res = await execAsync([
            "curl",
            "-s",
            "-H",
            `Authorization: Bearer ${token}`,
            url,
        ]);
        const data = JSON.parse(res);
        if (data.error) {
            console.error("Google Tasks fetch error:", data.error);
            return [];
        }
        return Array.isArray(data.items) ? data.items : [];
    } catch (e) {
        console.error("fetchGoogleTasks failed:", e);
        return [];
    }
};

export type InsertGoogleTaskOptions = {
    /** YYYY-MM-DD */
    due?: string | null;
    notes?: string | null;
};

/** due + notes tùy chọn (Google Tasks POST) */
export const insertGoogleTask = async (
    title: string,
    options?: InsertGoogleTaskOptions | null,
): Promise<boolean> => {
    const token = await getGoogleAccessToken();
    if (!token) return false;

    const listId = await getTaskListId();
    if (!listId) return false;

    try {
        const payload: Record<string, string> = { title: title.trim() };
        const dueIso = options?.due?.trim();
        if (dueIso) {
            payload.due = `${dueIso}T00:00:00.000Z`;
        }
        const noteText = options?.notes?.trim();
        if (noteText) {
            payload.notes = noteText;
        }
        const body = JSON.stringify(payload);
        const res = await execAsync([
            "curl",
            "-s",
            "-X",
            "POST",
            `${TASKS_API}/lists/${encodeURIComponent(listId)}/tasks`,
            "-H",
            `Authorization: Bearer ${token}`,
            "-H",
            "Content-Type: application/json",
            "-d",
            body,
        ]);
        const data = JSON.parse(res);
        if (data.error) {
            console.error("insertGoogleTask error:", data.error);
            return false;
        }
        return !!data.id;
    } catch (e) {
        console.error("insertGoogleTask failed:", e);
        return false;
    }
};

export const patchGoogleTask = async (
    taskId: string,
    patch: {
        title?: string;
        status?: "needsAction" | "completed";
        /** Gửi null để xóa hạn (Google Tasks PATCH) */
        due?: string | null;
        /** Gửi null hoặc "" để xóa ghi chú */
        notes?: string | null;
    },
): Promise<boolean> => {
    const token = await getGoogleAccessToken();
    if (!token) return false;

    const listId = await getTaskListId();
    if (!listId) return false;

    try {
        const bodyObj: Record<string, unknown> = {};
        if (patch.title !== undefined) bodyObj.title = patch.title;
        if (patch.status !== undefined) bodyObj.status = patch.status;
        if (patch.due !== undefined) {
            bodyObj.due =
                patch.due === null
                    ? null
                    : `${patch.due}T00:00:00.000Z`;
        }
        if (patch.notes !== undefined) {
            bodyObj.notes = patch.notes === null ? "" : patch.notes;
        }
        const body = JSON.stringify(bodyObj);
        const res = await execAsync([
            "curl",
            "-s",
            "-X",
            "PATCH",
            `${TASKS_API}/lists/${encodeURIComponent(
                listId,
            )}/tasks/${encodeURIComponent(taskId)}`,
            "-H",
            `Authorization: Bearer ${token}`,
            "-H",
            "Content-Type: application/json",
            "-d",
            body,
        ]);
        const data = JSON.parse(res);
        if (data.error) {
            console.error("patchGoogleTask error:", data.error);
            return false;
        }
        return true;
    } catch (e) {
        console.error("patchGoogleTask failed:", e);
        return false;
    }
};

export const deleteGoogleTask = async (taskId: string): Promise<boolean> => {
    const token = await getGoogleAccessToken();
    if (!token) return false;

    const listId = await getTaskListId();
    if (!listId) return false;

    try {
        const res = await execAsync([
            "curl",
            "-s",
            "-X",
            "DELETE",
            "-H",
            `Authorization: Bearer ${token}`,
            `${TASKS_API}/lists/${encodeURIComponent(
                listId,
            )}/tasks/${encodeURIComponent(taskId)}`,
        ]);
        const t = res.trim();
        if (!t) return true;
        try {
            const data = JSON.parse(t);
            return !data.error;
        } catch {
            return true;
        }
    } catch (e) {
        console.error("deleteGoogleTask failed:", e);
        return false;
    }
};
