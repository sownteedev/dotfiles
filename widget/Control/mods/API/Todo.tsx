import { bind, execAsync, Variable } from "astal";
import { Gtk } from "astal/gtk3";
import { getGoogleAccessToken, reloadCalendarEvents } from "./Calendar";
import { showEventForm, showTodoAddForm } from "./modalState";
import {
    clearGoogleTasksCache,
    deleteGoogleTask,
    fetchGoogleTasks,
    insertGoogleTask,
    patchGoogleTask,
    type GoogleTaskApiItem,
} from "./googleTasks";

export type TodoItem = {
    id: string;
    title: string;
    done: boolean;
    /** YYYY-MM-DD from Google Tasks */
    due?: string;
    /** Google Tasks notes */
    notes?: string;
};

function apiDueToYmd(due: string | undefined | null): string | undefined {
    if (!due) return undefined;
    return due.slice(0, 10);
}

function mapApiToItems(tasks: GoogleTaskApiItem[]): TodoItem[] {
    return tasks.map((t) => ({
        id: t.id,
        title: t.title ?? "",
        done: t.status === "completed",
        due: apiDueToYmd(t.due ?? undefined),
        notes: t.notes?.trim() ? t.notes : undefined,
    }));
}

function stripTime(d: Date): Date {
    const x = new Date(d);
    x.setHours(0, 0, 0, 0);
    return x;
}

/** DD/MM/YYYY → YYYY-MM-DD, or null if empty/invalid */
function ddmmyyyyToYmd(s: string): string | null {
    const t = s.trim();
    if (!t) return null;
    const m = t.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/);
    if (!m) return null;
    const d = Number(m[1]);
    const mo = Number(m[2]);
    const y = Number(m[3]);
    if (mo < 1 || mo > 12 || d < 1 || d > 31 || y < 1970 || y > 2100)
        return null;
    return `${y}-${String(mo).padStart(2, "0")}-${String(d).padStart(2, "0")}`;
}

function ymdToDdmmyyyy(ymd: string | undefined): string {
    if (!ymd) return "";
    const [y, mo, d] = ymd.split("-");
    if (!y || !mo || !d) return "";
    return `${d}/${mo}/${y}`;
}

const SECTION_LABEL_NO_DATE = "No date";

function getDueSectionLabel(due: string | undefined): string {
    if (!due) return SECTION_LABEL_NO_DATE;
    const d = new Date(due + "T12:00:00");
    if (Number.isNaN(d.getTime())) return SECTION_LABEL_NO_DATE;
    const today = stripTime(new Date());
    const taskDay = stripTime(d);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);
    if (taskDay.getTime() === today.getTime()) return "Today";
    if (taskDay.getTime() === tomorrow.getTime()) return "Tomorrow";
    try {
        return d.toLocaleDateString("en-US", {
            weekday: "long",
            day: "numeric",
            month: "long",
        });
    } catch {
        return due;
    }
}

function sortByDue(items: TodoItem[]): TodoItem[] {
    return [...items].sort((a, b) => {
        const ta = a.due
            ? stripTime(new Date(a.due + "T12:00:00")).getTime()
            : Number.POSITIVE_INFINITY;
        const tb = b.due
            ? stripTime(new Date(b.due + "T12:00:00")).getTime()
            : Number.POSITIVE_INFINITY;
        if (ta !== tb) return ta - tb;
        return (a.title || "").localeCompare(b.title || "", "en");
    });
}

type DueGroup = { label: string; items: TodoItem[] };

function groupByDueHeader(items: TodoItem[]): DueGroup[] {
    const sorted = sortByDue(items);
    const groups: DueGroup[] = [];
    let lastKey = "";
    for (const item of sorted) {
        const key = item.due?.slice(0, 10) ?? "__none__";
        const label = getDueSectionLabel(item.due);
        if (key !== lastKey) {
            lastKey = key;
            groups.push({ label, items: [item] });
        } else {
            groups[groups.length - 1].items.push(item);
        }
    }
    return groups;
}

let todos: Variable<TodoItem[]> | null = null;

const getTodos = (): Variable<TodoItem[]> => {
    if (!todos) todos = Variable<TodoItem[]>([]);
    return todos;
};

export const cleanupTodo = () => {
    clearGoogleTasksCache();
    if (todos) {
        todos.drop();
        todos = null;
    }
};

/** Refresh task list from Google (after add/edit from form). */
export async function reloadTodoList(): Promise<void> {
    const token = await getGoogleAccessToken();
    if (!token) return;
    const raw = await fetchGoogleTasks();
    getTodos().set(mapApiToItems(raw));
}

/** Add-task form — same layout as Calendar `event-form`. */
export const TodoAddFormDialog = () => {
    let noteAddTv: Gtk.TextView | null = null;
    let noteAddChangedId: number | null = null;
    const newTitle = Variable("");
    const newDueDate = Variable("");
    const newNote = Variable("");
    const isSubmitting = Variable(false);
    const formHint = Variable("");

    const cleanup = () => {
        if (noteAddTv && noteAddChangedId !== null) {
            noteAddTv.get_buffer().disconnect(noteAddChangedId);
        }
        noteAddChangedId = null;
        newTitle.drop();
        newDueDate.drop();
        newNote.drop();
        isSubmitting.drop();
        formHint.drop();
        noteAddTv = null;
    };

    const clearForm = () => {
        newTitle.set("");
        newDueDate.set("");
        newNote.set("");
        formHint.set("");
        if (noteAddTv) {
            noteAddTv.get_buffer().set_text("", -1);
        }
    };

    const handleCancel = () => {
        showTodoAddForm.set(false);
        clearForm();
    };

    const handleSubmit = async () => {
        const t = newTitle.get().trim();
        if (!t) return;

        const rawDue = newDueDate.get().trim();
        let dueOpt: string | undefined;
        if (rawDue) {
            const ymd = ddmmyyyyToYmd(rawDue);
            if (!ymd) {
                formHint.set("Invalid date. Use DD/MM/YYYY or leave empty.");
                return;
            }
            dueOpt = ymd;
        }
        formHint.set("");

        const notesText = newNote.get().trim();
        isSubmitting.set(true);
        const ok = await insertGoogleTask(t, {
            due: dueOpt,
            notes: notesText || undefined,
        });
        isSubmitting.set(false);
        if (ok) {
            showTodoAddForm.set(false);
            clearForm();
            await reloadTodoList();
        }
    };

    return (
        <box
            vertical
            className="event-form todo-task-form"
            spacing={15}
            onDestroy={cleanup}
        >
            <centerbox className="event-form-header">
                <label
                    label="Add task"
                    className="event-form-title-label"
                    halign={Gtk.Align.START}
                />
                <box />
                <button
                    halign={Gtk.Align.END}
                    cursor="hand1"
                    onClicked={handleCancel}
                >
                    <icon icon="go-previous-symbolic" />
                </button>
            </centerbox>

            <scrollable
                vscrollbarPolicy={Gtk.PolicyType.AUTOMATIC}
                hscrollbarPolicy={Gtk.PolicyType.NEVER}
                className="event-form-scroll"
                vexpand
            >
                <box vertical spacing={20} className="event-form-body">
                    {bind(formHint).as((h) =>
                        h ? (
                            <label
                                label={h}
                                className="todo-api-hint"
                                wrap
                                xalign={0}
                            />
                        ) : (
                            <box visible={false} />
                        ),
                    )}

                    <box vertical spacing={5}>
                        <label label="Title" xalign={0} />
                        <entry
                            className="event-form-entry"
                            text={bind(newTitle).as((x) => x ?? "")}
                            placeholderText="What needs to be done?"
                            onChanged={(self: Gtk.Entry) =>
                                newTitle.set(self.text)
                            }
                            onActivate={handleSubmit}
                        />
                    </box>

                    <box vertical spacing={5}>
                        <label label="Due (DD/MM/YYYY)" xalign={0} />
                        <entry
                            className="event-form-entry"
                            text={bind(newDueDate).as((d) => d ?? "")}
                            placeholderText="Optional — leave empty for no due date"
                            onChanged={(self: Gtk.Entry) =>
                                newDueDate.set(self.text)
                            }
                        />
                    </box>

                    <box vertical spacing={5}>
                        <label label="Notes" xalign={0} />
                        <box
                            className="todo-note-box todo-note-box--form"
                            vexpand={false}
                            setup={(self: Gtk.Box) => {
                                const tv = new Gtk.TextView();
                                tv.set_editable(true);
                                tv.set_can_focus(true);
                                tv.set_cursor_visible(true);
                                tv.set_wrap_mode(Gtk.WrapMode.WORD_CHAR);
                                tv.set_left_margin(10);
                                tv.set_right_margin(10);
                                tv.set_top_margin(8);
                                tv.set_bottom_margin(8);
                                tv.set_size_request(-1, 120);
                                tv.get_style_context().add_class(
                                    "todo-note-textview",
                                );
                                const buf = tv.get_buffer();
                                noteAddChangedId = buf.connect("changed", () => {
                                    const [s, e] = buf.get_bounds();
                                    newNote.set(buf.get_text(s, e, false));
                                });
                                (self as Gtk.Box).pack_start(tv, true, true, 0);
                                noteAddTv = tv;
                                self.show_all();
                            }}
                        />
                    </box>

                    <box halign={Gtk.Align.END}>
                        <button
                            className="event-form-submit"
                            cursor="hand1"
                            onClicked={handleSubmit}
                            sensitive={bind(isSubmitting).as((s) => !s)}
                        >
                            {bind(isSubmitting).as((submitting) =>
                                submitting ? (
                                    <label label="Saving..." />
                                ) : (
                                    <label label="Add task" />
                                ),
                            )}
                        </button>
                    </box>
                </box>
            </scrollable>
        </box>
    );
};

export const Todo = () => {
    let noteEditTv: Gtk.TextView | null = null;
    let noteEditChangedId: number | null = null;

    const editingId = Variable<string | null>(null);
    const editingText = Variable("");
    const editingDue = Variable("");
    const editingNote = Variable("");
    const isLoading = Variable(false);
    const hasToken = Variable(true);
    const isSetupRunning = Variable(false);
    const isSetupInputVisible = Variable(false);
    const setupCode = Variable("");
    const activeTab = Variable<"todo" | "done">("todo");

    const loadFromGoogle = async () => {
        const token = await getGoogleAccessToken();
        if (!token) {
            hasToken.set(false);
            getTodos().set([]);
            return;
        }
        hasToken.set(true);
        isLoading.set(true);
        try {
            await reloadTodoList();
        } finally {
            isLoading.set(false);
        }
    };

    const startGoogleSetup = async () => {
        isSetupInputVisible.set(true);
        try {
            await execAsync([
                "bash",
                "-lc",
                'cd "$HOME/Dotfiles/dotf/ags" && ./scripts/google-calendar-setup.sh --open-only',
            ]);
        } catch {
            // no-op: user can still paste code manually
        }
    };

    const runGoogleSetup = async (code: string) => {
        isSetupRunning.set(true);
        try {
            await execAsync([
                "bash",
                "-lc",
                'cd "$HOME/Dotfiles/dotf/ags" && ./scripts/google-calendar-setup.sh --auth-code "$1"',
                "--",
                code,
            ]);
        } finally {
            isSetupRunning.set(false);
        }
        await loadFromGoogle();
        await reloadCalendarEvents();
    };

    const setup = () => {
        loadFromGoogle();
    };

    const onDestroy = () => {
        if (noteEditTv && noteEditChangedId !== null) {
            noteEditTv.get_buffer().disconnect(noteEditChangedId);
        }
        noteEditChangedId = null;
        editingId.drop();
        editingText.drop();
        editingDue.drop();
        editingNote.drop();
        isLoading.drop();
        hasToken.drop();
        isSetupRunning.drop();
        isSetupInputVisible.drop();
        setupCode.drop();
        activeTab.drop();
        noteEditTv = null;
    };

    const refreshList = () => {
        getTodos().set([...getTodos().get()]);
    };

    const startEdit = (item: TodoItem) => {
        editingId.set(item.id);
        editingText.set(item.title);
        editingDue.set(ymdToDdmmyyyy(item.due));
        editingNote.set(item.notes ?? "");
        refreshList();
    };

    const saveEdit = async () => {
        const id = editingId.get();
        if (!id) return;
        const title = editingText.get().trim();
        if (!title) return;
        const item = getTodos()
            .get()
            .find((i) => i.id === id);
        if (!item) return;

        const rawDue = editingDue.get().trim();
        let patch: Parameters<typeof patchGoogleTask>[1] = { title };
        if (rawDue === "") {
            if (item.due) patch = { ...patch, due: null };
        } else {
            const ymd = ddmmyyyyToYmd(rawDue);
            if (!ymd) return;
            patch = { ...patch, due: ymd };
        }

        const nextNotes = editingNote.get().trim();
        const prevNotes = (item.notes ?? "").trim();
        if (nextNotes !== prevNotes) {
            patch = { ...patch, notes: nextNotes === "" ? null : nextNotes };
        }

        isLoading.set(true);
        const ok = await patchGoogleTask(id, patch);
        isLoading.set(false);
        if (ok) {
            if (noteEditTv && noteEditChangedId !== null) {
                noteEditTv.get_buffer().disconnect(noteEditChangedId);
            }
            noteEditChangedId = null;
            editingId.set(null);
            editingText.set("");
            editingDue.set("");
            editingNote.set("");
            await loadFromGoogle();
        }
    };

    const cancelEdit = () => {
        if (noteEditTv && noteEditChangedId !== null) {
            noteEditTv.get_buffer().disconnect(noteEditChangedId);
        }
        noteEditChangedId = null;
        editingId.set(null);
        editingText.set("");
        editingDue.set("");
        editingNote.set("");
        if (noteEditTv) {
            noteEditTv.get_buffer().set_text("", -1);
        }
        noteEditTv = null;
        refreshList();
    };

    const removeTodo = async (id: string) => {
        isLoading.set(true);
        const ok = await deleteGoogleTask(id);
        isLoading.set(false);
        if (ok) {
            getTodos().set(
                getTodos()
                    .get()
                    .filter((x) => x.id !== id),
            );
            refreshList();
        }
    };

    const toggleTodo = async (item: TodoItem) => {
        const nextStatus = item.done ? "needsAction" : "completed";
        isLoading.set(true);
        const ok = await patchGoogleTask(item.id, { status: nextStatus });
        isLoading.set(false);
        if (ok) {
            getTodos().set(
                getTodos()
                    .get()
                    .map((it) =>
                        it.id === item.id ? { ...it, done: !it.done } : it,
                    ),
            );
            refreshList();
        }
    };

    return (
        <box
            vertical
            className="todo-container"
            spacing={15}
            setup={setup}
            onDestroy={onDestroy}
        >
            <box vertical spacing={8}>
                <centerbox className="todo-header todo-header-bar">
                    <box hexpand halign={Gtk.Align.START} />
                    <label
                        label="Google Tasks"
                        className="todo-title"
                        xalign={0}
                    />
                    <box spacing={8} hexpand halign={Gtk.Align.END}>
                        <button
                            className="todo-add-button"
                            cursor="hand1"
                            sensitive={bind(isLoading).as((l) => !l)}
                            onClicked={() => {
                                showEventForm.set(false);
                                showTodoAddForm.set(true);
                            }}
                            tooltipText="Add task"
                        >
                            <icon icon="list-add-symbolic" />
                        </button>
                    </box>
                </centerbox>

                <box
                    visible={bind(hasToken).as((ok) => !ok)}
                    vertical
                    spacing={8}
                    className="todo-setup-wrap"
                    halign={Gtk.Align.FILL}
                    hexpand
                >
                    <box visible={bind(isSetupInputVisible).as((v) => !v)}>
                        <button
                            className="todo-setup-button"
                            cursor="hand1"
                            onClicked={startGoogleSetup}
                        >
                            <label label="Run setup" />
                        </button>
                    </box>
                    <box
                        visible={bind(isSetupInputVisible)}
                        vertical
                        spacing={8}
                    >
                        <label
                            label="Paste authorization code"
                            className="todo-setup-label"
                            xalign={0}
                            wrap
                        />
                        <entry
                            className="todo-setup-entry"
                            text={bind(setupCode).as((x) => x ?? "")}
                            placeholderText="4/..."
                            hexpand
                            onChanged={(self: Gtk.Entry) =>
                                setupCode.set(self.text)
                            }
                        />
                        <box>
                            <button
                                className="todo-setup-button"
                                cursor="hand1"
                                onClicked={async () => {
                                    const code = setupCode.get().trim();
                                    if (!code) return;
                                    await runGoogleSetup(code);
                                    setupCode.set("");
                                }}
                                sensitive={bind(isSetupRunning).as((s) => !s)}
                            >
                                {bind(isSetupRunning).as((s) =>
                                    s ? (
                                        <label label="Running setup..." />
                                    ) : (
                                        <label label="Done" />
                                    ),
                                )}
                            </button>
                        </box>
                    </box>
                </box>

                <box className="todo-filter-tabs" spacing={8}>
                    <button
                        className={bind(activeTab).as((tab) =>
                            tab === "todo"
                                ? "todo-filter-tab active"
                                : "todo-filter-tab",
                        )}
                        cursor="hand1"
                        onClicked={() => {
                            activeTab.set("todo");
                            refreshList();
                        }}
                    >
                        <label label="To do" />
                    </button>
                    <button
                        className={bind(activeTab).as((tab) =>
                            tab === "done"
                                ? "todo-filter-tab active"
                                : "todo-filter-tab",
                        )}
                        cursor="hand1"
                        onClicked={() => {
                            activeTab.set("done");
                            refreshList();
                        }}
                    >
                        <label label="Done" />
                    </button>
                </box>

                <scrollable
                    vscrollbarPolicy={Gtk.PolicyType.AUTOMATIC}
                    hscrollbarPolicy={Gtk.PolicyType.NEVER}
                    className="todo-scroll"
                    vexpand
                >
                    <box vertical className="todo-list" spacing={12}>
                        {bind(getTodos()).as((items) => {
                            const filteredItems = items.filter((item) =>
                                activeTab.get() === "todo"
                                    ? !item.done
                                    : item.done,
                            );

                            if (filteredItems.length === 0) {
                                return (
                                    <box
                                        className="todo-empty"
                                        halign={Gtk.Align.CENTER}
                                        valign={Gtk.Align.CENTER}
                                        vexpand
                                        vertical
                                        spacing={10}
                                    >
                                        <icon
                                            icon="view-list-symbolic"
                                            className="todo-empty-icon"
                                        />
                                        <label
                                            label="No tasks"
                                            className="todo-empty-text"
                                        />
                                    </box>
                                );
                            }

                            const groups = groupByDueHeader(filteredItems);
                            const currentEditId = editingId.get();

                            return groups.map((group) => (
                                <box
                                    vertical
                                    spacing={8}
                                    className="todo-due-group"
                                >
                                    <label
                                        label={group.label}
                                        className="todo-section-header"
                                        xalign={0}
                                    />
                                    {group.items.map((item: TodoItem) => {
                                        const isEditing =
                                            currentEditId === item.id;
                                        return (
                                            <box
                                                key={item.id}
                                                className="todo-item"
                                                spacing={12}
                                                valign={Gtk.Align.CENTER}
                                            >
                                                <button
                                                    className="todo-check"
                                                    cursor="hand1"
                                                    valign={Gtk.Align.CENTER}
                                                    sensitive={bind(
                                                        isLoading,
                                                    ).as((l) => !l)}
                                                    onClicked={() =>
                                                        toggleTodo(item)
                                                    }
                                                >
                                                    <icon
                                                        icon={
                                                            item.done
                                                                ? "checkbox-checked-symbolic"
                                                                : "checkbox-symbolic"
                                                        }
                                                        className={
                                                            item.done
                                                                ? "todo-check-done"
                                                                : ""
                                                        }
                                                    />
                                                </button>
                                                {isEditing ? (
                                                    <box
                                                        vertical
                                                        spacing={6}
                                                        hexpand
                                                    >
                                                        <entry
                                                            className="todo-edit-entry"
                                                            text={bind(
                                                                editingText,
                                                            ).as(
                                                                (t) => t ?? "",
                                                            )}
                                                            hexpand
                                                            onChanged={(
                                                                self: Gtk.Entry,
                                                            ) =>
                                                                editingText.set(
                                                                    self.text,
                                                                )
                                                            }
                                                            onActivate={
                                                                saveEdit
                                                            }
                                                        />
                                                        <entry
                                                            className="todo-edit-due-entry"
                                                            text={bind(
                                                                editingDue,
                                                            ).as(
                                                                (t) => t ?? "",
                                                            )}
                                                            placeholderText="Due DD/MM/YYYY (empty = clear due date)"
                                                            hexpand
                                                            onChanged={(
                                                                self: Gtk.Entry,
                                                            ) =>
                                                                editingDue.set(
                                                                    self.text,
                                                                )
                                                            }
                                                        />
                                                        <label
                                                            className="todo-field-label"
                                                            label="Notes"
                                                            xalign={0}
                                                        />
                                                        <box
                                                            className="todo-edit-note-box"
                                                            vexpand={false}
                                                            hexpand
                                                            setup={(
                                                                self: Gtk.Box,
                                                            ) => {
                                                                const tv =
                                                                    new Gtk.TextView();
                                                                tv.set_editable(
                                                                    true,
                                                                );
                                                                tv.set_can_focus(
                                                                    true,
                                                                );
                                                                tv.set_cursor_visible(
                                                                    true,
                                                                );
                                                                tv.set_wrap_mode(
                                                                    Gtk.WrapMode
                                                                        .WORD_CHAR,
                                                                );
                                                                tv.set_left_margin(
                                                                    10,
                                                                );
                                                                tv.set_right_margin(
                                                                    10,
                                                                );
                                                                tv.set_top_margin(
                                                                    8,
                                                                );
                                                                tv.set_bottom_margin(
                                                                    8,
                                                                );
                                                                tv.set_size_request(
                                                                    -1,
                                                                    88,
                                                                );
                                                                tv.set_accepts_tab(
                                                                    false,
                                                                );
                                                                tv.get_style_context().add_class(
                                                                    "todo-note-textview",
                                                                );
                                                                const buf =
                                                                    tv.get_buffer();
                                                                buf.set_text(
                                                                    editingNote.get(),
                                                                    -1,
                                                                );
                                                                if (
                                                                    noteEditTv &&
                                                                    noteEditChangedId !== null
                                                                ) {
                                                                    noteEditTv
                                                                        .get_buffer()
                                                                        .disconnect(
                                                                            noteEditChangedId,
                                                                        );
                                                                }
                                                                noteEditChangedId =
                                                                    buf.connect(
                                                                    "changed",
                                                                    () => {
                                                                        const [
                                                                            s,
                                                                            e,
                                                                        ] =
                                                                            buf.get_bounds();
                                                                        editingNote.set(
                                                                            buf.get_text(
                                                                                s,
                                                                                e,
                                                                                false,
                                                                            ),
                                                                        );
                                                                    },
                                                                );
                                                                (
                                                                    self as Gtk.Box
                                                                ).pack_start(
                                                                    tv,
                                                                    true,
                                                                    true,
                                                                    0,
                                                                );
                                                                noteEditTv = tv;
                                                                self.show_all();
                                                            }}
                                                        />
                                                        <box spacing={6}>
                                                            <button
                                                                className="todo-edit-ok"
                                                                cursor="hand1"
                                                                onClicked={
                                                                    saveEdit
                                                                }
                                                            >
                                                                <icon icon="emblem-ok-symbolic" />
                                                            </button>
                                                            <button
                                                                className="todo-edit-cancel"
                                                                cursor="hand1"
                                                                onClicked={
                                                                    cancelEdit
                                                                }
                                                            >
                                                                <icon icon="window-close-symbolic" />
                                                            </button>
                                                        </box>
                                                    </box>
                                                ) : (
                                                    <box
                                                        vertical
                                                        spacing={6}
                                                        hexpand
                                                        valign={Gtk.Align.CENTER}
                                                    >
                                                        <label
                                                            label={item.title}
                                                            className={`todo-text ${
                                                                item.done
                                                                    ? "todo-text-done"
                                                                    : ""
                                                            }`}
                                                            xalign={0}
                                                            wrap
                                                            hexpand
                                                        />
                                                        {item.notes &&
                                                        item.notes.trim() ? (
                                                            <box
                                                                spacing={8}
                                                                className="todo-notes-row"
                                                                hexpand
                                                            >
                                                                <icon
                                                                    icon="format-justify-left-symbolic"
                                                                    className="todo-notes-icon"
                                                                />
                                                                <label
                                                                    label={item.notes.trim()}
                                                                    className="todo-notes-text"
                                                                    wrap
                                                                    xalign={0}
                                                                    hexpand
                                                                />
                                                            </box>
                                                        ) : null}
                                                        {item.due && (
                                                            <label
                                                                label={ymdToDdmmyyyy(
                                                                    item.due,
                                                                )}
                                                                className="todo-due-chip"
                                                                xalign={0}
                                                            />
                                                        )}
                                                    </box>
                                                )}
                                                <box
                                                    spacing={6}
                                                    valign={Gtk.Align.CENTER}
                                                    className="todo-item-actions"
                                                >
                                                    {!isEditing &&
                                                        !item.done && (
                                                            <button
                                                                className="todo-edit-button"
                                                                cursor="hand1"
                                                                valign={
                                                                    Gtk.Align.CENTER
                                                                }
                                                                onClicked={() =>
                                                                    startEdit(
                                                                        item,
                                                                    )
                                                                }
                                                                tooltipText="Edit"
                                                            >
                                                                <icon icon="document-edit-symbolic" />
                                                            </button>
                                                        )}
                                                    <button
                                                        className="todo-delete"
                                                        onClicked={() =>
                                                            removeTodo(item.id)
                                                        }
                                                        cursor="hand1"
                                                        valign={
                                                            Gtk.Align.CENTER
                                                        }
                                                        tooltipText="Delete"
                                                        sensitive={bind(
                                                            isLoading,
                                                        ).as((l) => !l)}
                                                    >
                                                        <icon icon="user-trash-symbolic" />
                                                    </button>
                                                </box>
                                            </box>
                                        );
                                    })}
                                </box>
                            ));
                        })}
                    </box>
                </scrollable>
            </box>
        </box>
    );
};
