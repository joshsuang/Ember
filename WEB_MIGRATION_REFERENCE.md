# Ember web migration reference

The Swift app remains intact in `Sources/EmberStudyApp`, `Tests/EmberStudyAppTests`, and `Ember.xcodeproj`. This reference records its screens and rules for the additive web implementation.

## Native screens and UI

- macOS: minimum 900×640, default 1120×790, hidden title bar. A 72px left navigation rail with Dashboard, Timers, Statistics, Settings; 50px top bar, centered/left-aligned scrolling page. Keyboard shortcuts Cmd-1, Cmd-2, Cmd-3, Cmd-comma. Hover/focus labels and animated rail selection; reduced-motion respected.
- Dashboard: “Good to see you” and localized date, “A fresh page”; daily-goal and compact timer cards; full 365/366-day, Monday-first heatmap with month/day labels, year navigation, Today action, level legend, current-day outline and day detail; weekly summary chart and today's session timeline.
- Timers: Pomodoro, Countdown, Stopwatch, Study until; animated circular timer; phase chips and completion count; quick starts and custom duration; local target time. Timer preference values are shown on the timer screen.
- Statistics: week total, average, goals reached, change vs prior week; week chart; annual heatmap/day detail; weekday progress toward individual goals.
- Settings: weekday goals (hours/minutes), focus/break durations and long-break cycle, Dark/Light/System, four accent colors, completion sound, break and goal notifications, three quick-duration shortcuts, unavailable compact-window indicator, sync status, destructive clear confirmation.
- Colors: initial dark background RGB (0.075,0.080,0.087), card surface (0.105,0.112,0.122), raised (0.135,0.143,0.153), primary text (0.93,0.93,0.92), secondary (0.69,0.71,0.73), muted (0.52,0.55,0.59); light equivalents in `DesignSystem.swift`. Orange accent is (1,0.43,0.20); blue, mint, violet alternatives. Native system font, 13px continuous card corners, 1px adaptive outline, compact 7–29px typography, 17–18px standard card padding (13px settings), 8px button corners.
- Existing iPhone native app has Today / Timer / Week / Settings tabs, 18px page insets and two-column summary cards; annual activity is a macOS/statistics feature. Responsive web uses these tab labels on narrow screens while retaining annual activity.

## Domain and timer rules

- v3 `PersistedStudyData`, `StudySettings`, `StudySession`, UUID sessions and interval IDs; fresh defaults: Sunday 30m, Mon–Fri 60m, Sat 45m; Pomodoro 25/5/15, long break after 4; dark/orange; sounds/reminders/goals on; quick durations 25/50/90. History begins empty.
- Session pauses close intervals; resumes append an interval to the same session. Only one running session; replacing timer closes the former session. Breaks appear in timeline, are excluded from study totals; completed focus IDs count once.
- Study is the union of focus intervals clipped to local midnight and `asOf`; intervals split at midnight; no overlapping double-counting; running intervals accrue to now; displayed minutes floor seconds.
- Weeks begin Monday with ISO-like first-week rules; elapsed days include today; weekly current and previous totals floor each day before summing. Daily goals use local weekday, require a positive goal; weekly change is `(current-previous)/previous`, or 1 if current>0 and no previous week, otherwise 0.
- Countdown is 1–720 minutes. Study-until chooses the next local occurrence of a time, rolling to tomorrow. Pomodoro completion auto-selects short break or each Nth long break, then focus after a break. Timer uses absolute wall-clock deadlines. Pause/resume retains one session and excludes idle time; reset/mode change closes without counting completed focus. Stopwatch recovers elapsed time on reload then pauses.
- Daily-goal notification is once/day only when the goal crosses from below during an active focus interval. App saves locally; cloud merge behavior in Swift has timestamp precedence, UUID dedupe, tombstones and reset-aware logic.

## Migration boundary and differences

- Web is an additive static Next.js app, suitable for Vercel export. Browser data is local to an origin/profile. Cloud sync/account was deliberately deferred by the user pending provider selection; there is no automatic Mac↔iPhone sharing and “Sync now” must not imply it.
- Explicit JSON import/export uses Swift `JSONEncoder` date epoch (seconds since 2001-01-01). Imports normalize and merge records with local sessions and settings; nothing is automatically transferred from native Application Support. Import/export completion is only reported after a user selects/downloads a file.
- Browser audio uses an oscillator after user interaction in place of native Glass/iOS system sound. Notification permission is optional. Browser timer deadline continues/reconciles when the page is inactive or reopened, but a static app cannot guarantee completion notification while closed/backgrounded without push infrastructure/service worker. Safari/iOS restrictions vary. Native CloudKit is not available in this local-first web version.
- iPhone web layout keeps the app features and adds scrollable year grid on the dashboard; this differs from native tabs' placement (annual grid remains in Statistics). Exact SwiftUI rendering cannot be identical: browser platform fonts/form controls and responsive stacking vary, so CSS matches colors, sizing, spacing, card treatment and original order as closely as practical.
- `compactTimer` was already unavailable/disabled natively and remains so. No Vercel production deployment has been authorized.
