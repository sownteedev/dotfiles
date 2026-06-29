import { bind, Variable } from "astal";
import { Gtk } from "astal/gtk3";
import { execAsync } from "astal";
import Global from "../../../../Global";
import { showEventForm, showTodoAddForm } from "./modalState";

export interface CalendarEvent {
    id: string;
    summary: string;
    description?: string;
    location?: string;
    start: {
        dateTime?: string;
        date?: string;
    };
    end: {
        dateTime?: string;
        date?: string;
    };
    recurrence?: string[];
    calendarId?: string;
    calendarName?: string;
    calendarColor?: string;
}

export interface EventForm {
    title: string;
    date: string;
    startTime: string;
    endTime: string;
    allDay: boolean;
    recurrence: string;
    calendarId?: string;
    location?: string;
    description?: string;
}

const TOKEN_FILE = Global.GoogleCalendar?.tokenFile || "";
const CALENDAR_ID_CONFIG = Global.GoogleCalendar?.calendarId || "";

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

/** Dùng cho Google Tasks API (cùng token OAuth với Calendar). */
export { getAccessToken as getGoogleAccessToken };

const getCalendarId = (): string => {
    return CALENDAR_ID_CONFIG || "primary";
};

let allCalendarsCache: Array<{
    id: string;
    name: string;
    color: string;
    canCreate: boolean;
}> | null = null;

const clearCalendarsCache = () => {
    allCalendarsCache = null;
};

const generateColorFromId = (
    calendarId: string,
    calendarName?: string,
): string => {
    const source =
        calendarName && calendarName.toLowerCase().includes("tkb")
            ? calendarName
            : calendarId;

    let hash = 0;
    for (let i = 0; i < source.length; i++) {
        hash = source.charCodeAt(i) + ((hash << 5) - hash);
        hash = hash & hash;
    }

    const r = (Math.abs(hash) % 200) + 55;
    const g = (Math.abs(hash >> 8) % 200) + 55;
    const b = (Math.abs(hash >> 16) % 200) + 55;

    return `rgb(${r}, ${g}, ${b})`;
};

export const getAllCalendars = async (): Promise<
    Array<{ id: string; name: string; color: string; canCreate: boolean }>
> => {
    if (allCalendarsCache !== null) {
        return allCalendarsCache;
    }

    try {
        const token = await getAccessToken();
        if (!token) {
            allCalendarsCache = [
                {
                    id: "primary",
                    name: "NGUYEN THANH SON",
                    color: generateColorFromId("primary", "NGUYEN THANH SON"),
                    canCreate: true,
                },
            ];
            return allCalendarsCache;
        }

        const response = await execAsync([
            "curl",
            "-s",
            "-H",
            `Authorization: Bearer ${token}`,
            "https://www.googleapis.com/calendar/v3/users/me/calendarList",
        ]);

        const result = JSON.parse(response);
        const calendars: Array<{
            id: string;
            name: string;
            color: string;
            canCreate: boolean;
        }> = [];

        if (result.items && Array.isArray(result.items)) {
            for (const cal of result.items) {
                if (cal.accessRole && cal.accessRole !== "none") {
                    const canCreate =
                        cal.accessRole === "owner" ||
                        cal.accessRole === "writer";

                    let displayName = cal.summary || cal.id;
                    if (
                        cal.id === "primary" ||
                        (cal.summary && cal.summary.includes("@"))
                    ) {
                        displayName = "NGUYEN THANH SON";
                    }

                    const hexColor = generateColorFromId(cal.id, displayName);

                    calendars.push({
                        id: cal.id,
                        name: displayName,
                        color: hexColor,
                        canCreate: canCreate,
                    });
                }
            }
        }

        calendars.sort((a, b) => {
            if (a.id === "primary") return -1;
            if (b.id === "primary") return 1;
            return a.name.localeCompare(b.name);
        });

        if (calendars.length === 0) {
            calendars.push({
                id: "primary",
                name: "NGUYEN THANH SON",
                color: generateColorFromId("primary", "NGUYEN THANH SON"),
                canCreate: true,
            });
        }

        allCalendarsCache = calendars;
        return calendars;
    } catch (e) {
        console.error("Failed to fetch all calendars:", e);
        allCalendarsCache = [
            {
                id: "primary",
                name: "NGUYEN THANH SON",
                color: generateColorFromId("primary", "NGUYEN THANH SON"),
                canCreate: true,
            },
        ];
        return allCalendarsCache;
    }
};

const getCalendarColor = (calendarId: string | undefined): string => {
    if (!calendarId) return "#808080";

    if (allCalendarsCache) {
        const cal = allCalendarsCache.find((c) => c.id === calendarId);
        if (cal) return cal.color;
    }

    if (allCalendarsCache) {
        const cal = allCalendarsCache.find((c) => c.id === calendarId);
        if (cal) return generateColorFromId(calendarId, cal.name);
    }
    return generateColorFromId(calendarId);
};

const getCalendarName = (calendarId: string | undefined): string => {
    if (!calendarId) return "Unknown";

    if (allCalendarsCache) {
        const cal = allCalendarsCache.find((c) => c.id === calendarId);
        if (cal) return cal.name;
    }

    if (calendarId === "primary") return "NGUYEN THANH SON";
    return calendarId;
};

const fetchCalendarEventsApi = async (): Promise<CalendarEvent[]> => {
    const token = await getAccessToken();
    if (!token) {
        throw new Error("No valid Google Calendar token");
    }

    const calendars = await getAllCalendars();

    if (!calendars || calendars.length === 0) {
        throw new Error("No calendars available to fetch events from");
    }

    const allEvents: CalendarEvent[] = [];

    const now = new Date();
    const startOfDay = new Date(
        now.getFullYear(),
        now.getMonth(),
        now.getDate(),
    );
    const timeMin = startOfDay.toISOString();
    const timeMax = new Date(
        now.getTime() + 30 * 24 * 60 * 60 * 1000,
    ).toISOString();

    for (const calendar of calendars) {
        try {
            const response = await execAsync([
                "curl",
                "-s",
                "-w",
                "\nHTTP_STATUS:%{http_code}\n",
                "-H",
                `Authorization: Bearer ${token}`,
                `https://www.googleapis.com/calendar/v3/calendars/${encodeURIComponent(
                    calendar.id,
                )}/events?timeMin=${encodeURIComponent(
                    timeMin,
                )}&timeMax=${encodeURIComponent(
                    timeMax,
                )}&singleEvents=true&orderBy=startTime&maxResults=50`,
            ]);

            let httpStatus = 200;
            let body = response;

            if (response.includes("\nHTTP_STATUS:")) {
                const parts = response.split("\nHTTP_STATUS:");
                if (parts.length > 1) {
                    const statusStr = parts[1].trim();
                    const parsedStatus = parseInt(statusStr);
                    if (!isNaN(parsedStatus)) {
                        httpStatus = parsedStatus;
                    }
                    body = parts[0];
                }
            }

            if (httpStatus !== 200) {
                console.error(
                    `HTTP ${httpStatus} when fetching events from ${calendar.name} (${calendar.id})`,
                );
                if (httpStatus === 401) {
                    const newToken = await getAccessToken();
                    if (newToken && newToken !== token) {
                        continue;
                    }
                }
                continue;
            }

            body = body.trim();

            let result;
            try {
                result = JSON.parse(body);
            } catch (parseError) {
                console.error(
                    `Failed to parse JSON response from ${calendar.name}:`,
                    parseError,
                );
                continue;
            }

            if (result.error) {
                console.error(`API Error for ${calendar.name}:`, result.error);
                continue;
            }

            if (result.items && Array.isArray(result.items)) {
                const eventsWithCalendar = result.items.map((event: any) => ({
                    ...event,
                    calendarId: calendar.id,
                    calendarName: calendar.name,
                    calendarColor: calendar.color,
                }));
                allEvents.push(...eventsWithCalendar);
            }
        } catch (e) {
            console.error(
                `Failed to fetch events from ${calendar.name} (${calendar.id}):`,
                e,
            );
        }
    }

    allEvents.sort((a, b) => {
        const aTime = a.start.dateTime || a.start.date || "";
        const bTime = b.start.dateTime || b.start.date || "";
        return aTime.localeCompare(bTime);
    });

    return allEvents;
};

const createCalendarEvent = async (form: EventForm): Promise<boolean> => {
    const token = await getAccessToken();
    if (!token) return false;

    try {
        const dateParts = form.date.split("/");
        const isoDate =
            dateParts.length === 3
                ? `${dateParts[2]}-${dateParts[1]}-${dateParts[0]}`
                : form.date;

        let eventData: any = {
            summary: form.title,
        };

        if (form.location && form.location.trim() !== "") {
            eventData.location = form.location.trim();
        }

        if (form.description && form.description.trim() !== "") {
            eventData.description = form.description.trim();
        }

        if (form.allDay) {
            eventData.start = { date: isoDate };
            const endDate = new Date(isoDate);
            endDate.setDate(endDate.getDate() + 1);
            eventData.end = { date: endDate.toISOString().split("T")[0] };
        } else {
            eventData.start = {
                dateTime: `${isoDate}T${form.startTime}:00+07:00`,
                timeZone: "Asia/Ho_Chi_Minh",
            };
            eventData.end = {
                dateTime: `${isoDate}T${form.endTime}:00+07:00`,
                timeZone: "Asia/Ho_Chi_Minh",
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

        const calendarId = form.calendarId || getCalendarId();

        const response = await execAsync([
            "curl",
            "-s",
            "-X",
            "POST",
            `https://www.googleapis.com/calendar/v3/calendars/${encodeURIComponent(
                calendarId,
            )}/events`,
            "-H",
            `Authorization: Bearer ${token}`,
            "-H",
            "Content-Type: application/json",
            "-d",
            JSON.stringify(eventData),
        ]);

        const result = JSON.parse(response);
        if (result.error) {
            console.error(
                "API Error creating event:",
                JSON.stringify(result.error, null, 2),
            );
            return false;
        }
        if (!result.id) {
            console.error(
                "No ID in response:",
                JSON.stringify(result, null, 2),
            );
            return false;
        }
        console.log("Event created successfully with ID:", result.id);
        return true;
    } catch (e) {
        console.error("Failed to create event:", e);
        return false;
    }
};

const deleteCalendarEvent = async (
    eventId: string,
    calendarId?: string,
): Promise<boolean> => {
    const token = await getAccessToken();
    if (!token) return false;

    try {
        const targetCalendarId = calendarId || getCalendarId();

        await execAsync([
            "curl",
            "-s",
            "-X",
            "DELETE",
            "-H",
            `Authorization: Bearer ${token}`,
            `https://www.googleapis.com/calendar/v3/calendars/${encodeURIComponent(
                targetCalendarId,
            )}/events/${eventId}`,
        ]);
        return true;
    } catch {
        return false;
    }
};

// ========== LUNAR CALENDAR ALGORITHM (Ho Ngoc Duc) ==========
const PI = Math.PI;

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
    timeZone: number = 7,
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

const makeDateKey = (d: number, m: number, y: number): string =>
    `${y}-${String(m + 1).padStart(2, "0")}-${String(d).padStart(2, "0")}`;

const getLunarDisplay = (d: number, m: number, y: number): string => {
    const lunar = solarToLunar(d, m + 1, y);
    return lunar.day === 1
        ? `${lunar.day}/${lunar.month}`
        : lunar.day.toString();
};

const isLunarSpecial = (d: number, m: number, y: number): boolean => {
    const lunar = solarToLunar(d, m + 1, y);
    return lunar.day === 1 || lunar.day === 15;
};

export const currentDate = Variable<Date>(new Date());
export const calendarEvents = Variable<CalendarEvent[]>([]);
export const isCalendarLoading = Variable(false);
export { showEventForm } from "./modalState";
export const selectedDateForEvents = Variable<string | null>(null);
export const prefillDateForNewEvent = Variable<string | null>(null);
export const datesWithEvents = Variable<Set<string>>(new Set());

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

const formatEventDate = (event: CalendarEvent): string => {
    const dateStr = event.start.date || event.start.dateTime;
    if (!dateStr) return "";
    const date = new Date(dateStr);
    const day = String(date.getDate()).padStart(2, "0");
    const month = String(date.getMonth() + 1).padStart(2, "0");
    const year = date.getFullYear();
    return `${day}/${month}/${year}`;
};

const getEventDateKey = (event: CalendarEvent): string | null => {
    const dateStr = event.start.date || event.start.dateTime;
    if (!dateStr) return null;
    const d = new Date(dateStr);
    return makeDateKey(d.getDate(), d.getMonth(), d.getFullYear());
};

const getEventsForDate = (
    dateKey: string,
): Array<{
    calendarId: string;
    calendarName: string;
    color: string;
    count: number;
}> => {
    const events = calendarEvents.get();
    const eventsForDate = events.filter((e) => getEventDateKey(e) === dateKey);

    const calendarMap = new Map<
        string,
        {
            calendarId: string;
            calendarName: string;
            color: string;
            count: number;
        }
    >();
    for (const event of eventsForDate) {
        const calId = event.calendarId || "primary";
        const calName = event.calendarName || getCalendarName(calId);
        const calColor = event.calendarColor || getCalendarColor(calId);

        if (!calendarMap.has(calId)) {
            calendarMap.set(calId, {
                calendarId: calId,
                calendarName: calName,
                color: calColor,
                count: 0,
            });
        }
        const entry = calendarMap.get(calId)!;
        entry.count++;
    }

    return Array.from(calendarMap.values());
};

const updateDatesWithEvents = () => {
    const events = calendarEvents.get();
    const dates = new Set<string>();
    for (const event of events) {
        const key = getEventDateKey(event);
        if (key) dates.add(key);
    }
    datesWithEvents.set(dates);
    currentDate.set(new Date(currentDate.get()));
};

const fetchCalendarEvents = async () => {
    if (isCalendarLoading.get()) return;
    isCalendarLoading.set(true);

    try {
        const allEvents = await fetchCalendarEventsApi();

        calendarEvents.set(allEvents);

        const dates = new Set<string>();
        for (const event of allEvents) {
            const key = getEventDateKey(event);
            if (key) dates.add(key);
        }
        datesWithEvents.set(dates);

        currentDate.set(new Date(currentDate.get()));
    } catch (e) {
        console.error("Failed to fetch calendar events:", e);
    }
    isCalendarLoading.set(false);
};

export const reloadCalendarEvents = async (): Promise<void> => {
    await fetchCalendarEvents();
};

const EventLocationDescription = (props: {
    event: CalendarEvent;
    classNamePrefix?: string;
}) => {
    const { event, classNamePrefix = "day-event" } = props;
    return (
        <box spacing={8} vertical>
            {event.location && (
                <box spacing={6}>
                    <icon
                        icon="location-symbolic"
                        className={`${classNamePrefix}-location-icon`}
                    />
                    <label
                        label={event.location}
                        className={`${classNamePrefix}-location`}
                        xalign={0}
                    />
                </box>
            )}
            {event.description && (
                <box spacing={6}>
                    <icon
                        icon="text-x-generic-symbolic"
                        className={`${classNamePrefix}-description-icon`}
                    />
                    <label
                        label={event.description}
                        className={`${classNamePrefix}-description`}
                        xalign={0}
                        wrap
                    />
                </box>
            )}
        </box>
    );
};

const DayEventsView = () => {
    const selectedDate = selectedDateForEvents.get();
    if (!selectedDate) return <box />;

    const [year, month, day] = selectedDate.split("-").map(Number);
    const formattedDate = `${String(day).padStart(2, "0")}/${String(
        month,
    ).padStart(2, "0")}/${year}`;

    const handleDelete = async (eventId: string, calendarId?: string) => {
        const currentEvents = calendarEvents.get();
        const newEvents = currentEvents.filter((e) => e.id !== eventId);
        calendarEvents.set(newEvents);

        updateDatesWithEvents();

        const success = await deleteCalendarEvent(eventId, calendarId);
        if (!success) {
            calendarEvents.set(currentEvents);
            updateDatesWithEvents();
        }
    };

    const handleBack = () => {
        selectedDateForEvents.set(null);
    };

    const handleAddEvent = () => {
        showTodoAddForm.set(false);
        prefillDateForNewEvent.set(formattedDate);
        showEventForm.set(true);
    };

    return (
        <box vertical className="day-events-view" spacing={15}>
            <centerbox className="day-events-header">
                <box hexpand halign={Gtk.Align.START}>
                    <button cursor="hand1" onClicked={handleBack}>
                        <icon icon="go-previous-symbolic" />
                    </button>
                </box>
                <label
                    label={`Events on ${formattedDate}`}
                    className="day-events-title"
                />
                <box hexpand halign={Gtk.Align.END}>
                    <button
                        className="todo-add-button"
                        cursor="hand1"
                        onClicked={handleAddEvent}
                        tooltipText="Create event"
                    >
                        <icon icon="list-add-symbolic" />
                    </button>
                </box>
            </centerbox>

            <scrollable
                vscrollbarPolicy={Gtk.PolicyType.AUTOMATIC}
                hscrollbarPolicy={Gtk.PolicyType.NEVER}
                className="day-events-scroll"
                vexpand
            >
                <box vertical spacing={15}>
                    {bind(calendarEvents).as((events) => {
                        const eventsForDay = events.filter(
                            (e) => getEventDateKey(e) === selectedDate,
                        );

                        if (eventsForDay.length === 0) {
                            return (
                                <box
                                    className="day-events-empty"
                                    halign={Gtk.Align.CENTER}
                                    valign={Gtk.Align.CENTER}
                                    vexpand
                                    vertical
                                    spacing={10}
                                >
                                    <icon
                                        icon="x-office-calendar-symbolic"
                                        className="day-events-empty-icon"
                                    />
                                    <label
                                        label="No events"
                                        className="day-events-empty-text"
                                    />
                                </box>
                            );
                        }

                        return eventsForDay.map((event: CalendarEvent) => {
                            const calendarColor =
                                event.calendarColor ||
                                getCalendarColor(event.calendarId);
                            const calendarName =
                                event.calendarName ||
                                getCalendarName(event.calendarId);
                            return (
                                <box className="day-event-item" spacing={12}>
                                    <box vertical hexpand spacing={8}>
                                        <label
                                            label={event.summary || "No title"}
                                            className="day-event-title"
                                            xalign={0}
                                            wrap
                                        />
                                        <box spacing={10} vertical>
                                            <box spacing={10}>
                                                <label
                                                    label={formatEventTime(
                                                        event,
                                                    )}
                                                    className="day-event-time"
                                                    xalign={0}
                                                />
                                                <label
                                                    label={calendarName}
                                                    className="day-event-calendar-name"
                                                    xalign={0}
                                                    css={`
                                                        color: ${calendarColor};
                                                    `}
                                                />
                                            </box>
                                            <EventLocationDescription
                                                event={event}
                                            />
                                        </box>
                                    </box>
                                    <button
                                        className="day-event-delete"
                                        onClicked={() =>
                                            handleDelete(
                                                event.id,
                                                event.calendarId,
                                            )
                                        }
                                        cursor="hand1"
                                    >
                                        <icon icon="user-trash-symbolic" />
                                    </button>
                                </box>
                            );
                        });
                    })}
                </box>
            </scrollable>
        </box>
    );
};

export const EventFormDialog = () => {
    const today = new Date();
    const todayStr = `${String(today.getDate()).padStart(2, "0")}/${String(
        today.getMonth() + 1,
    ).padStart(2, "0")}/${today.getFullYear()}`;

    const titleText = Variable("");
    const dateText = Variable(todayStr);
    const startTimeText = Variable("09:00");
    const endTimeText = Variable("10:00");
    const isSubmitting = Variable(false);
    const selectedCalendarId = Variable<string>("");
    const locationText = Variable("");
    const descriptionText = Variable("");

    const availableCalendars = Variable<
        Array<{ id: string; name: string; color: string; canCreate: boolean }>
    >([]);

    const initCalendars = async () => {
        clearCalendarsCache();
        const allCalendars = await getAllCalendars();
        const writableCalendars = allCalendars.filter((cal) => cal.canCreate);
        availableCalendars.set(writableCalendars);
        if (writableCalendars.length > 0) {
            selectedCalendarId.set(writableCalendars[0].id);
        }
    };

    const cleanup = () => {
        titleText.drop();
        dateText.drop();
        startTimeText.drop();
        endTimeText.drop();
        isSubmitting.drop();
        selectedCalendarId.drop();
        availableCalendars.drop();
        locationText.drop();
        descriptionText.drop();
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
            calendarId: selectedCalendarId.get() || undefined,
            location: locationText.get().trim() || undefined,
            description: descriptionText.get().trim() || undefined,
        };

        const success = await createCalendarEvent(form);
        if (success) {
            showEventForm.set(false);
            titleText.set("");
            dateText.set(todayStr);
            startTimeText.set("09:00");
            endTimeText.set("10:00");
            selectedCalendarId.set(availableCalendars.get()[0]?.id || "");
            locationText.set("");
            descriptionText.set("");
            await fetchCalendarEvents();
        }
        isSubmitting.set(false);
    };

    const handleCancel = () => {
        showEventForm.set(false);
        titleText.set("");
    };

    return (
        <box
            vertical
            className="event-form"
            spacing={15}
            onDestroy={cleanup}
            setup={(self: Gtk.Widget) => {
                initCalendars();
                const prefill = prefillDateForNewEvent.get();
                if (prefill) {
                    dateText.set(prefill);
                    prefillDateForNewEvent.set(null);
                }
            }}
        >
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

            <scrollable
                vscrollbarPolicy={Gtk.PolicyType.AUTOMATIC}
                hscrollbarPolicy={Gtk.PolicyType.NEVER}
                className="event-form-scroll"
                vexpand
            >
                <box vertical spacing={20} className="event-form-body">
                    <box vertical spacing={5}>
                        <label label="Calendar" xalign={0} />
                        {bind(availableCalendars).as((calendars) => {
                            if (calendars.length === 0) {
                                return (
                                    <label
                                        label="Loading calendars..."
                                        className="event-form-entry"
                                    />
                                );
                            }
                            return (
                                <box vertical spacing={8}>
                                    {calendars.map((cal) => (
                                        <button
                                            className={bind(
                                                selectedCalendarId,
                                            ).as((selectedId) =>
                                                selectedId === cal.id
                                                    ? "calendar-select-button active"
                                                    : "calendar-select-button",
                                            )}
                                            onClicked={() =>
                                                selectedCalendarId.set(cal.id)
                                            }
                                            cursor="hand1"
                                            hexpand
                                        >
                                            <box
                                                spacing={10}
                                                className="calendar-select-content"
                                            >
                                                <box
                                                    className="calendar-color-dot"
                                                    css={`
                                                        background-color: ${cal.color};
                                                        width: 12px;
                                                        height: 12px;
                                                        border-radius: 50%;
                                                        min-width: 12px;
                                                        min-height: 12px;
                                                    `}
                                                />
                                                <label
                                                    label={cal.name}
                                                    className="calendar-select-label"
                                                    xalign={0}
                                                    hexpand
                                                />
                                            </box>
                                        </button>
                                    ))}
                                </box>
                            );
                        })}
                    </box>

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

                    <box vertical spacing={5}>
                        <label label="Date" xalign={0} />
                        <entry
                            className="event-form-entry"
                            text={bind(dateText).as((d) => d ?? "")}
                            placeholderText="DD/MM/YYYY"
                            onChanged={(self: Gtk.Entry) =>
                                dateText.set(self.text)
                            }
                        />
                    </box>

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

                    <box vertical spacing={5}>
                        <label label="Location" xalign={0} />
                        <entry
                            className="event-form-entry"
                            placeholderText="Enter location..."
                            onChanged={(self: Gtk.Entry) =>
                                locationText.set(self.text)
                            }
                        />
                    </box>

                    <box vertical spacing={5}>
                        <label label="Description" xalign={0} />
                        <entry
                            className="event-form-entry"
                            placeholderText="Enter description..."
                            onChanged={(self: Gtk.Entry) =>
                                descriptionText.set(self.text)
                            }
                        />
                    </box>

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
                                ),
                            )}
                        </button>
                    </box>
                </box>
            </scrollable>
        </box>
    );
};

export const Calendar = () => {
    // Initialize calendar events on mount
    const initCalendar = () => {
        fetchCalendarEvents();
    };

    const navigateMonth = (direction: number) => {
        const current = currentDate.get();
        currentDate.set(
            new Date(current.getFullYear(), current.getMonth() + direction, 1),
        );
    };

    const handleDayClick = (d: number, m: number, y: number) => {
        const key = makeDateKey(d, m, y);
        selectedDateForEvents.set(key);
    };

    return (
        <box
            vertical
            className="calendar-container"
            spacing={10}
            setup={initCalendar}
        >
            {bind(selectedDateForEvents).as((selected) =>
                selected ? (
                    <DayEventsView />
                ) : (
                    <box vertical spacing={10}>
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
                                        `${MONTH_NAMES[date.getMonth()]} ${date.getFullYear()}`,
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

                        <box vertical className="calendar-grid" spacing={5}>
                            {bind(currentDate).as((date) => {
                                const eventsSet = datesWithEvents.get();

                                const year = date.getFullYear();
                                const month = date.getMonth();
                                const daysInMonth = getDaysInMonth(date);
                                const jsFirst = getFirstDayOfMonth(date);
                                const firstDay = (jsFirst + 6) % 7;
                                const prevMonthLastDay = new Date(
                                    year,
                                    month,
                                    0,
                                ).getDate();

                                const hasEvents = (
                                    d: number,
                                    m: number,
                                    y: number,
                                ) => eventsSet.has(makeDateKey(d, m, y));

                                const totalCells = 42;
                                const cells: JSX.Element[] = [];

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
                                        prevYear,
                                    );
                                    const prevDateKey = makeDateKey(
                                        dayNum,
                                        prevMonth,
                                        prevYear,
                                    );
                                    const prevDayCalendars = prevDayHasEvents
                                        ? getEventsForDate(prevDateKey)
                                        : [];

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
                                                        prevYear,
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
                                                            prevYear,
                                                        )}
                                                        className="lunar-day"
                                                    />
                                                    {prevDayHasEvents && (
                                                        <box
                                                            spacing={2}
                                                            halign={
                                                                Gtk.Align.CENTER
                                                            }
                                                        >
                                                            {prevDayCalendars.map(
                                                                (cal) => (
                                                                    <box
                                                                        className="calendar-event-dot"
                                                                        css={`
                                                                            background-color: ${cal.color};
                                                                            width: 6px;
                                                                            height: 6px;
                                                                            border-radius: 50%;
                                                                        `}
                                                                        tooltipText={
                                                                            cal.calendarName
                                                                        }
                                                                    />
                                                                ),
                                                            )}
                                                        </box>
                                                    )}
                                                </box>
                                            </button>
                                        </box>,
                                    );
                                }

                                for (let d = 1; d <= daysInMonth; d++) {
                                    const idx = firstDay + d - 1;
                                    const dow = idx % 7;
                                    const isWeekend = dow === 5 || dow === 6;
                                    const dayDate = new Date(year, month, d);
                                    const isTodayDay = isToday(dayDate);
                                    const isSpecial = isLunarSpecial(
                                        d,
                                        month,
                                        year,
                                    );
                                    const dayHasEvents = hasEvents(
                                        d,
                                        month,
                                        year,
                                    );
                                    const dateKey = makeDateKey(d, month, year);
                                    const dayCalendars = dayHasEvents
                                        ? getEventsForDate(dateKey)
                                        : [];

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
                                                        year,
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
                                                            year,
                                                        )}
                                                        className={`lunar-day ${
                                                            isSpecial
                                                                ? "special"
                                                                : ""
                                                        }`}
                                                    />
                                                    {dayHasEvents && (
                                                        <box
                                                            spacing={2}
                                                            halign={
                                                                Gtk.Align.CENTER
                                                            }
                                                        >
                                                            {dayCalendars.map(
                                                                (cal) => (
                                                                    <box
                                                                        className="calendar-event-dot"
                                                                        css={`
                                                                            background-color: ${cal.color};
                                                                            width: 6px;
                                                                            height: 6px;
                                                                            border-radius: 50%;
                                                                        `}
                                                                        tooltipText={
                                                                            cal.calendarName
                                                                        }
                                                                    />
                                                                ),
                                                            )}
                                                        </box>
                                                    )}
                                                </box>
                                            </button>
                                        </box>,
                                    );
                                }

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
                                        nextYear,
                                    );
                                    const nextDateKey = makeDateKey(
                                        i,
                                        nextMonth,
                                        nextYear,
                                    );
                                    const nextDayCalendars = nextDayHasEvents
                                        ? getEventsForDate(nextDateKey)
                                        : [];

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
                                                        nextYear,
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
                                                            nextYear,
                                                        )}
                                                        className="lunar-day"
                                                    />
                                                    {nextDayHasEvents && (
                                                        <box
                                                            spacing={2}
                                                            halign={
                                                                Gtk.Align.CENTER
                                                            }
                                                        >
                                                            {nextDayCalendars.map(
                                                                (cal) => (
                                                                    <box
                                                                        className="calendar-event-dot"
                                                                        css={`
                                                                            background-color: ${cal.color};
                                                                            width: 6px;
                                                                            height: 6px;
                                                                            border-radius: 50%;
                                                                        `}
                                                                        tooltipText={
                                                                            cal.calendarName
                                                                        }
                                                                    />
                                                                ),
                                                            )}
                                                        </box>
                                                    )}
                                                </box>
                                            </button>
                                        </box>,
                                    );
                                }

                                const weeks: JSX.Element[] = [];
                                for (let w = 0; w < 6; w++) {
                                    weeks.push(
                                        <box
                                            className="calendar-week"
                                            spacing={15}
                                        >
                                            {cells.slice(w * 7, (w + 1) * 7)}
                                        </box>,
                                    );
                                }

                                return weeks;
                            })}
                        </box>
                    </box>
                ),
            )}
        </box>
    );
};
