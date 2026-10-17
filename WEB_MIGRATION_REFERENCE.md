# Ember web reference

Ember is a TypeScript/CSS web app (Next.js static export): domain logic lives in `src/lib/domain.ts`, state and persistence in `src/lib/store.ts`, and the UI in `src/components/`. This reference records its screens and rules.

## Screens and UI

- Layout: 72px left navigation rail with Dashboard, Timers, Statistics, Settings; 50px top bar, centered/left-aligned scrolling page. Keyboard shortcuts Cmd/Ctrl-1, Cmd/Ctrl-2, Cmd/Ctrl-3, Cmd/Ctrl-comma. Hover/focus labels and animated rail selection; reduced-motion respected. Narrow screens switch to a mobile layout with Today / Timer / Week / Settings bottom tabs, 18px page insets and two-column summary cards; the desktop rail and top bar are hidden.
- Dashboard: “Good to see you” and localized date, “A fresh page”; daily-goal and compact timer cards; full 365/366-day, Monday-first heatmap with month/day labels, year navigation, Today action, level legend, current-day outline and day detail; weekly summary chart and today's session timeline.
- Timers: Pomodoro, Countdown, Stopwatch, Study until; animated circular timer; phase chips and completion count; quick starts and custom duration; local target time. Timer preference values are shown on the timer screen.
- Statistics: week total, average, goals reached, change vs prior week; week chart; annual heatmap/day detail; weekday progress toward individual goals.
- Settings: weekday goals (hours/minutes), focus/break durations and long-break cycle, Dark/Light/System, four accent colors, completion sound, break and goal notifications, three quick-duration shortcuts, unavailable compact-window indicator, JSON backup export/import, destructive clear confirmation.
- Colors: dark background RGB (0.075,0.080,0.087), card surface (0.105,0.112,0.122), raised (0.135,0.143,0.153), primary text (0.93,0.93,0.92), secondary (0.69,0.71,0.73), muted (0.52,0.55,0.59); light equivalents defined in `src/components/ember.css`. Orange accent is (1,0.43,0.20); blue, mint, violet alternatives. System font stack, 13px continuous card corners, 1px adaptive outline, compact 7–29px typography, 17–18px standard card padding (13px settings), 8px button corners.

## Domain and timer rules

- v3 `StudyData`, `StudySettings`, `StudySession`, UUID sessions and interval IDs; fresh defaults: Sunday 30m, Mon–Fri 60m, Sat 45m; Pomodoro 25/5/15, long break after 4; dark/orange; sounds/reminders/goals on; quick durations 25/50/90. History begins empty.
- Session pauses close intervals; resumes append an interval to the same session. Only one running session; replacing timer closes the former session. Breaks appear in timeline, are excluded from study totals; completed focus IDs count once.
- Study is the union of focus intervals clipped to local midnight and `asOf`; intervals split at midnight; no overlapping double-counting; running intervals accrue to now; displayed minutes floor seconds.
- Weeks begin Monday with ISO-like first-week rules; elapsed days include today; weekly current and previous totals floor each day before summing. Daily goals use local weekday, require a positive goal; weekly change is `(current-previous)/previous`, or 1 if current>0 and no previous week, otherwise 0.
- Countdown is 1–720 minutes. Study-until chooses the next local occurrence of a time, rolling to tomorrow. Pomodoro completion auto-selects short break or each Nth long break, then focus after a break. Timer uses absolute wall-clock deadlines. Pause/resume retains one session and excludes idle time; reset/mode change closes without counting completed focus. Stopwatch recovers elapsed time on reload then pauses.
- Daily-goal notification is once/day only when the goal crosses from below during an active focus interval. Backups merge with timestamp precedence, UUID dedupe, tombstones and reset-aware logic.

## Web boundaries and backup format

- The app is local-first: browser data is scoped to an origin/profile, and there is no account or automatic cross-device sync by design. JSON import/export is the supported way to transfer data; nothing is automatically transferred from anywhere else.
- Explicit JSON import/export encodes dates as seconds since 2001-01-01 — unchanged so backups from earlier Ember versions remain importable; `normalizeData` also accepts millisecond epochs and ISO strings. Imports normalize and merge records with local sessions and settings. Import/export completion is only reported after a user selects/downloads a file.
- Browser audio uses an oscillator after user interaction in place of a bundled sound. Notification permission is optional. The timer deadline continues/reconciles when the page is inactive or reopened, but a static app cannot guarantee completion notification while closed/backgrounded without push infrastructure/a service worker. Browser restrictions vary.
- The mobile web layout keeps all app features and adds a scrollable year grid on the dashboard (the year grid also remains in Statistics). Exact rendering cannot be pixel-identical across platforms: browser fonts, form controls and responsive stacking vary, so CSS matches colors, sizing, spacing, card treatment and original order as closely as practical.
- `compactTimer` was already unavailable/disabled and remains so. No production deployment has been authorized.
