import { bind, Variable, derive } from "astal";
import { Gtk } from "astal/gtk3";
import { Calendar } from "./Calendar";
import { Todo, cleanupTodo, TodoAddFormDialog } from "./Todo";
import { Weather, weatherData, isWeatherLoading, cleanupWeather } from "./Weather";
import {
    currentDate,
    calendarEvents,
    isCalendarLoading,
    EventFormDialog,
    selectedDateForEvents,
    prefillDateForNewEvent,
    datesWithEvents,
} from "./Calendar";
import { showEventForm, showTodoAddForm } from "./modalState";

// ========== TAB MANAGEMENT (global, singleton) ==========
const buttonSelected = Variable(0);

// Factory functions to create new component instances
// (GTK widgets are destroyed when removed from tree, so we must recreate)
const createContent = (index: number): JSX.Element => {
    switch (index) {
        case 0:
            return <Calendar />;
        case 1:
            return <Todo />;
        case 2:
            return <Weather />;
        default:
            return <Calendar />;
    }
};

const content = Variable<JSX.Element>(createContent(0));

/** Ẩn tab Calendar/Todo/Weather khi đang mở form Calendar hoặc form thêm task */
const showMainTabContent = derive(
    [showEventForm, showTodoAddForm],
    (event, todo) => !event && !todo,
);

// Button config (static)
const buttons = [
    {
        label: "Calendar",
        activeIcon: "calendar-active",
        inactiveIcon: "calendar-i",
    },
    {
        label: "To Do",
        activeIcon: "todo-active",
        inactiveIcon: "todo-inactive",
    },
    {
        label: "Weather",
        activeIcon: "weather-few-clouds-symbolic",
        inactiveIcon: "weather-few-clouds-symbolic",
    },
];

const cleanupAll = () => {
    cleanupWeather();

    cleanupTodo();

    try {
        currentDate.drop();
        weatherData.drop();
        isWeatherLoading.drop();
        buttonSelected.drop();
        content.drop();
        calendarEvents.drop();
        isCalendarLoading.drop();
        showEventForm.drop();
        showTodoAddForm.drop();
        showMainTabContent.drop();
        selectedDateForEvents.drop();
        prefillDateForNewEvent.drop();
        datesWithEvents.drop();
    } catch {
        // Variables might already be dropped
    }
};

// Main component
export default () => {
    return (
        <box
            vertical
            className="calendar-todo-weather-container"
            spacing={30}
            onDestroy={cleanupAll}
        >
            <box
                spacing={10}
                className="button-container"
                halign={Gtk.Align.CENTER}
            >
                {buttons.map((button, index) => (
                    <button
                        cursor="hand1"
                        className={bind(buttonSelected).as((selected) =>
                            selected === index ? "active" : ""
                        )}
                        onClicked={() => {
                            if (buttonSelected.get() !== index) {
                                showEventForm.set(false);
                                showTodoAddForm.set(false);
                                buttonSelected.set(index);
                                content.set(createContent(index));
                            }
                        }}
                    >
                        {bind(buttonSelected).as((selected) => {
                            const icon =
                                selected === index
                                    ? button.activeIcon
                                    : button.inactiveIcon;

                            if (selected === index) {
                                return (
                                    <box spacing={10}>
                                        <icon icon={icon} />
                                        <label label={button.label} />
                                    </box>
                                );
                            }
                            return <icon icon={icon} />;
                        })}
                    </button>
                ))}
            </box>
            <box vertical spacing={10}>
                {bind(showEventForm).as((show) =>
                    show ? (
                        <EventFormDialog />
                    ) : (
                        <box visible={false} />
                    ),
                )}
                {bind(showTodoAddForm).as((show) =>
                    show ? (
                        <TodoAddFormDialog />
                    ) : (
                        <box visible={false} />
                    ),
                )}
                <box visible={bind(showMainTabContent)}>
                    {bind(content)}
                </box>
            </box>
        </box>
    );
};