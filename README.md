# Ember

Ember is a study timer and focus journal built as a web app with TypeScript, React and CSS (a Next.js static export). It offers Pomodoro, countdown, stopwatch and “study until” timers, a daily-goal dashboard, weekly statistics and a full-year activity heatmap. Study data is stored locally in the browser for offline use; there is no account, server or cloud service.

## Run

- **Development:** `npm install`, then `npm run dev` and open the printed URL.
- **Production build:** `npm run build` writes the static export to `out/`, which `vercel.json` publishes.
- **Checks:** `npm run typecheck` for TypeScript and `npm test` for the domain logic checks.

## Data and backup behavior

Each browser profile keeps its own study data in browser local storage. Nothing is sent anywhere, and data does not automatically sync between devices; use the JSON backup in Settings to move it manually.

- **Export** downloads an Ember JSON backup of all sessions and settings.
- **Import** merges a backup with the data already in the browser: sessions deduplicate by UUID and study intervals by UUID, intentional clears keep tombstones, settings and timer state merge by their modification timestamps, and study time counts the union of intervals so overlapping sessions are not counted twice. Only one session runs at a time, and the timer is anchored to a wall-clock deadline, so reopening Ember recalculates elapsed time from that deadline.

Backup files encode dates as seconds since 2001-01-01 — the same format earlier Ember versions used — so existing backups remain importable.

## Browser support notes

The completion sound uses a short WebAudio tone after the first user interaction, and completion/goal notifications use the browser Notification API where available; both degrade gracefully when a browser blocks or lacks them. The timer keeps correct time while the tab is inactive or reopened, but a static page cannot guarantee a completion notification while fully closed.

## Verification status

`npm test`, `npm run typecheck` and `npm run build` pass locally, and the responsive layouts have been exercised at phone and desktop widths in a browser. Notification prompts and audio playback depend on the browser and on user permission, so they are verified only where the browser allows them.
