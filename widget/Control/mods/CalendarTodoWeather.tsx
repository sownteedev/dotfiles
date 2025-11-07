import { bind, Variable, GLib } from "astal";
import { Gtk } from "astal/gtk3";

// Types
interface TodoItem {
    id: number;
    text: string;
    completed: boolean;
    createdAt: number;
}

interface WeatherData {
    temperature: string;
    condition: string;
    icon: string;
    humidity: string;
    windSpeed: string;
}

// State variables
const currentDate = Variable<Date>(new Date());
const selectedDate = Variable<Date>(new Date());
const todoList = Variable<TodoItem[]>([]);
const weatherData = Variable<WeatherData>({
    temperature: "24°C",
    condition: "Partly Cloudy",
    icon: "weather-few-clouds-symbolic",
    humidity: "65%",
    windSpeed: "12 km/h"
});

// Helper functions
const getDaysInMonth = (date: Date) => {
    return new Date(date.getFullYear(), date.getMonth() + 1, 0).getDate();
};

const getFirstDayOfMonth = (date: Date) => {
    return new Date(date.getFullYear(), date.getMonth(), 1).getDay();
};

const formatDate = (date: Date, format: string) => {
    const gDate = GLib.DateTime.new_from_unix_local(date.getTime() / 1000);
    return gDate.format(format) || "";
};

const isToday = (date: Date) => {
    const today = new Date();
    return date.getDate() === today.getDate() &&
           date.getMonth() === today.getMonth() &&
           date.getFullYear() === today.getFullYear();
};

const isSameDay = (date1: Date, date2: Date) => {
    return date1.getDate() === date2.getDate() &&
           date1.getMonth() === date2.getMonth() &&
           date1.getFullYear() === date2.getFullYear();
};

// Calendar component
const Calendar = () => {
    const monthNames = ["January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"];
    
    const weekDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

    const navigateMonth = (direction: number) => {
        const current = currentDate.get();
        const newDate = new Date(current.getFullYear(), current.getMonth() + direction, 1);
        currentDate.set(newDate);
    };

    const selectDate = (day: number) => {
        const current = currentDate.get();
        const selected = new Date(current.getFullYear(), current.getMonth(), day);
        selectedDate.set(selected);
    };

    return (
        <box vertical className="calendar-container" spacing={10}>
            {/* Calendar Header */}
            <box className="calendar-header" spacing={20} halign={Gtk.Align.CENTER}>
                <button 
                    onClicked={() => navigateMonth(-1)}
                    cursor="hand1"
                >
                    <icon icon="pan-start-symbolic" />
                </button>
                
                <label 
                    label={bind(currentDate).as(date => 
                        `${monthNames[date.getMonth()]} ${date.getFullYear()}`
                    )}
                />
                
                <button 
                    onClicked={() => navigateMonth(1)}
                    cursor="hand1"
                >
                    <icon icon="pan-end-symbolic" />
                </button>
            </box>

            {/* Week days header */}
            <box className="calendar-weekdays" spacing={5}>
                {weekDays.map((day, idx) => (
                    <label
                        label={day} 
                        className={idx >= 5 ? "weekend" : ""}
                        halign={Gtk.Align.CENTER}
                        hexpand
                    />
                ))}
            </box>

            {/* Calendar grid */}
            <box vertical className="calendar-grid" spacing={5}>
                {bind(currentDate).as(date => {
                    const year = date.getFullYear();
                    const month = date.getMonth();
                    const daysInMonth = getDaysInMonth(date);
                    // JS: 0=Sun..6=Sat → Shift to Monday-first: 0=Mon..6=Sun
                    const jsFirst = getFirstDayOfMonth(date);
                    const firstDay = (jsFirst + 6) % 7;
                    const prevMonthLastDay = new Date(year, month, 0).getDate();

                    const totalCells = 42; // 6 weeks x 7 days
                    const cells: JSX.Element[] = [];

                    // Leading days from previous month
                    for (let i = 0; i < firstDay; i++) {
                        const dayNum = prevMonthLastDay - firstDay + 1 + i;
                        const dow = i % 7; // 0=Mon..6=Sun
                        const isWeekend = dow === 5 || dow === 6;
                        cells.push(
                            <button className={`calendar-day not-in ${isWeekend ? 'weekend' : ''}`} hexpand>
                                <label label={dayNum.toString()} />
                            </button>
                        );
                    }

                    // Current month days
                    for (let d = 1; d <= daysInMonth; d++) {
                        const idx = firstDay + d - 1;
                        const dow = idx % 7;
                        const isWeekend = dow === 5 || dow === 6;
                        const dayDate = new Date(year, month, d);
                        const isSelectedDay = bind(selectedDate).as(selected => isSameDay(dayDate, selected));
                        const isTodayDay = isToday(dayDate);

                        cells.push(
                            <button
                                className={`calendar-day ${isWeekend ? 'weekend' : ''} ${isTodayDay ? 'today' : ''}`}
                                onClicked={() => selectDate(d)}
                                cursor="hand1"
                                hexpand
                            >
                                <label
                                    label={d.toString()}
                                    className={bind(isSelectedDay).as(selected => selected ? 'selected' : '')}
                                />
                            </button>
                        );
                    }

                    // Trailing days from next month to fill 42 cells
                    const trailing = totalCells - cells.length;
                    for (let i = 1; i <= trailing; i++) {
                        const idx = firstDay + daysInMonth + i - 1;
                        const dow = idx % 7;
                        const isWeekend = dow === 5 || dow === 6;
                        cells.push(
                            <button className={`calendar-day not-in ${isWeekend ? 'weekend' : ''}`} hexpand>
                                <label label={i.toString()} />
                            </button>
                        );
                    }

                    // Group into rows
                    const weeks: JSX.Element[] = [];
                    for (let w = 0; w < 6; w++) {
                        weeks.push(
                            <box className="calendar-week" spacing={15}>
                                {cells.slice(w * 7, (w + 1) * 7)}
                            </box>
                        );
                    }

                    return weeks;
                })}
            </box>
        </box>
    );
};

// Todo component
const Todo = () => {
    const newTodoText = Variable("");
    const todoIdCounter = Variable(1);

    const addTodo = () => {
        const text = newTodoText.get().trim();
        if (text) {
            const newTodo: TodoItem = {
                id: todoIdCounter.get(),
                text,
                completed: false,
                createdAt: Date.now()
            };
            todoList.set([...todoList.get(), newTodo]);
            todoIdCounter.set(todoIdCounter.get() + 1);
            newTodoText.set("");
        }
    };

    const toggleTodo = (id: number) => {
        const todos = todoList.get();
        const updatedTodos = todos.map(todo =>
            todo.id === id ? { ...todo, completed: !todo.completed } : todo
        );
        todoList.set(updatedTodos);
    };

    const deleteTodo = (id: number) => {
        const todos = todoList.get();
        const filteredTodos = todos.filter(todo => todo.id !== id);
        todoList.set(filteredTodos);
    };

    return (
        <box vertical className="todo-container" spacing={10}>
            {/* Todo header */}
            <box className="todo-header" spacing={10}>
                <icon icon="view-list-symbolic" />
                <label label="To Do" className="todo-title" hexpand />
            </box>

            {/* Add todo input */}
            <box className="todo-input" spacing={10}>
                <entry
                    className="todo-entry"
                    placeholderText="Add a new task..."
                    text={bind(newTodoText)}
                    onChanged={(self) => newTodoText.set(self.text)}
                    onActivate={addTodo}
                    hexpand
                />
                <button
                    className="todo-add-button"
                    onClicked={addTodo}
                    cursor="hand1"
                >
                    <icon icon="list-add-symbolic" />
                </button>
            </box>

            {/* Todo list */}
            <scrollable
                vscrollbarPolicy={Gtk.PolicyType.AUTOMATIC}
                hscrollbarPolicy={Gtk.PolicyType.NEVER}
                className="todo-scroll"
            >
                <box vertical className="todo-list" spacing={5}>
                    {bind(todoList).as(todos => {
                        if (todos.length === 0) {
                            return (
                                <box className="todo-empty" halign={Gtk.Align.CENTER}>
                                    <label label="No tasks yet" className="todo-empty-text" />
                                </box>
                            );
                        }

                        return todos.map(todo => (
                            <box className={`todo-item ${todo.completed ? 'completed' : ''}`} spacing={10}>
                                <button
                                    className="todo-checkbox"
                                    onClicked={() => toggleTodo(todo.id)}
                                    cursor="hand1"
                                >
                                    <icon icon={todo.completed ? "checkbox-checked-symbolic" : "checkbox-symbolic"} />
                                </button>
                                
                                <label
                                    label={todo.text}
                                    className="todo-text"
                                    hexpand
                                    xalign={0}
                                    wrap
                                />
                                
                                <button
                                    className="todo-delete"
                                    onClicked={() => deleteTodo(todo.id)}
                                    cursor="hand1"
                                >
                                    <icon icon="user-trash-symbolic" />
                                </button>
                            </box>
                        ));
                    })}
                </box>
            </scrollable>
        </box>
    );
};

// Weather component
const Weather = () => {
    // Simulated weather update (you can replace with real API call)
    const updateWeather = () => {
        // This would be replaced with actual weather API call
        const conditions = [
            { temp: "22°C", condition: "Sunny", icon: "weather-clear-symbolic" },
            { temp: "18°C", condition: "Cloudy", icon: "weather-overcast-symbolic" },
            { temp: "25°C", condition: "Partly Cloudy", icon: "weather-few-clouds-symbolic" },
            { temp: "15°C", condition: "Rainy", icon: "weather-showers-symbolic" }
        ];
        
        const randomCondition = conditions[Math.floor(Math.random() * conditions.length)];
        weatherData.set({
            temperature: randomCondition.temp,
            condition: randomCondition.condition,
            icon: randomCondition.icon,
            humidity: `${50 + Math.floor(Math.random() * 30)}%`,
            windSpeed: `${5 + Math.floor(Math.random() * 20)} km/h`
        });
    };

    // Manage periodic update timer safely to avoid leaks
    let weatherTimeoutId: number | null = null;
    const startWeatherTimer = () => {
        if (weatherTimeoutId) {
            GLib.source_remove(weatherTimeoutId);
            weatherTimeoutId = null;
        }
        weatherTimeoutId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 300000, () => {
            updateWeather();
            return true; // keep repeating while component exists
        });
    };
    startWeatherTimer();

    return (
        <box vertical className="weather-container" spacing={10} onDestroy={() => {
            if (weatherTimeoutId) {
                GLib.source_remove(weatherTimeoutId);
                weatherTimeoutId = null;
            }
        }}>
            {/* Weather header */}
            <box className="weather-header" spacing={10}>
                <icon icon="weather-few-clouds-symbolic" />
                <label label="Weather" className="weather-title" hexpand />
                <button
                    className="weather-refresh"
                    onClicked={() => { updateWeather(); startWeatherTimer(); }}
                    cursor="hand1"
                >
                    <icon icon="view-refresh-symbolic" />
                </button>
            </box>

            {/* Current weather */}
            <box className="weather-current" spacing={15}>
                <icon 
                    icon={bind(weatherData).as(data => data.icon)}
                    className="weather-icon"
                />
                
                <box vertical spacing={5}>
                    <label
                        label={bind(weatherData).as(data => data.temperature)}
                        className="weather-temperature"
                    />
                    <label
                        label={bind(weatherData).as(data => data.condition)}
                        className="weather-condition"
                    />
                </box>
            </box>

            {/* Weather details */}
            <box vertical className="weather-details" spacing={8}>
                <box className="weather-detail" spacing={10}>
                    <icon icon="weather-storm-symbolic" className="weather-detail-icon" />
                    <label label="Humidity:" className="weather-detail-label" />
                    <label
                        label={bind(weatherData).as(data => data.humidity)}
                        className="weather-detail-value"
                        xalign={1}
                        hexpand
                    />
                </box>
                
                <box className="weather-detail" spacing={10}>
                    <icon icon="weather-windy-symbolic" className="weather-detail-icon" />
                    <label label="Wind:" className="weather-detail-label" />
                    <label
                        label={bind(weatherData).as(data => data.windSpeed)}
                        className="weather-detail-value"
                        xalign={1}
                        hexpand
                    />
                </box>
            </box>
        </box>
    );
};

// Main component
export default () => {
    const cleanup = () => {
        currentDate.drop();
        selectedDate.drop();
        todoList.drop();
        weatherData.drop();
    };

    const buttonSelected = Variable(0);

    const buttons = [
        {
            label: "Calendar",
            icon: bind(buttonSelected).as((selected) => selected === 0 ? "calendar-active" : "calendar-i"),
        },
        {
            label: "To Do",
            icon: bind(buttonSelected).as((selected) => selected === 1 ? "todo-active" : "todo"),
        },
        {
            label: "Weather",
            icon: "weather-few-clouds-symbolic",
        },
    ];

    const content = Variable(<Calendar />);

    return (
        <box vertical className="calendar-todo-weather-container" spacing={30} onDestroy={cleanup}>
            <box spacing={10} className="button-container" halign={Gtk.Align.CENTER}>
                {buttons.map((button, index) => (
                    <button
                        cursor={"hand1"}
                        className={bind(buttonSelected).as((selected) => {
                            if (selected === index) {
                                return "active";
                            }
                            return "";
                        })}
                        onClicked={() => {
                            if (button.label === "Calendar") {
                                content.set(<Calendar />);
                                buttonSelected.set(index);
                            } else if (button.label === "To Do") {
                                content.set(<Todo />);
                                buttonSelected.set(index);
                            } else if (button.label === "Weather") {
                                content.set(<Weather />);
                                buttonSelected.set(index);
                            }
                        }}>
                        {bind(buttonSelected).as((selected) => {
                            if (selected === index) {
                                return <box spacing={10}>
                                    <icon icon={button.icon} />
                                    <label label={button.label} />
                                </box>
                            }
                            return <icon icon={button.icon} />
                        })}
                    </button>
                ))}
            </box>
            <box vertical spacing={10}>
                {bind(content).as((content) => {
                    return content;
                })}
            </box>
        </box>
    );
};

