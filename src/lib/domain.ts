export type TimerMode = 'Pomodoro' | 'Countdown' | 'Stopwatch' | 'Study until';
export type SessionKind = 'Focused study' | 'Short break' | 'Long break';
export type SessionStatus = 'running' | 'paused' | 'completed';
export type Appearance = 'Dark' | 'Light' | 'System';
export type Accent = 'Orange' | 'Blue' | 'Mint' | 'Violet';

export interface StudySettings {
  weekdayGoals: Record<number, number>;
  focusMinutes: number;
  shortBreakMinutes: number;
  longBreakMinutes: number;
  sessionsBeforeLongBreak: number;
  appearance: Appearance;
  accent: Accent;
  completionSound: boolean;
  breakReminders: boolean;
  goalNotifications: boolean;
  quickDurations: number[];
  compactTimer: boolean;
}
export interface StudyInterval { id: string; start: number; end: number | null }
export interface StudySession {
  id: string; start: number; end: number | null; duration: number; kind: SessionKind;
  status: SessionStatus; intervals: StudyInterval[]; modifiedAt: number;
}
export interface StudyData {
  schemaVersion: number;
  updatedAt: number;
  settingsUpdatedAt: number;
  timerUpdatedAt: number;
  resetAt: number;
  deletedSessionIDs: string[];
  settings: StudySettings;
  sessions: StudySession[];
  activeMode: TimerMode;
  remaining: number;
  elapsed: number;
  stopwatchStartedAt: number | null;
  selectedYear: number;
  completedFocusSessions: number;
  completedFocusSessionIDs: string[];
  selectedKind: SessionKind;
  timerBaseDuration: number;
  targetDate: number;
  timerRunning: boolean;
  timerStartedAt: number | null;
  timerDeadline: number | null;
  timerSessionID: string | null;
  notifiedGoalDays: string[];
}

export const defaultSettings = (): StudySettings => ({
  weekdayGoals: { 1: 60, 2: 60, 3: 60, 4: 60, 5: 60, 6: 45, 7: 30 },
  focusMinutes: 25, shortBreakMinutes: 5, longBreakMinutes: 15, sessionsBeforeLongBreak: 4,
  appearance: 'Dark', accent: 'Orange', completionSound: true, breakReminders: true, goalNotifications: true,
  quickDurations: [25, 50, 90], compactTimer: false,
});
export const freshData = (now = Date.now()): StudyData => ({
  schemaVersion: 3, updatedAt: now, settingsUpdatedAt: now, timerUpdatedAt: now, resetAt: 0,
  deletedSessionIDs: [], settings: defaultSettings(), sessions: [], activeMode: 'Pomodoro', remaining: 1500,
  elapsed: 0, stopwatchStartedAt: null, selectedYear: new Date(now).getFullYear(), completedFocusSessions: 0,
  completedFocusSessionIDs: [], selectedKind: 'Focused study', timerBaseDuration: 1500, targetDate: nextTarget(17, 0, now),
  timerRunning: false, timerStartedAt: null, timerDeadline: null, timerSessionID: null, notifiedGoalDays: [],
});
const UUID = () => globalThis.crypto?.randomUUID?.() ?? `ember-${Date.now()}-${Math.random().toString(16).slice(2)}`;
const clamp = (n: number, min: number, max: number) => Math.min(max, Math.max(min, n));
const safeClamp = (value: unknown, fallback: number, min: number, max: number) => { const n=Number(value ?? fallback); return clamp(Number.isFinite(n)?n:fallback,min,max); };
const dayStart = (stamp: number) => { const d = new Date(stamp); d.setHours(0, 0, 0, 0); return d.getTime(); };
const dayEnd = (stamp: number) => { const d = new Date(dayStart(stamp)); d.setDate(d.getDate() + 1); return d.getTime(); };
export function nextTarget(hour: number, minute: number, now = Date.now()) {
  const target = new Date(now); target.setHours(hour, minute, 0, 0);
  if (target.getTime() <= now) target.setDate(target.getDate() + 1);
  return target.getTime();
}
export function normalizeData(input: unknown, now = Date.now()): StudyData {
  if (!input || typeof input !== 'object' || Array.isArray(input)) throw new Error('Ember backup must contain a JSON object.');
  const d = input as Record<string, unknown>;
  if (d.schemaVersion !== undefined && Number(d.schemaVersion) > 3) throw new Error('This Ember backup was created by a newer app version.');
  if (d.sessions !== undefined && !Array.isArray(d.sessions)) throw new Error('Ember backup sessions must be a list.');
  if (d.settings !== undefined && (!d.settings || typeof d.settings !== 'object' || Array.isArray(d.settings))) throw new Error('Ember backup settings are invalid.');
  const base = freshData(now);
  const s = d.settings && typeof d.settings === 'object' ? d.settings as Record<string, unknown> : {};
  const defaults = defaultSettings();
  const goals = s.weekdayGoals && typeof s.weekdayGoals === 'object' ? s.weekdayGoals as Record<string, unknown> : {};
  const quick = Array.isArray(s.quickDurations) ? s.quickDurations.map(Number).filter(n => Number.isFinite(n) && n >= 1 && n <= 720) : defaults.quickDurations;
  const settings: StudySettings = {
    weekdayGoals: Object.fromEntries(Array.from({ length: 7 }, (_, i) => { const k = i + 1; const n=Number(goals[k] ?? defaults.weekdayGoals[k]); return [k, clamp(Number.isFinite(n)?n:defaults.weekdayGoals[k], 0, 1440)]; })),
    focusMinutes: safeClamp(s.focusMinutes, defaults.focusMinutes, 1, 180),
    shortBreakMinutes: safeClamp(s.shortBreakMinutes, defaults.shortBreakMinutes, 1, 60),
    longBreakMinutes: safeClamp(s.longBreakMinutes, defaults.longBreakMinutes, 1, 90),
    sessionsBeforeLongBreak: safeClamp(s.sessionsBeforeLongBreak, defaults.sessionsBeforeLongBreak, 2, 8),
    appearance: ['Dark','Light','System'].includes(String(s.appearance)) ? s.appearance as Appearance : defaults.appearance,
    accent: ['Orange','Blue','Mint','Violet'].includes(String(s.accent)) ? s.accent as Accent : defaults.accent,
    completionSound: s.completionSound !== false, breakReminders: s.breakReminders !== false,
    goalNotifications: s.goalNotifications !== false, quickDurations: [...new Set(quick)].slice(0, 3), compactTimer: Boolean(s.compactTimer),
  };
  const parseDate = (value: unknown, fallback: number | null = null): number | null => {
    if (typeof value === 'number' && Number.isFinite(value)) return value > 1e12 ? value : value * 1000 + 978307200000;
    if (typeof value === 'string' && value) { const parsed = Date.parse(value); if (Number.isFinite(parsed)) return parsed; }
    return fallback;
  };
  const array = (key: string): unknown[] => Array.isArray(d[key]) ? d[key] as unknown[] : [];
  const sessions: StudySession[] = array('sessions').flatMap(raw => {
    if (!raw || typeof raw !== 'object') return [];
    const r = raw as Record<string, unknown>;
    const start = parseDate(r.start); if (start === null) return [];
    const end = parseDate(r.end);
    const status: SessionStatus = ['running','paused','completed'].includes(String(r.status)) ? r.status as SessionStatus : (end === null ? 'running' : 'completed');
    if (r.intervals !== undefined && !Array.isArray(r.intervals)) throw new Error('Ember backup session intervals must be a list.');
    const intervals: StudyInterval[] = (Array.isArray(r.intervals) ? r.intervals : []).flatMap(rawInterval => {
      if (!rawInterval || typeof rawInterval !== 'object') return [];
      const i = rawInterval as Record<string, unknown>; const istart = parseDate(i.start); if (istart === null) return [];
      return [{ id: String(i.id || UUID()), start: istart, end: parseDate(i.end) }];
    });
    if (!intervals.length && Number(r.duration) > 0 && end !== null) intervals.push({ id: UUID(), start, end });
    const kind = ['Focused study','Short break','Long break'].includes(String(r.kind)) ? r.kind as SessionKind : 'Focused study';
    return [{ id: String(r.id || UUID()), start, end, duration: Math.max(0, Number(r.duration) || 0), kind, status, intervals, modifiedAt: parseDate(r.modifiedAt, end ?? start) ?? start }];
  });
  const mode = ['Pomodoro','Countdown','Stopwatch','Study until'].includes(String(d.activeMode)) ? d.activeMode as TimerMode : 'Pomodoro';
  const timerRunning = d.timerRunning === true && parseDate(d.timerStartedAt) !== null;
  return {
    ...base, ...d, schemaVersion: 3, settings, settingsUpdatedAt: parseDate(d.settingsUpdatedAt, parseDate(d.updatedAt, now)!)!,
    timerUpdatedAt: parseDate(d.timerUpdatedAt, parseDate(d.updatedAt, now)!)!, updatedAt: parseDate(d.updatedAt, now)!, resetAt: parseDate(d.resetAt, 0)!,
    deletedSessionIDs: array('deletedSessionIDs').map(String), sessions, activeMode: mode,
    remaining: Math.max(0, Number(d.remaining ?? base.remaining)), elapsed: Math.max(0, Number(d.elapsed ?? 0)),
    stopwatchStartedAt: parseDate(d.stopwatchStartedAt), selectedYear: Number(d.selectedYear ?? base.selectedYear),
    completedFocusSessions: Math.max(0, Number(d.completedFocusSessions ?? 0)), completedFocusSessionIDs: array('completedFocusSessionIDs').map(String),
    selectedKind: ['Focused study','Short break','Long break'].includes(String(d.selectedKind)) ? d.selectedKind as SessionKind : 'Focused study',
    timerBaseDuration: Math.max(1, Number(d.timerBaseDuration ?? base.timerBaseDuration)), targetDate: parseDate(d.targetDate, base.targetDate)!,
    timerRunning, timerStartedAt: timerRunning ? parseDate(d.timerStartedAt) : null, timerDeadline: timerRunning ? parseDate(d.timerDeadline) : null,
    timerSessionID: typeof d.timerSessionID === 'string' ? d.timerSessionID : null, notifiedGoalDays: array('notifiedGoalDays').map(String),
  };
}
// Backup files encode dates as seconds since 2001-01-01 so backups created by
// earlier versions of Ember remain importable; normalizeData accepts both encodings.
export function encodeBackupJSON(data: StudyData) {
  const date = (stamp: number | null) => stamp === null ? null : (stamp - 978307200000) / 1000;
  return JSON.stringify({ ...data, updatedAt: date(data.updatedAt), settingsUpdatedAt: date(data.settingsUpdatedAt), timerUpdatedAt: date(data.timerUpdatedAt), resetAt: date(data.resetAt), targetDate: date(data.targetDate), stopwatchStartedAt: date(data.stopwatchStartedAt), timerStartedAt: date(data.timerStartedAt), timerDeadline: date(data.timerDeadline), sessions: data.sessions.map(s => ({ ...s, start: date(s.start), end: date(s.end), modifiedAt: date(s.modifiedAt), intervals: s.intervals.map(i => ({ ...i, start: date(i.start), end: date(i.end) })) })) }, null, 2);
}
export function mergeSessions(current: StudySession[], incoming: StudySession[]) {
  const map = new Map(current.map(s => [s.id, s]));
  for (const other of incoming) {
    const old = map.get(other.id); if (!old) { map.set(other.id, other); continue; }
    const newest = old.modifiedAt >= other.modifiedAt ? old : other;
    const intervals = new Map<string, StudyInterval>();
    for (const i of [...old.intervals, ...other.intervals]) {
      const previous = intervals.get(i.id);
      if (!previous) intervals.set(i.id, i);
      else { const preferred = newest.intervals.find(x => x.id === i.id) ?? i; intervals.set(i.id, { ...preferred, start: Math.min(previous.start, i.start) }); }
    }
    const completed = old.status === 'completed' || other.status === 'completed';
    const end = completed ? Math.max(old.end ?? 0, other.end ?? 0) : newest.status === 'running' ? null : newest.end;
    const mergedIntervals = [...intervals.values()].map(i => completed && i.end === null ? { ...i, end } : i).sort((a,b) => a.start-b.start);
    map.set(old.id, { ...newest, start: Math.min(old.start, other.start), modifiedAt: Math.max(old.modifiedAt, other.modifiedAt), status: completed ? 'completed' : newest.status, end, intervals: mergedIntervals, duration: Math.max(old.duration, other.duration, mergedIntervals.reduce((sum,i) => sum + Math.max(0,(i.end ?? Date.now())-i.start),0)) });
  }
  return [...map.values()].sort((a,b) => a.start-b.start || a.id.localeCompare(b.id));
}
export function mergeData(local: StudyData, remote: StudyData): StudyData {
  if (local.resetAt !== remote.resetAt) {
    const reset = local.resetAt > remote.resetAt ? local : remote; const older = reset === local ? remote : local;
    const merged = { ...reset, settings: remote.settingsUpdatedAt > local.settingsUpdatedAt ? remote.settings : local.settings,
      settingsUpdatedAt: Math.max(local.settingsUpdatedAt,remote.settingsUpdatedAt), deletedSessionIDs: [...new Set([...reset.deletedSessionIDs,...older.deletedSessionIDs,...older.sessions.filter(s=>s.start<=reset.resetAt).map(s=>s.id)])] };
    const deleted = new Set(merged.deletedSessionIDs);
    merged.sessions = mergeSessions(reset.sessions, older.sessions.filter(s=>s.start>reset.resetAt&&!deleted.has(s.id))).filter(s=>s.start>reset.resetAt&&!deleted.has(s.id));
    merged.updatedAt = Math.max(local.updatedAt,remote.updatedAt); return merged;
  }
  const newer = remote.timerUpdatedAt > local.timerUpdatedAt ? remote : local;
  const deleted = new Set([...local.deletedSessionIDs,...remote.deletedSessionIDs]);
  return { ...local, ...newer, settings: remote.settingsUpdatedAt > local.settingsUpdatedAt ? remote.settings : local.settings,
    settingsUpdatedAt: Math.max(local.settingsUpdatedAt,remote.settingsUpdatedAt), deletedSessionIDs:[...deleted],
    sessions: mergeSessions(local.sessions,remote.sessions).filter(s=>!deleted.has(s.id)),
    completedFocusSessionIDs:[...new Set([...local.completedFocusSessionIDs,...remote.completedFocusSessionIDs])],
    completedFocusSessions:new Set([...local.completedFocusSessionIDs,...remote.completedFocusSessionIDs]).size,
    notifiedGoalDays:[...new Set([...local.notifiedGoalDays,...remote.notifiedGoalDays])], updatedAt:Math.max(local.updatedAt,remote.updatedAt) };
}
export function studySeconds(sessions: StudySession[], day: number, asOf = Date.now()) {
  const start = dayStart(day), end = dayEnd(day);
  const intervals = sessions.filter(s=>s.kind==='Focused study').flatMap(s=>s.intervals.length?s.intervals:[{id:s.id,start:s.start,end:s.end}]).map(i=>({start:Math.max(start,i.start),end:Math.min(end,i.end??asOf,asOf)})).filter(i=>i.end>i.start).sort((a,b)=>a.start-b.start);
  let total=0, endAt=-Infinity; for(const i of intervals){ if(i.start<=endAt){const extended=Math.max(endAt,i.end);total+=extended-endAt;endAt=extended;}else{total+=i.end-i.start;endAt=i.end;} } return total/1000;
}
export function studyMinutes(sessions: StudySession[], day: number, asOf = Date.now()) { return Math.floor(studySeconds(sessions,day,asOf)/60); }
export function goalFor(data: StudyData, day: number) { return data.settings.weekdayGoals[new Date(day).getDay()+1] ?? 60; }
export function mondayStart(stamp:number){const d=new Date(dayStart(stamp));d.setDate(d.getDate()-(d.getDay()+6)%7);return d.getTime();}
export function weekDates(now=Date.now()){const start=mondayStart(now);return Array.from({length:7},(_,i)=>{const d=new Date(start);d.setDate(d.getDate()+i);return d.getTime();});}
export function weeklyStats(data:StudyData,now=Date.now()){
  const start=mondayStart(now), today=dayStart(now), elapsed=Math.max(1,Math.floor((today-start)/86400000)+1);
  const daily=Array.from({length:elapsed},(_,i)=>{const d=new Date(start);d.setDate(d.getDate()+i);return studySeconds(data.sessions,d.getTime(),now);});
  let prev=0;for(let i=0;i<7;i++){const d=new Date(start);d.setDate(d.getDate()-7+i);prev+=Math.floor(studySeconds(data.sessions,d.getTime(),start)/60)*60;}
  const total=daily.reduce((n,s)=>n+Math.floor(s/60)*60,0),reached=daily.reduce((n,s,i)=>{const d=new Date(start);d.setDate(d.getDate()+i);return n+(goalFor(data,d.getTime())>0&&Math.floor(s/60)>=goalFor(data,d.getTime())?1:0);},0);
  return { totalSeconds:total,averageSeconds:total/elapsed,goalsReached:reached,elapsedDays:elapsed,previousWeekSeconds:prev,change:prev===0?(total>0?1:0):(total-prev)/prev };
}
export function daysInYear(data:StudyData,year:number){const start=new Date(year,0,1),end=new Date(year+1,0,1),days=[];for(let d=start;d<end;d.setDate(d.getDate()+1)){const stamp=d.getTime(),minutes=studyMinutes(data.sessions,stamp);const goal=goalFor(data,stamp);days.push({date:stamp,minutes,goal,ratio:goal?minutes/goal:0,reached:goal>0&&minutes>=goal});}return days;}
export const compactDuration=(minutes:number)=>{const hours=Math.floor(minutes/60),rest=minutes%60;return hours===0?`${rest}m`:rest===0?`${hours}h`:`${hours}h ${rest}m`;};
export function durationText(seconds:number,showHours=false){const total=Math.max(0,Math.floor(seconds)),hours=Math.floor(total/3600),minutes=Math.floor(total%3600/60),secs=total%60;return hours>0||showHours?[hours,minutes,secs].map(n=>String(n).padStart(2,'0')).join(':'):`${String(Math.floor(total/60)).padStart(2,'0')}:${String(secs).padStart(2,'0')}`;}
export function sessionForDay(sessions:StudySession[],day:number){const start=dayStart(day),end=dayEnd(day);return sessions.flatMap(s=>{const pieces=s.intervals.map(i=>({...i,start:Math.max(start,i.start),end:i.end===null?null:Math.min(end,i.end)})).filter(i=>(i.end??Date.now())>i.start);if(!pieces.length&&s.intervals.length===0&&dayStart(s.start)===start)return [s];if(!pieces.length)return [];const first=Math.min(...pieces.map(i=>i.start)),last=pieces.reduce((m,i)=>Math.max(m,i.end??Date.now()),0);return [{...s,start:first,end:s.status==='running'&&pieces.some(i=>i.end===null)?null:last,duration:pieces.reduce((sum,i)=>sum+Math.max(0,(i.end??Date.now())-i.start),0)}];}).sort((a,b)=>a.start-b.start);}
export const uid=UUID;
