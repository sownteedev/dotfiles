import { bind, Variable, GLib, execAsync } from "astal";
import { Gtk } from "astal/gtk3";
import Global from "../../../Global";

// Types
interface TodoItem {
    id: number;
    text: string;
    completed: boolean;
    createdAt: number;
}

// Google Calendar Event interface
interface CalendarEvent {
    id: string;
    summary: string;
    description?: string;
    start: {
        dateTime?: string;
        date?: string;
    };
    end: {
        dateTime?: string;
        date?: string;
    };
    recurrence?: string[];
}

// Form state for new event
interface EventForm {
    title: string;
    date: string;
    startTime: string;
    endTime: string;
    allDay: boolean;
    recurrence: string;
}

interface DailyForecast {
    day: string;
    icon: string;
    tempMax: number;
    tempMin: number;
}

interface WeatherData {
    temperature: number;
    feelsLike: number;
    tempMax: number;
    tempMin: number;
    condition: string;
    icon: string;
    humidity: number;
    city: string;
    country: string;
    daily: DailyForecast[];
}

// Weather API Configuration
const WEATHER_CONFIG = {
    apiKey: Global.APIWeather,
    lat: Global.LatLon.split(",")[0],
    lon: Global.LatLon.split(",")[1],
    units: "metric",
    updateInterval: 300000, // 5 minutes in ms
};

// OpenWeatherMap icon to GTK icon mapping
const WEATHER_ICON_MAP: { [key: string]: string } = {
    "01d": "weather-clear-symbolic",
    "01n": "weather-clear-night-symbolic",
    "02d": "weather-few-clouds-symbolic",
    "02n": "weather-few-clouds-night-symbolic",
    "03d": "weather-clouds-symbolic",
    "03n": "weather-clouds-night-symbolic",
    "04d": "weather-overcast-symbolic",
    "04n": "weather-overcast-symbolic",
    "09d": "weather-showers-symbolic",
    "09n": "weather-showers-symbolic",
    "10d": "weather-showers-scattered-symbolic",
    "10n": "weather-showers-scattered-symbolic",
    "11d": "weather-storm-symbolic",
    "11n": "weather-storm-symbolic",
    "13d": "weather-snow-symbolic",
    "13n": "weather-snow-symbolic",
    "50d": "weather-fog-symbolic",
    "50n": "weather-fog-symbolic",
};

// ========== GLOBAL STATE (singleton, persists across tab switches) ==========
// Calendar state
const currentDate = Variable<Date>(new Date());

// Todo state
const todoList = Variable<TodoItem[]>([]);
const newTodoText = Variable("");
const todoIdCounter = Variable(1);

// Google Calendar state
const calendarEvents = Variable<CalendarEvent[]>([]);
const isCalendarLoading = Variable(false);
const showEventForm = Variable(false);
const selectedDateForEvents = Variable<string | null>(null); // "YYYY-MM-DD" format
const datesWithEvents = Variable<Set<string>>(new Set()); // Set of "YYYY-MM-DD" strings

// Google Calendar Token Management
const TOKEN_FILE = Global.GoogleCalendar?.tokenFile || "";

const readTokenFile = async (): Promise<any | null> => {
    try {
        const content = await execAsync(["cat", TOKEN_FILE]);
        return JSON.parse(content);
    } catch {
        return null;
    }
};

const saveTokenFile = async (data: any) => {
    const content = JSON.stringify(data, null, 2);
    await execAsync(["bash", "-c", `echo '${content}' > ${TOKEN_FILE}`]);
};

const refreshAccessToken = async (): Promise<string | null> => {
    const tokenData = await readTokenFile();
    if (!tokenData?.refresh_token) return null;

    try {
        const response = await execAsync([
            "curl",
            "-s",
            "-X",
            "POST",
            "https://oauth2.googleapis.com/token",
            "-H",
            "Content-Type: application/x-www-form-urlencoded",
            "-d",
            `client_id=${tokenData.client_id}`,
            "-d",
            `client_secret=${tokenData.client_secret}`,
            "-d",
            `refresh_token=${tokenData.refresh_token}`,
            "-d",
            "grant_type=refresh_token",
        ]);

        const result = JSON.parse(response);
        if (result.access_token) {
            const expiresAt = Math.floor(Date.now() / 1000) + result.expires_in;
            await saveTokenFile({
                ...tokenData,
                access_token: result.access_token,
                expires_at: expiresAt,
            });
            return result.access_token;
        }
    } catch (e) {
        console.error("Failed to refresh token:", e);
    }
    return null;
};

const getAccessToken = async (): Promise<string | null> => {
    const tokenData = await readTokenFile();
    if (!tokenData) return null;

    const now = Math.floor(Date.now() / 1000);
    if (tokenData.expires_at && now >= tokenData.expires_at - 60) {
        return await refreshAccessToken();
    }
    return tokenData.access_token;
};

// Fetch events from Google Calendar
const fetchCalendarEvents = async () => {
    if (isCalendarLoading.get()) return;
    isCalendarLoading.set(true);

    try {
        const token = await getAccessToken();
        if (!token) {
            console.error("No valid Google Calendar token");
            isCalendarLoading.set(false);
            return;
        }

        const now = new Date();
        // Start from beginning of today (00:00:00)
        const startOfDay = new Date(
            now.getFullYear(),
            now.getMonth(),
            now.getDate()
        );
        const timeMin = startOfDay.toISOString();
        const timeMax = new Date(
            now.getTime() + 30 * 24 * 60 * 60 * 1000
        ).toISOString();

        const response = await execAsync([
            "curl",
            "-s",
            "-H",
            `Authorization: Bearer ${token}`,
            `https://www.googleapis.com/calendar/v3/calendars/primary/events?timeMin=${encodeURIComponent(
                timeMin
            )}&timeMax=${encodeURIComponent(
                timeMax
            )}&singleEvents=true&orderBy=startTime&maxResults=50`,
        ]);

        const result = JSON.parse(response);
        if (result.items) {
            calendarEvents.set(result.items);

            // Extract dates with events for calendar highlighting
            const dates = new Set<string>();
            for (const event of result.items) {
                const dateStr = event.start.date || event.start.dateTime;
                if (dateStr) {
                    // Extract YYYY-MM-DD
                    const d = new Date(dateStr);
                    const key = `${d.getFullYear()}-${String(
                        d.getMonth() + 1
                    ).padStart(2, "0")}-${String(d.getDate()).padStart(
                        2,
                        "0"
                    )}`;
                    dates.add(key);
                }
            }
            datesWithEvents.set(dates);

            // Trigger calendar re-render by updating currentDate
            currentDate.set(new Date(currentDate.get()));
        }
    } catch (e) {
        console.error("Failed to fetch calendar events:", e);
    }
    isCalendarLoading.set(false);
};

// Create event on Google Calendar
const createCalendarEvent = async (form: EventForm): Promise<boolean> => {
    const token = await getAccessToken();
    if (!token) return false;

    try {
        // Parse DD/MM/YYYY to YYYY-MM-DD for API
        const dateParts = form.date.split("/");
        const isoDate =
            dateParts.length === 3
                ? `${dateParts[2]}-${dateParts[1]}-${dateParts[0]}`
                : form.date;

        let eventData: any = {
            summary: form.title,
        };

        if (form.allDay) {
            eventData.start = { date: isoDate };
            const endDate = new Date(isoDate);
            endDate.setDate(endDate.getDate() + 1);
            eventData.end = { date: endDate.toISOString().split("T")[0] };
        } else {
            eventData.start = {
                dateTime: `${isoDate}T${form.startTime}:00+07:00`,
            };
            eventData.end = {
                dateTime: `${isoDate}T${form.endTime}:00+07:00`,
            };
        }

        if (form.recurrence !== "none") {
            const recurrenceMap: { [key: string]: string } = {
                daily: "RRULE:FREQ=DAILY",
                weekly: "RRULE:FREQ=WEEKLY",
                monthly: "RRULE:FREQ=MONTHLY",
                yearly: "RRULE:FREQ=YEARLY",
            };
            eventData.recurrence = [recurrenceMap[form.recurrence]];
        }

        const response = await execAsync([
            "curl",
            "-s",
            "-X",
            "POST",
            "https://www.googleapis.com/calendar/v3/calendars/primary/events",
            "-H",
            `Authorization: Bearer ${token}`,
            "-H",
            "Content-Type: application/json",
            "-d",
            JSON.stringify(eventData),
        ]);

        const result = JSON.parse(response);
        return !!result.id;
    } catch (e) {
        console.error("Failed to create event:", e);
        return false;
    }
};

// Delete event from Google Calendar
const deleteCalendarEvent = async (eventId: string): Promise<boolean> => {
    const token = await getAccessToken();
    if (!token) return false;

    try {
        await execAsync([
            "curl",
            "-s",
            "-X",
            "DELETE",
            "-H",
            `Authorization: Bearer ${token}`,
            `https://www.googleapis.com/calendar/v3/calendars/primary/events/${eventId}`,
        ]);
        return true;
    } catch {
        return false;
    }
};

// Weather state
const weatherData = Variable<WeatherData>({
    temperature: 0,
    feelsLike: 0,
    tempMax: 0,
    tempMin: 0,
    condition: "Loading...",
    icon: "weather-few-clouds-symbolic",
    humidity: 0,
    city: "Hanoi",
    country: "VN",
    daily: [],
});
const isWeatherLoading = Variable(false);
let weatherTimerId: number | null = null;
let weatherInitialized = false;

// ========== LUNAR CALENDAR ALGORITHM (Ho Ngoc Duc) ==========
const PI = Math.PI;

// Convert Julian Day Number to date
const jdToDate = (jd: number): [number, number, number] => {
    const a = jd + 32044;
    const b = Math.floor((4 * a + 3) / 146097);
    const c = a - Math.floor((146097 * b) / 4);
    const d = Math.floor((4 * c + 3) / 1461);
    const e = c - Math.floor((1461 * d) / 4);
    const m = Math.floor((5 * e + 2) / 153);
    const day = e - Math.floor((153 * m + 2) / 5) + 1;
    const month = m + 3 - 12 * Math.floor(m / 10);
    const year = 100 * b + d - 4800 + Math.floor(m / 10);
    return [day, month, year];
};

// Convert date to Julian Day Number
const dateToJd = (day: number, month: number, year: number): number => {
    const a = Math.floor((14 - month) / 12);
    const y = year + 4800 - a;
    const m = month + 12 * a - 3;
    const jd =
        day +
        Math.floor((153 * m + 2) / 5) +
        365 * y +
        Math.floor(y / 4) -
        Math.floor(y / 100) +
        Math.floor(y / 400) -
        32045;
    return jd;
};

// Get new moon day
const getNewMoonDay = (k: number, timeZone: number): number => {
    const T = k / 1236.85;
    const T2 = T * T;
    const T3 = T2 * T;
    const dr = PI / 180;
    let Jd1 =
        2415020.75933 + 29.53058868 * k + 0.0001178 * T2 - 0.000000155 * T3;
    Jd1 = Jd1 + 0.00033 * Math.sin((166.56 + 132.87 * T - 0.009173 * T2) * dr);
    const M = 359.2242 + 29.10535608 * k - 0.0000333 * T2 - 0.00000347 * T3;
    const Mpr = 306.0253 + 385.81691806 * k + 0.0107306 * T2 + 0.00001236 * T3;
    const F = 21.2964 + 390.67050646 * k - 0.0016528 * T2 - 0.00000239 * T3;
    let C1 =
        (0.1734 - 0.000393 * T) * Math.sin(M * dr) +
        0.0021 * Math.sin(2 * dr * M);
    C1 = C1 - 0.4068 * Math.sin(Mpr * dr) + 0.0161 * Math.sin(dr * 2 * Mpr);
    C1 = C1 - 0.0004 * Math.sin(dr * 3 * Mpr);
    C1 = C1 + 0.0104 * Math.sin(dr * 2 * F) - 0.0051 * Math.sin(dr * (M + Mpr));
    C1 =
        C1 -
        0.0074 * Math.sin(dr * (M - Mpr)) +
        0.0004 * Math.sin(dr * (2 * F + M));
    C1 =
        C1 -
        0.0004 * Math.sin(dr * (2 * F - M)) -
        0.0006 * Math.sin(dr * (2 * F + Mpr));
    C1 =
        C1 +
        0.001 * Math.sin(dr * (2 * F - Mpr)) +
        0.0005 * Math.sin(dr * (2 * Mpr + M));
    let deltat: number;
    if (T < -11) {
        deltat =
            0.001 +
            0.000839 * T +
            0.0002261 * T2 -
            0.00000845 * T3 -
            0.000000081 * T * T3;
    } else {
        deltat = -0.000278 + 0.000265 * T + 0.000262 * T2;
    }
    const JdNew = Jd1 + C1 - deltat;
    return Math.floor(JdNew + 0.5 + timeZone / 24);
};

// Get sun longitude
const getSunLongitude = (jdn: number, timeZone: number): number => {
    const T = (jdn - 2451545.5 - timeZone / 24) / 36525;
    const T2 = T * T;
    const dr = PI / 180;
    const M = 357.5291 + 35999.0503 * T - 0.0001559 * T2 - 0.00000048 * T * T2;
    const L0 = 280.46645 + 36000.76983 * T + 0.0003032 * T2;
    let DL = (1.9146 - 0.004817 * T - 0.000014 * T2) * Math.sin(dr * M);
    DL =
        DL +
        (0.019993 - 0.000101 * T) * Math.sin(dr * 2 * M) +
        0.00029 * Math.sin(dr * 3 * M);
    let L = L0 + DL;
    L = L * dr;
    L = L - PI * 2 * Math.floor(L / (PI * 2));
    return Math.floor((L / PI) * 6);
};

// Get lunar month 11
const getLunarMonth11 = (yy: number, timeZone: number): number => {
    const off = dateToJd(31, 12, yy) - 2415021;
    const k = Math.floor(off / 29.530588853);
    let nm = getNewMoonDay(k, timeZone);
    const sunLong = getSunLongitude(nm, timeZone);
    if (sunLong >= 9) {
        nm = getNewMoonDay(k - 1, timeZone);
    }
    return nm;
};

// Get leap month offset
const getLeapMonthOffset = (a11: number, timeZone: number): number => {
    const k = Math.floor((a11 - 2415021.076998695) / 29.530588853 + 0.5);
    let last: number;
    let i = 1;
    let arc = getSunLongitude(getNewMoonDay(k + i, timeZone), timeZone);
    do {
        last = arc;
        i++;
        arc = getSunLongitude(getNewMoonDay(k + i, timeZone), timeZone);
    } while (arc !== last && i < 14);
    return i - 1;
};

// Convert solar date to lunar date
interface LunarDate {
    day: number;
    month: number;
    year: number;
    leap: boolean;
}

const solarToLunar = (
    dd: number,
    mm: number,
    yy: number,
    timeZone: number = 7
): LunarDate => {
    const dayNumber = dateToJd(dd, mm, yy);
    const k = Math.floor((dayNumber - 2415021.076998695) / 29.530588853);
    let monthStart = getNewMoonDay(k + 1, timeZone);
    if (monthStart > dayNumber) {
        monthStart = getNewMoonDay(k, timeZone);
    }
    let a11 = getLunarMonth11(yy, timeZone);
    let b11 = a11;
    let lunarYear: number;
    if (a11 >= monthStart) {
        lunarYear = yy;
        a11 = getLunarMonth11(yy - 1, timeZone);
    } else {
        lunarYear = yy + 1;
        b11 = getLunarMonth11(yy + 1, timeZone);
    }
    const lunarDay = dayNumber - monthStart + 1;
    const diff = Math.floor((monthStart - a11) / 29);
    let lunarLeap = false;
    let lunarMonth = diff + 11;
    if (b11 - a11 > 365) {
        const leapMonthDiff = getLeapMonthOffset(a11, timeZone);
        if (diff >= leapMonthDiff) {
            lunarMonth = diff + 10;
            if (diff === leapMonthDiff) {
                lunarLeap = true;
            }
        }
    }
    if (lunarMonth > 12) {
        lunarMonth = lunarMonth - 12;
    }
    if (lunarMonth >= 11 && diff < 4) {
        lunarYear -= 1;
    }
    return {
        day: lunarDay,
        month: lunarMonth,
        year: lunarYear,
        leap: lunarLeap,
    };
};

// Helper functions
const getDaysInMonth = (date: Date) => {
    return new Date(date.getFullYear(), date.getMonth() + 1, 0).getDate();
};

const getFirstDayOfMonth = (date: Date) => {
    return new Date(date.getFullYear(), date.getMonth(), 1).getDay();
};

const isToday = (date: Date) => {
    const today = new Date();
    return (
        date.getDate() === today.getDate() &&
        date.getMonth() === today.getMonth() &&
        date.getFullYear() === today.getFullYear()
    );
};

// Calendar component
// Calendar helper functions (outside component to avoid recreation)
const MONTH_NAMES = [
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
];
const WEEK_DAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

// Helper to create date key
const makeDateKey = (d: number, m: number, y: number): string =>
    `${y}-${String(m + 1).padStart(2, "0")}-${String(d).padStart(2, "0")}`;

// Get lunar date for display
const getLunarDisplay = (d: number, m: number, y: number): string => {
    const lunar = solarToLunar(d, m + 1, y);
    return lunar.day === 1
        ? `${lunar.day}/${lunar.month}`
        : lunar.day.toString();
};

// Check if lunar day is special (1st or 15th of lunar month)
const isLunarSpecial = (d: number, m: number, y: number): boolean => {
    const lunar = solarToLunar(d, m + 1, y);
    return lunar.day === 1 || lunar.day === 15;
};

// Fetch calendar events on AGS startup (module load)
fetchCalendarEvents();

const Calendar = () => {
    const navigateMonth = (direction: number) => {
        const current = currentDate.get();
        currentDate.set(
            new Date(current.getFullYear(), current.getMonth() + direction, 1)
        );
    };

    // Handle day click to show events
    const handleDayClick = (d: number, m: number, y: number) => {
        const key = makeDateKey(d, m, y);
        if (datesWithEvents.get().has(key)) {
            selectedDateForEvents.set(key);
        }
    };

    return (
        <box vertical className="calendar-container" spacing={10}>
            {bind(selectedDateForEvents).as((selected) =>
                selected ? (
                    <DayEventsView />
                ) : (
                    <box vertical spacing={10}>
                        {/* Calendar Header */}
                        <centerbox className="calendar-header">
                            <button
                                onClicked={() => navigateMonth(-1)}
                                cursor="hand1"
                                halign={Gtk.Align.START}
                            >
                                <icon icon="pan-start-symbolic" />
                            </button>

                            <label
                                label={bind(currentDate).as(
                                    (date) =>
                                        `${
                                            MONTH_NAMES[date.getMonth()]
                                        } ${date.getFullYear()}`
                                )}
                                className="calendar-solar-header"
                            />

                            <button
                                onClicked={() => navigateMonth(1)}
                                cursor="hand1"
                                halign={Gtk.Align.END}
                            >
                                <icon icon="pan-end-symbolic" />
                            </button>
                        </centerbox>

                        {/* Week days header */}
                        <box className="calendar-weekdays" spacing={15}>
                            {WEEK_DAYS.map((day, idx) => (
                                <box hexpand halign={Gtk.Align.CENTER}>
                                    <label
                                        label={day}
                                        className={idx >= 5 ? "weekend" : ""}
                                    />
                                </box>
                            ))}
                        </box>

                        {/* Calendar grid */}
                        <box vertical className="calendar-grid" spacing={5}>
                            {bind(currentDate).as((date) => {
                                const year = date.getFullYear();
                                const month = date.getMonth();
                                const daysInMonth = getDaysInMonth(date);
                                const jsFirst = getFirstDayOfMonth(date);
                                const firstDay = (jsFirst + 6) % 7;
                                const prevMonthLastDay = new Date(
                                    year,
                                    month,
                                    0
                                ).getDate();

                                // Get events set
                                const eventsSet = datesWithEvents.get();
                                const hasEvents = (
                                    d: number,
                                    m: number,
                                    y: number
                                ) => eventsSet.has(makeDateKey(d, m, y));

                                const totalCells = 42;
                                const cells: JSX.Element[] = [];

                                // Leading days from previous month
                                for (let i = 0; i < firstDay; i++) {
                                    const dayNum =
                                        prevMonthLastDay - firstDay + 1 + i;
                                    const dow = i % 7;
                                    const isWeekend = dow === 5 || dow === 6;
                                    const prevMonth =
                                        month === 0 ? 11 : month - 1;
                                    const prevYear =
                                        month === 0 ? year - 1 : year;
                                    const prevDayHasEvents = hasEvents(
                                        dayNum,
                                        prevMonth,
                                        prevYear
                                    );

                                    cells.push(
                                        <box hexpand halign={Gtk.Align.CENTER}>
                                            <button
                                                className={`calendar-day not-in ${
                                                    isWeekend ? "weekend" : ""
                                                } ${
                                                    prevDayHasEvents
                                                        ? "has-events"
                                                        : ""
                                                }`}
                                                cursor={
                                                    prevDayHasEvents
                                                        ? "hand1"
                                                        : "default"
                                                }
                                                onClicked={() =>
                                                    handleDayClick(
                                                        dayNum,
                                                        prevMonth,
                                                        prevYear
                                                    )
                                                }
                                            >
                                                <box vertical>
                                                    <label
                                                        label={dayNum.toString()}
                                                        className={`solar-day ${
                                                            prevDayHasEvents
                                                                ? "has-events"
                                                                : ""
                                                        }`}
                                                    />
                                                    <label
                                                        label={getLunarDisplay(
                                                            dayNum,
                                                            prevMonth,
                                                            prevYear
                                                        )}
                                                        className="lunar-day"
                                                    />
                                                </box>
                                            </button>
                                        </box>
                                    );
                                }

                                // Current month days
                                for (let d = 1; d <= daysInMonth; d++) {
                                    const idx = firstDay + d - 1;
                                    const dow = idx % 7;
                                    const isWeekend = dow === 5 || dow === 6;
                                    const dayDate = new Date(year, month, d);
                                    const isTodayDay = isToday(dayDate);
                                    const isSpecial = isLunarSpecial(
                                        d,
                                        month,
                                        year
                                    );
                                    const dayHasEvents = hasEvents(
                                        d,
                                        month,
                                        year
                                    );

                                    cells.push(
                                        <box hexpand halign={Gtk.Align.CENTER}>
                                            <button
                                                className={`calendar-day ${
                                                    isWeekend ? "weekend" : ""
                                                } ${
                                                    isTodayDay ? "today" : ""
                                                } ${
                                                    isSpecial
                                                        ? "lunar-special"
                                                        : ""
                                                } ${
                                                    dayHasEvents
                                                        ? "has-events"
                                                        : ""
                                                }`}
                                                cursor={
                                                    dayHasEvents
                                                        ? "hand1"
                                                        : "default"
                                                }
                                                onClicked={() =>
                                                    handleDayClick(
                                                        d,
                                                        month,
                                                        year
                                                    )
                                                }
                                            >
                                                <box vertical>
                                                    <label
                                                        label={d.toString()}
                                                        className={`solar-day ${
                                                            dayHasEvents
                                                                ? "has-events"
                                                                : ""
                                                        }`}
                                                    />
                                                    <label
                                                        label={getLunarDisplay(
                                                            d,
                                                            month,
                                                            year
                                                        )}
                                                        className={`lunar-day ${
                                                            isSpecial
                                                                ? "special"
                                                                : ""
                                                        }`}
                                                    />
                                                </box>
                                            </button>
                                        </box>
                                    );
                                }

                                // Trailing days from next month
                                const trailing = totalCells - cells.length;
                                for (let i = 1; i <= trailing; i++) {
                                    const idx = firstDay + daysInMonth + i - 1;
                                    const dow = idx % 7;
                                    const isWeekend = dow === 5 || dow === 6;
                                    const nextMonth =
                                        month === 11 ? 0 : month + 1;
                                    const nextYear =
                                        month === 11 ? year + 1 : year;
                                    const nextDayHasEvents = hasEvents(
                                        i,
                                        nextMonth,
                                        nextYear
                                    );

                                    cells.push(
                                        <box hexpand halign={Gtk.Align.CENTER}>
                                            <button
                                                className={`calendar-day not-in ${
                                                    isWeekend ? "weekend" : ""
                                                } ${
                                                    nextDayHasEvents
                                                        ? "has-events"
                                                        : ""
                                                }`}
                                                cursor={
                                                    nextDayHasEvents
                                                        ? "hand1"
                                                        : "default"
                                                }
                                                onClicked={() =>
                                                    handleDayClick(
                                                        i,
                                                        nextMonth,
                                                        nextYear
                                                    )
                                                }
                                            >
                                                <box vertical spacing={2}>
                                                    <label
                                                        label={i.toString()}
                                                        className={`solar-day ${
                                                            nextDayHasEvents
                                                                ? "has-events"
                                                                : ""
                                                        }`}
                                                    />
                                                    <label
                                                        label={getLunarDisplay(
                                                            i,
                                                            nextMonth,
                                                            nextYear
                                                        )}
                                                        className="lunar-day"
                                                    />
                                                </box>
                                            </button>
                                        </box>
                                    );
                                }

                                // Group into rows
                                const weeks: JSX.Element[] = [];
                                for (let w = 0; w < 6; w++) {
                                    weeks.push(
                                        <box
                                            className="calendar-week"
                                            spacing={15}
                                        >
                                            {cells.slice(w * 7, (w + 1) * 7)}
                                        </box>
                                    );
                                }

                                return weeks;
                            })}
                        </box>
                    </box>
                )
            )}
        </box>
    );
};

// Format event time for display
const formatEventTime = (event: CalendarEvent): string => {
    if (event.start.date) {
        return "All day";
    }
    if (event.start.dateTime) {
        const start = new Date(event.start.dateTime);
        const end = event.end.dateTime ? new Date(event.end.dateTime) : null;
        const startStr = start.toLocaleTimeString("en-US", {
            hour: "2-digit",
            minute: "2-digit",
            hour12: false,
        });
        const endStr = end
            ? end.toLocaleTimeString("en-US", {
                  hour: "2-digit",
                  minute: "2-digit",
                  hour12: false,
              })
            : "";
        return end ? `${startStr} - ${endStr}` : startStr;
    }
    return "";
};

// Helper to get date key from event
const getEventDateKey = (event: CalendarEvent): string | null => {
    const dateStr = event.start.date || event.start.dateTime;
    if (!dateStr) return null;
    const d = new Date(dateStr);
    return makeDateKey(d.getDate(), d.getMonth(), d.getFullYear());
};

// Update datesWithEvents from current calendarEvents
const updateDatesWithEvents = () => {
    const events = calendarEvents.get();
    const dates = new Set<string>();
    for (const event of events) {
        const key = getEventDateKey(event);
        if (key) dates.add(key);
    }
    datesWithEvents.set(dates);
    // Trigger calendar re-render
    currentDate.set(new Date(currentDate.get()));
};

// Component to show events for a selected day
const DayEventsView = () => {
    const selectedDate = selectedDateForEvents.get();
    if (!selectedDate) return <box />;

    // Parse selected date for display
    const [year, month, day] = selectedDate.split("-").map(Number);
    const formattedDate = `${String(day).padStart(2, "0")}/${String(
        month
    ).padStart(2, "0")}/${year}`;

    const handleDelete = async (eventId: string) => {
        // Optimistic update
        const currentEvents = calendarEvents.get();
        const newEvents = currentEvents.filter((e) => e.id !== eventId);
        calendarEvents.set(newEvents);

        // Update calendar highlighting
        updateDatesWithEvents();

        // Check remaining events for this day
        const remaining = newEvents.filter(
            (e) => getEventDateKey(e) === selectedDate
        );

        // If no more events for this day, close the view
        if (remaining.length === 0) {
            selectedDateForEvents.set(null);
        }

        // Delete from API
        const success = await deleteCalendarEvent(eventId);
        if (!success) {
            calendarEvents.set(currentEvents);
            updateDatesWithEvents(); // Restore highlighting
        }
    };

    const handleBack = () => {
        selectedDateForEvents.set(null);
    };

    return (
        <box vertical className="day-events-view" spacing={15}>
            {/* Header */}
            <centerbox className="day-events-header">
                <button
                    halign={Gtk.Align.START}
                    cursor="hand1"
                    onClicked={handleBack}
                >
                    <icon icon="go-previous-symbolic" />
                </button>
                <label
                    label={`Events on ${formattedDate}`}
                    className="day-events-title"
                />
                <box />
            </centerbox>

            {/* Events list - bind to calendarEvents for reactivity */}
            <scrollable
                vscrollbarPolicy={Gtk.PolicyType.AUTOMATIC}
                hscrollbarPolicy={Gtk.PolicyType.NEVER}
                className="day-events-scroll"
                vexpand
            >
                <box vertical spacing={10}>
                    {bind(calendarEvents).as((events) => {
                        const eventsForDay = events.filter(
                            (e) => getEventDateKey(e) === selectedDate
                        );

                        if (eventsForDay.length === 0) {
                            return (
                                <box
                                    halign={Gtk.Align.CENTER}
                                    valign={Gtk.Align.CENTER}
                                    vexpand
                                >
                                    <label
                                        label="No events"
                                        className="empty-text"
                                    />
                                </box>
                            );
                        }

                        return eventsForDay.map((event: CalendarEvent) => (
                            <box className="day-event-item" spacing={12}>
                                <box vertical hexpand spacing={4}>
                                    <label
                                        label={event.summary || "No title"}
                                        className="day-event-title"
                                        xalign={0}
                                        wrap
                                    />
                                    <label
                                        label={formatEventTime(event)}
                                        className="day-event-time"
                                        xalign={0}
                                    />
                                </box>
                                <button
                                    className="day-event-delete"
                                    onClicked={() => handleDelete(event.id)}
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

const formatEventDate = (event: CalendarEvent): string => {
    const dateStr = event.start.date || event.start.dateTime;
    if (!dateStr) return "";
    const date = new Date(dateStr);
    const day = String(date.getDate()).padStart(2, "0");
    const month = String(date.getMonth() + 1).padStart(2, "0");
    const year = date.getFullYear();
    return `${day}/${month}/${year}`;
};

// Event Form Component - Simple like WiFi password entry
const EventFormDialog = () => {
    // Get today's date in DD/MM/YYYY format
    const today = new Date();
    const todayStr = `${String(today.getDate()).padStart(2, "0")}/${String(
        today.getMonth() + 1
    ).padStart(2, "0")}/${today.getFullYear()}`;

    // Local state - no complex bindings
    const titleText = Variable("");
    const dateText = Variable(todayStr);
    const startTimeText = Variable("09:00");
    const endTimeText = Variable("10:00");
    const isSubmitting = Variable(false);

    const cleanup = () => {
        titleText.drop();
        dateText.drop();
        startTimeText.drop();
        endTimeText.drop();
        isSubmitting.drop();
    };

    const handleSubmit = async () => {
        const title = titleText.get().trim();
        if (!title) return;

        isSubmitting.set(true);

        const form: EventForm = {
            title,
            date: dateText.get(),
            startTime: startTimeText.get(),
            endTime: endTimeText.get(),
            allDay: false,
            recurrence: "none",
        };

        const success = await createCalendarEvent(form);
        if (success) {
            showEventForm.set(false);
            titleText.set("");
            dateText.set(todayStr);
            startTimeText.set("09:00");
            endTimeText.set("10:00");
            await fetchCalendarEvents();
        }
        isSubmitting.set(false);
    };

    const handleCancel = () => {
        showEventForm.set(false);
        titleText.set("");
    };

    return (
        <box vertical className="event-form" spacing={15} onDestroy={cleanup}>
            {/* Header */}
            <centerbox className="event-form-header">
                <label
                    label="Add Event"
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

            {/* Title input */}
            <box vertical spacing={20} className="event-form-body">
                <box vertical spacing={5}>
                    <label label="Title" xalign={0} />
                    <entry
                        className="event-form-entry"
                        placeholderText="Enter event title..."
                        onChanged={(self: Gtk.Entry) =>
                            titleText.set(self.text)
                        }
                        onActivate={handleSubmit}
                    />
                </box>

                {/* Date input */}
                <box vertical spacing={5}>
                    <label label="Date" xalign={0} />
                    <entry
                        className="event-form-entry"
                        text={`${String(today.getDate()).padStart(
                            2,
                            "0"
                        )}/${String(today.getMonth() + 1).padStart(
                            2,
                            "0"
                        )}/${today.getFullYear()}`}
                        placeholderText="DD/MM/YYYY"
                        onChanged={(self: Gtk.Entry) => dateText.set(self.text)}
                    />
                </box>

                {/* Time inputs */}
                <box spacing={10} className="event-form-time-inputs">
                    <box vertical spacing={5} hexpand>
                        <label label="Start" xalign={0} />
                        <entry
                            className="event-form-entry"
                            text="09:00"
                            onChanged={(self: Gtk.Entry) =>
                                startTimeText.set(self.text)
                            }
                        />
                    </box>
                    <box vertical spacing={5} hexpand>
                        <label label="End" xalign={0} />
                        <entry
                            className="event-form-entry"
                            text="10:00"
                            onChanged={(self: Gtk.Entry) =>
                                endTimeText.set(self.text)
                            }
                        />
                    </box>
                </box>

                {/* Submit button */}
                <box halign={Gtk.Align.END}>
                    <button
                        className="event-form-submit"
                        cursor="hand1"
                        onClicked={handleSubmit}
                    >
                        {bind(isSubmitting).as((submitting) =>
                            submitting ? (
                                <label label="Saving..." />
                            ) : (
                                <label label="Save" />
                            )
                        )}
                    </button>
                </box>
            </box>
        </box>
    );
};

// Todo component with Google Calendar integration
const Todo = () => {
    const handleDelete = async (eventId: string) => {
        // Optimistic update - remove from UI immediately
        const currentEvents = calendarEvents.get();
        calendarEvents.set(currentEvents.filter((e) => e.id !== eventId));

        // Update calendar highlighting
        updateDatesWithEvents();

        // Delete from API in background
        const success = await deleteCalendarEvent(eventId);
        if (!success) {
            // Restore if failed
            calendarEvents.set(currentEvents);
            updateDatesWithEvents();
        }
    };

    return (
        <box vertical className="todo-container" spacing={15}>
            {/* Toggle between form and list view */}
            {bind(showEventForm).as((show) =>
                show ? (
                    <EventFormDialog />
                ) : (
                    <box vertical spacing={8}>
                        {/* Header with buttons */}
                        <box className="todo-header" spacing={8}>
                            <label
                                label="Events"
                                className="todo-title"
                                hexpand
                                xalign={0}
                            />
                            <button
                                className="todo-reload-button"
                                onClicked={() => fetchCalendarEvents()}
                                cursor="hand1"
                            >
                                <icon icon="view-refresh-symbolic" />
                            </button>
                            <button
                                className="todo-add-button"
                                onClicked={() => showEventForm.set(true)}
                                cursor="hand1"
                            >
                                <icon icon="list-add-symbolic" />
                            </button>
                        </box>

                        {/* Events list */}
                        <scrollable
                            vscrollbarPolicy={Gtk.PolicyType.AUTOMATIC}
                            hscrollbarPolicy={Gtk.PolicyType.NEVER}
                            className="todo-scroll"
                            vexpand
                        >
                            <box vertical className="todo-list" spacing={15}>
                                {bind(calendarEvents).as((events) => {
                                    if (events.length === 0) {
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
                                                    icon="x-office-calendar-symbolic"
                                                    className="todo-empty-icon"
                                                />
                                                <label
                                                    label="No events"
                                                    className="todo-empty-text"
                                                />
                                            </box>
                                        );
                                    }

                                    return events.map((event) => (
                                        <box className="todo-item">
                                            <box vertical hexpand spacing={8}>
                                                <label
                                                    label={
                                                        event.summary ||
                                                        "No title"
                                                    }
                                                    className="todo-text"
                                                    xalign={0}
                                                    wrap
                                                />
                                                <box spacing={10}>
                                                    <label
                                                        label={formatEventDate(
                                                            event
                                                        )}
                                                        className="event-date"
                                                        xalign={0}
                                                    />
                                                    <label
                                                        label={formatEventTime(
                                                            event
                                                        )}
                                                        className="event-time"
                                                        xalign={0}
                                                    />
                                                </box>
                                            </box>

                                            <button
                                                className="todo-delete"
                                                onClicked={() =>
                                                    handleDelete(event.id)
                                                }
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
                )
            )}
        </box>
    );
};

// Get day name from timestamp
const getDayName = (timestamp: number): string => {
    const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    const date = new Date(timestamp * 1000);
    return days[date.getDay()];
};

// Weather API URLs (computed once)
const WEATHER_FORECAST_URL = `https://api.openweathermap.org/data/3.0/onecall?lat=${WEATHER_CONFIG.lat}&lon=${WEATHER_CONFIG.lon}&appid=${WEATHER_CONFIG.apiKey}&units=${WEATHER_CONFIG.units}&exclude=minutely,hourly,alerts`;
const WEATHER_LOCATION_URL = `https://api.openweathermap.org/geo/1.0/reverse?lat=${WEATHER_CONFIG.lat}&lon=${WEATHER_CONFIG.lon}&limit=1&appid=${WEATHER_CONFIG.apiKey}`;

// Fetch weather data (global function, not recreated per component)
const fetchWeather = async () => {
    if (isWeatherLoading.get()) return; // Prevent concurrent fetches

    isWeatherLoading.set(true);
    try {
        const weatherResponse = await execAsync([
            "curl",
            "-s",
            "--show-error",
            "-X",
            "GET",
            WEATHER_FORECAST_URL,
        ]);

        if (weatherResponse.includes("Could not resolve host")) {
            console.error("Weather: Network error");
            isWeatherLoading.set(false);
            return;
        }

        const result = JSON.parse(weatherResponse);
        if (result.current) {
            const current = result.current;
            const weather = current.weather[0];
            const iconCode = weather.icon || "02d";

            // Fetch location data
            let city = "Hanoi";
            let country = "VN";
            try {
                const locationResponse = await execAsync([
                    "curl",
                    "-s",
                    "-X",
                    "GET",
                    WEATHER_LOCATION_URL,
                ]);
                const locationResult = JSON.parse(locationResponse);
                if (locationResult[0]) {
                    city = locationResult[0].name || city;
                    country = locationResult[0].country || country;
                }
            } catch (e) {
                console.error("Weather: Location fetch failed");
            }

            // Get today's max/min from daily[0]
            let todayMax = 0;
            let todayMin = 0;
            if (result.daily && result.daily[0]) {
                todayMax = Math.round(result.daily[0].temp.max);
                todayMin = Math.round(result.daily[0].temp.min);
            }

            // Parse daily forecast (skip today, get next 6 days)
            const dailyForecast: DailyForecast[] = [];
            if (result.daily && Array.isArray(result.daily)) {
                for (let i = 1; i < Math.min(7, result.daily.length); i++) {
                    const day = result.daily[i];
                    const dayIcon = day.weather?.[0]?.icon || "02d";
                    dailyForecast.push({
                        day: getDayName(day.dt),
                        icon:
                            WEATHER_ICON_MAP[dayIcon] ||
                            "weather-few-clouds-symbolic",
                        tempMax: Math.round(day.temp.max),
                        tempMin: Math.round(day.temp.min),
                    });
                }
            }

            weatherData.set({
                temperature: Math.round(current.temp),
                feelsLike: Math.round(current.feels_like),
                tempMax: todayMax,
                tempMin: todayMin,
                condition: weather.description
                    .split(" ")
                    .map((w: string) => w.charAt(0).toUpperCase() + w.slice(1))
                    .join(" "),
                icon:
                    WEATHER_ICON_MAP[iconCode] || "weather-few-clouds-symbolic",
                humidity: current.humidity,
                city,
                country: country.toUpperCase(),
                daily: dailyForecast,
            });
        }
    } catch (e) {
        console.error("Weather: Fetch failed", e);
    }
    isWeatherLoading.set(false);
};

// Initialize weather timer (called once globally)
const initWeatherTimer = () => {
    if (weatherInitialized) return;
    weatherInitialized = true;

    // Initial fetch
    fetchWeather();

    // Set up periodic updates
    weatherTimerId = GLib.timeout_add(
        GLib.PRIORITY_DEFAULT,
        WEATHER_CONFIG.updateInterval,
        () => {
            fetchWeather();
            return true;
        }
    );
};

// Weather component (UI only, no state management)
const Weather = () => {
    // Initialize weather on first render (singleton pattern)
    initWeatherTimer();

    return (
        <box vertical className="weather-container" vexpand>
            <box className="weather-main" spacing={15} vexpand>
                {/* Left side: City, Icon, Description */}
                <box
                    vertical
                    className="weather-left"
                    spacing={10}
                    valign={Gtk.Align.START}
                >
                    <box spacing={10}>
                        <icon
                            icon="location-svg"
                            className="weather-location-icon"
                        />
                        <label
                            label={bind(weatherData).as(
                                (data) => `${data.city}, ${data.country}`
                            )}
                            className="weather-location"
                        />
                    </box>
                    <icon
                        icon={bind(weatherData).as((data) => data.icon)}
                        className="weather-icon-large"
                    />
                    <label
                        label={bind(weatherData).as((data) => data.condition)}
                        className="weather-condition"
                        xalign={0}
                    />
                </box>

                {/* Right side: Temperature, Max/Min, Feels Like, Humidity */}
                <box
                    vertical
                    className="weather-right"
                    valign={Gtk.Align.START}
                    halign={Gtk.Align.END}
                    hexpand
                    spacing={10}
                >
                    <label
                        label={bind(weatherData).as(
                            (data) => `${data.temperature}°C`
                        )}
                        className="weather-temp-large"
                        xalign={1}
                    />
                    <label
                        label={bind(weatherData).as(
                            (data) => `${data.tempMax}° / ${data.tempMin}°`
                        )}
                        className="weather-temp-range"
                        xalign={1}
                    />
                    <label
                        label={bind(weatherData).as(
                            (data) => `Feels Like ${data.feelsLike}°C`
                        )}
                        className="weather-feels-like"
                        xalign={1}
                    />
                    <label
                        label={bind(weatherData).as(
                            (data) => `Humidity: ${data.humidity}%`
                        )}
                        className="weather-humidity"
                        xalign={1}
                    />
                </box>
            </box>

            {/* 6-day forecast row */}
            <box
                className="weather-forecast"
                homogeneous
                valign={Gtk.Align.END}
            >
                {bind(weatherData).as((data) =>
                    data.daily.map((day) => (
                        <box
                            vertical
                            className="weather-forecast-day"
                            halign={Gtk.Align.CENTER}
                            spacing={8}
                        >
                            <label
                                label={day.day}
                                className="forecast-day-name"
                            />
                            <icon icon={day.icon} className="forecast-icon" />
                            <label
                                label={`${day.tempMax}° / ${day.tempMin}°`}
                                className="forecast-temp"
                            />
                        </box>
                    ))
                )}
            </box>
        </box>
    );
};

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

// Button config (static)
const buttons = [
    {
        label: "Calendar",
        activeIcon: "calendar-active",
        inactiveIcon: "calendar-i",
    },
    { label: "To Do", activeIcon: "todo-active", inactiveIcon: "todo" },
    {
        label: "Weather",
        activeIcon: "weather-few-clouds-symbolic",
        inactiveIcon: "weather-few-clouds-symbolic",
    },
];

// Global cleanup function - only called when app exits
// Note: Control window is hidden/shown, NOT destroyed/recreated
// So this cleanup only runs on app shutdown
const cleanupAll = () => {
    // Clear weather timer first
    if (weatherTimerId) {
        GLib.source_remove(weatherTimerId);
        weatherTimerId = null;
    }
    weatherInitialized = false;

    // Drop all Variables (safe to call even if already dropped)
    try {
        currentDate.drop();
        todoList.drop();
        newTodoText.drop();
        todoIdCounter.drop();
        weatherData.drop();
        isWeatherLoading.drop();
        buttonSelected.drop();
        content.drop();
        // Google Calendar variables
        calendarEvents.drop();
        isCalendarLoading.drop();
        showEventForm.drop();
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
                {bind(content)}
            </box>
        </box>
    );
};
