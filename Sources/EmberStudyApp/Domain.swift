import Foundation
import SwiftUI
import Combine

// MARK: - App and preference models

enum AppSection: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard", timers = "Timers", statistics = "Statistics", settings = "Settings"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        case .timers: "timer"
        case .statistics: "chart.bar.xaxis"
        case .settings: "slider.horizontal.3"
        }
    }
}

enum TimerMode: String, CaseIterable, Identifiable, Codable {
    case pomodoro = "Pomodoro", countdown = "Countdown", stopwatch = "Stopwatch", until = "Study until"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .pomodoro: "circle.dotted.circle"
        case .countdown: "hourglass"
        case .stopwatch: "stopwatch"
        case .until: "sun.horizon"
        }
    }
}

enum SessionKind: String, Codable, CaseIterable {
    case focus = "Focused study", shortBreak = "Short break", longBreak = "Long break"
    var symbol: String { self == .focus ? "book.closed.fill" : "cup.and.saucer.fill" }
    var isStudy: Bool { self == .focus }
}

enum AppearanceChoice: String, CaseIterable, Identifiable, Codable {
    case dark = "Dark", light = "Light", system = "System"
    var id: String { rawValue }
    var colorScheme: ColorScheme? { self == .dark ? .dark : self == .light ? .light : nil }
}

enum AccentChoice: String, CaseIterable, Identifiable, Codable {
    case orange = "Orange", blue = "Blue", mint = "Mint", violet = "Violet"
    var id: String { rawValue }
    var color: Color {
        switch self {
        case .orange: Color(red: 1, green: 0.43, blue: 0.20)
        case .blue: Color(red: 0.33, green: 0.63, blue: 0.98)
        case .mint: Color(red: 0.29, green: 0.78, blue: 0.61)
        case .violet: Color(red: 0.65, green: 0.48, blue: 0.98)
        }
    }
}

struct StudySettings: Codable {
    var weekdayGoals: [Int: Int] = [1: 60, 2: 60, 3: 60, 4: 60, 5: 60, 6: 45, 7: 30]
    var focusMinutes = 25
    var shortBreakMinutes = 5
    var longBreakMinutes = 15
    var sessionsBeforeLongBreak = 4
    var appearance: AppearanceChoice = .dark
    var accent: AccentChoice = .orange
    var completionSound = true
    var breakReminders = true
    var goalNotifications = true
    var quickDurations: [Int] = [25, 50, 90]
    var compactTimer = false

    private enum CodingKeys: String, CodingKey {
        case weekdayGoals, focusMinutes, shortBreakMinutes, longBreakMinutes, sessionsBeforeLongBreak
        case appearance, accent, completionSound, breakReminders, goalNotifications, quickDurations, compactTimer
    }
    init() {}
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = StudySettings()
        weekdayGoals = try values.decodeIfPresent([Int: Int].self, forKey: .weekdayGoals) ?? defaults.weekdayGoals
        for day in 1...7 { weekdayGoals[day] = min(1440, max(0, weekdayGoals[day] ?? defaults.weekdayGoals[day] ?? 60)) }
        focusMinutes = min(180, max(1, try values.decodeIfPresent(Int.self, forKey: .focusMinutes) ?? defaults.focusMinutes))
        shortBreakMinutes = min(60, max(1, try values.decodeIfPresent(Int.self, forKey: .shortBreakMinutes) ?? defaults.shortBreakMinutes))
        longBreakMinutes = min(90, max(1, try values.decodeIfPresent(Int.self, forKey: .longBreakMinutes) ?? defaults.longBreakMinutes))
        sessionsBeforeLongBreak = min(8, max(2, try values.decodeIfPresent(Int.self, forKey: .sessionsBeforeLongBreak) ?? defaults.sessionsBeforeLongBreak))
        appearance = (try? values.decode(AppearanceChoice.self, forKey: .appearance)) ?? defaults.appearance
        accent = (try? values.decode(AccentChoice.self, forKey: .accent)) ?? defaults.accent
        completionSound = try values.decodeIfPresent(Bool.self, forKey: .completionSound) ?? defaults.completionSound
        breakReminders = try values.decodeIfPresent(Bool.self, forKey: .breakReminders) ?? defaults.breakReminders
        goalNotifications = try values.decodeIfPresent(Bool.self, forKey: .goalNotifications) ?? defaults.goalNotifications
        let durations = try values.decodeIfPresent([Int].self, forKey: .quickDurations) ?? defaults.quickDurations
        var seen = Set<Int>()
        quickDurations = durations.filter { (1...720).contains($0) && seen.insert($0).inserted }.prefix(3).map { $0 }
        compactTimer = try values.decodeIfPresent(Bool.self, forKey: .compactTimer) ?? defaults.compactTimer
    }
    func goal(for date: Date, calendar: Calendar = .current) -> Int {
        weekdayGoals[calendar.component(.weekday, from: date)] ?? 60
    }
}

// MARK: - Session accounting

enum StudySessionStatus: String, Codable {
    case running, paused, completed
}

struct StudyInterval: Identifiable, Codable, Equatable {
    var id = UUID()
    var start: Date
    var end: Date?
    func seconds(asOf date: Date = Date()) -> TimeInterval { max(0, (end ?? date).timeIntervalSince(start)) }
}

struct StudySession: Identifiable, Codable, Equatable {
    var id = UUID()
    var start: Date
    var end: Date?
    var duration: TimeInterval
    var kind: SessionKind
    var status: StudySessionStatus = .completed
    var intervals: [StudyInterval] = []
    var isRunning: Bool { status == .running }
    var isPaused: Bool { status == .paused }

    func duration(asOf date: Date = Date()) -> TimeInterval {
        intervals.isEmpty ? max(0, duration) : max(duration, intervals.reduce(0) { $0 + $1.seconds(asOf: date) })
    }

    private enum CodingKeys: String, CodingKey { case id, start, end, duration, kind, status, intervals }
    init(id: UUID = UUID(), start: Date, end: Date?, duration: TimeInterval, kind: SessionKind, status: StudySessionStatus = .completed, intervals: [StudyInterval] = []) {
        self.id = id
        self.start = start
        self.end = end
        self.duration = max(0, duration)
        self.kind = kind
        self.status = status
        self.intervals = intervals
        if self.intervals.isEmpty, duration > 0, let end, end >= start {
            self.intervals = [StudyInterval(start: start, end: end)]
        }
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        start = try values.decode(Date.self, forKey: .start)
        end = try values.decodeIfPresent(Date.self, forKey: .end)
        duration = max(0, try values.decodeIfPresent(TimeInterval.self, forKey: .duration) ?? 0)
        kind = try values.decode(SessionKind.self, forKey: .kind)
        intervals = try values.decodeIfPresent([StudyInterval].self, forKey: .intervals) ?? []
        if intervals.isEmpty, duration > 0, let end, end >= start {
            intervals = [StudyInterval(start: start, end: end)]
        }
        status = try values.decodeIfPresent(StudySessionStatus.self, forKey: .status) ?? (end == nil ? .running : .completed)
    }
}

struct StudyDay: Identifiable {
    let date: Date
    let minutes: Int
    let goal: Int
    var id: Date { date }
    var ratio: Double { goal > 0 ? Double(minutes) / Double(goal) : 0 }
    var reached: Bool { minutes >= goal && goal > 0 }
}

// MARK: - Versioned local application state

struct PersistedStudyData: Codable {
    var schemaVersion = 2
    var settings = StudySettings()
    var sessions: [StudySession] = []
    var activeMode = TimerMode.pomodoro
    var remaining = 25 * 60.0
    var elapsed = 0.0
    var selectedYear = Calendar.current.component(.year, from: Date())
    var completedFocusSessions = 0
    var selectedKind: SessionKind = .focus
    var timerBaseDuration = 25 * 60.0
    var targetDate = Date()
    var timerRunning = false
    var timerStartedAt: Date?
    var timerDeadline: Date?
    var timerSessionID: UUID?
    var notifiedGoalDays: Set<String> = []

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, settings, sessions, activeMode, remaining, elapsed, selectedYear
        case completedFocusSessions, selectedKind, timerBaseDuration, targetDate
        case timerRunning, timerStartedAt, timerDeadline, timerSessionID, notifiedGoalDays
    }
    init() {}
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        settings = try values.decodeIfPresent(StudySettings.self, forKey: .settings) ?? StudySettings()
        sessions = try values.decodeIfPresent([StudySession].self, forKey: .sessions) ?? []
        activeMode = (try? values.decode(TimerMode.self, forKey: .activeMode)) ?? .pomodoro
        remaining = max(0, try values.decodeIfPresent(TimeInterval.self, forKey: .remaining) ?? 25 * 60)
        elapsed = max(0, try values.decodeIfPresent(TimeInterval.self, forKey: .elapsed) ?? 0)
        selectedYear = try values.decodeIfPresent(Int.self, forKey: .selectedYear) ?? Calendar.current.component(.year, from: Date())
        completedFocusSessions = max(0, try values.decodeIfPresent(Int.self, forKey: .completedFocusSessions) ?? 0)
        selectedKind = (try? values.decode(SessionKind.self, forKey: .selectedKind)) ?? .focus
        timerBaseDuration = max(1, try values.decodeIfPresent(TimeInterval.self, forKey: .timerBaseDuration) ?? remaining)
        targetDate = try values.decodeIfPresent(Date.self, forKey: .targetDate) ?? Date()
        timerRunning = try values.decodeIfPresent(Bool.self, forKey: .timerRunning) ?? false
        timerStartedAt = try values.decodeIfPresent(Date.self, forKey: .timerStartedAt)
        timerDeadline = try values.decodeIfPresent(Date.self, forKey: .timerDeadline)
        timerSessionID = try values.decodeIfPresent(UUID.self, forKey: .timerSessionID)
        notifiedGoalDays = try values.decodeIfPresent(Set<String>.self, forKey: .notifiedGoalDays) ?? []
        if !timerRunning {
            for index in sessions.indices where sessions[index].isRunning {
                sessions[index].status = .paused
                sessions[index].end = sessions[index].intervals.last?.end ?? Date()
            }
        }
    }
}

@MainActor
final class StudyStore: ObservableObject {
    @Published var data: PersistedStudyData { didSet { save() } }
    @Published private(set) var persistenceError: String?
    let storageURL: URL
    private let calendar = Calendar.current
    private let encoder = JSONEncoder()
    private let defaults: UserDefaults

    init(storageDirectory: URL? = nil, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let directory = storageDirectory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Ember", isDirectory: true)
        storageURL = directory.appendingPathComponent("study-data.json")
        var loaded = false
        var loadWarning: String?
        if let raw = try? Data(contentsOf: storageURL), let decoded = try? JSONDecoder().decode(PersistedStudyData.self, from: raw) {
            var restored = decoded
            if restored.timerRunning, let id = restored.timerSessionID, restored.sessions.contains(where: { $0.id == id && $0.isRunning }) {
                for index in restored.sessions.indices where restored.sessions[index].isRunning && restored.sessions[index].id != id {
                    restored.sessions[index].status = .paused
                    restored.sessions[index].end = restored.sessions[index].intervals.last?.end ?? restored.sessions[index].start
                }
            } else {
                restored.timerRunning = false
                restored.timerStartedAt = nil
                restored.timerDeadline = nil
                restored.timerSessionID = nil
                for index in restored.sessions.indices where restored.sessions[index].isRunning {
                    restored.sessions[index].status = .paused
                    restored.sessions[index].end = restored.sessions[index].intervals.last?.end ?? restored.sessions[index].start
                }
            }
            data = restored
            loaded = true
            if restored.schemaVersion != 2 { var migrated = restored; migrated.schemaVersion = 2; data = migrated }
            else { save() }
        } else if FileManager.default.fileExists(atPath: storageURL.path) {
            let quarantine = storageURL.appendingPathExtension("invalid-\(Int(Date().timeIntervalSince1970))")
            do { try FileManager.default.copyItem(at: storageURL, to: quarantine); loadWarning = "Stored study data was invalid. A backup was kept at \(quarantine.lastPathComponent), and Ember started with empty history." }
            catch { loadWarning = "Stored study data could not be read or backed up: \(error.localizedDescription)" }
        }
        if !loaded {
            // Migrate preferences only. Seeded prototype sessions are intentionally never treated as real study history.
            var initial = PersistedStudyData()
            if let legacy = defaults.data(forKey: "ember.study.prototype.v1"),
               let old = try? JSONDecoder().decode(PersistedStudyData.self, from: legacy) {
                initial.settings = old.settings
            }
            initial.sessions = []
            initial.completedFocusSessions = 0
            data = initial
            save()
        }
        if let loadWarning { persistenceError = loadWarning }
        encoder.outputFormatting = [.sortedKeys]
        if data.schemaVersion != 2 {
            var migrated = data
            migrated.schemaVersion = 2
            data = migrated
        }
        defaults.removeObject(forKey: "ember.study.prototype.v1")
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let raw = try encoder.encode(data)
            try raw.write(to: storageURL, options: .atomic)
            persistenceError = nil
        } catch {
            persistenceError = error.localizedDescription
        }
    }

    func resetUserData() {
        data = PersistedStudyData()
        defaults.removeObject(forKey: "ember.study.prototype.v1")
    }
    func clearPersistenceError() { persistenceError = nil }

    func goal(for date: Date) -> Int { data.settings.goal(for: date, calendar: calendar) }
    func studySeconds(on date: Date, asOf now: Date = Date()) -> TimeInterval {
        data.sessions.reduce(0) { $0 + studySeconds(in: $1, during: date, calendar: calendar, asOf: now) }
    }
    func studyMinutes(on date: Date) -> Int { Int(studySeconds(on: date) / 60) }
    var todayMinutes: Int { studyMinutes(on: Date()) }
    var todayGoal: Int { goal(for: Date()) }
    var todayRemaining: Int { max(0, todayGoal - todayMinutes) }

    func sessions(on date: Date) -> [StudySession] {
        guard let range = calendar.dateInterval(of: .day, for: date) else { return [] }
        var slices: [StudySession] = []
        for session in data.sessions {
            if session.intervals.isEmpty {
                guard calendar.isDate(session.start, inSameDayAs: date) else { continue }
                slices.append(session)
                continue
            }
            for interval in session.intervals {
                let start = max(range.start, interval.start)
                let rawEnd = interval.end ?? Date()
                let end = min(range.end, rawEnd)
                guard end > start else { continue }
                let active = interval.end == nil
                let clipped = StudyInterval(id: interval.id, start: start, end: active ? nil : end)
                slices.append(StudySession(id: interval.id, start: start, end: active ? nil : end, duration: end.timeIntervalSince(start), kind: session.kind, status: active ? .running : .completed, intervals: [clipped]))
            }
        }
        return slices.sorted { $0.start < $1.start }
    }

    func days(in year: Int) -> [StudyDay] {
        guard let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let end = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) else { return [] }
        var days: [StudyDay] = []
        var date = start
        while date < end {
            days.append(StudyDay(date: date, minutes: studyMinutes(on: date), goal: goal(for: date)))
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? end
        }
        return days
    }

    var weekDates: [Date] {
        let today = calendar.startOfDay(for: Date())
        let monday = weekStart(for: today, calendar: calendar)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }
    var weekStudyMinutes: [Int] { weekDates.map(studyMinutes(on:)) }
    var weekly: WeeklyStatistics { weeklyStatistics(sessions: data.sessions, goal: goal, calendar: calendar) }
    var weekTotal: Int { Int(weekly.totalSeconds / 60) }
    var weekAverage: Int { Int(weekly.averageSeconds / 60) }
    var goalsReachedThisWeek: Int { weekly.goalsReached }
    var elapsedDaysThisWeek: Int { weekly.elapsedDays }
    var previousWeekTotal: Int { Int(weekly.previousWeekSeconds / 60) }
    var weeklyChange: Double { weekly.change }

    func beginSession(kind: SessionKind, at date: Date = Date()) -> UUID {
        closeOtherRunningSessions(at: date)
        let id = UUID()
        let interval = StudyInterval(start: date, end: nil)
        data.sessions.append(StudySession(id: id, start: date, end: nil, duration: 0, kind: kind, status: .running, intervals: [interval]))
        return id
    }
    func resumeSession(id: UUID, at date: Date = Date()) {
        closeOtherRunningSessions(except: id, at: date)
        guard let index = data.sessions.firstIndex(where: { $0.id == id }), data.sessions[index].status == .paused else { return }
        data.sessions[index].status = .running
        data.sessions[index].end = nil
        data.sessions[index].intervals.append(StudyInterval(start: date, end: nil))
    }
    func pauseSession(id: UUID, at date: Date = Date()) {
        guard let index = data.sessions.firstIndex(where: { $0.id == id }), data.sessions[index].status == .running else { return }
        closeCurrentInterval(index: index, at: date)
        data.sessions[index].status = .paused
        data.sessions[index].end = date
        data.sessions[index].duration = data.sessions[index].duration(asOf: date)
    }
    func completeSession(id: UUID?, at date: Date = Date()) {
        guard let id, let index = data.sessions.firstIndex(where: { $0.id == id }), data.sessions[index].status != .completed else { return }
        if data.sessions[index].status == .running { closeCurrentInterval(index: index, at: date) }
        data.sessions[index].status = .completed
        data.sessions[index].end = date
        data.sessions[index].duration = data.sessions[index].duration(asOf: date)
        if data.sessions[index].kind == .focus { data.completedFocusSessions += 1 }
    }
    private func closeCurrentInterval(index: Int, at date: Date) {
        guard let interval = data.sessions[index].intervals.lastIndex(where: { $0.end == nil }) else { return }
        data.sessions[index].intervals[interval].end = max(date, data.sessions[index].intervals[interval].start)
    }
    private func closeOtherRunningSessions(except id: UUID? = nil, at date: Date) {
        for index in data.sessions.indices where data.sessions[index].status == .running && data.sessions[index].id != id {
            closeCurrentInterval(index: index, at: date)
            data.sessions[index].status = .completed
            data.sessions[index].end = date
            data.sessions[index].duration = data.sessions[index].duration(asOf: date)
        }
    }
}

struct WeeklyStatistics: Equatable {
    var totalSeconds: TimeInterval
    var averageSeconds: TimeInterval
    var goalsReached: Int
    var elapsedDays: Int
    var previousWeekSeconds: TimeInterval
    var change: Double { previousWeekSeconds == 0 ? (totalSeconds > 0 ? 1 : 0) : (totalSeconds - previousWeekSeconds) / previousWeekSeconds }
}

func studySeconds(in interval: StudyInterval, during day: Date, calendar: Calendar = .current, asOf: Date = Date()) -> TimeInterval {
    guard let dayRange = calendar.dateInterval(of: .day, for: day) else { return 0 }
    let start = max(interval.start, dayRange.start)
    let end = min(interval.end ?? asOf, dayRange.end, asOf)
    return max(0, end.timeIntervalSince(start))
}

func studySeconds(in session: StudySession, during day: Date, calendar: Calendar = .current, asOf: Date = Date()) -> TimeInterval {
    guard session.kind.isStudy else { return 0 }
    if session.intervals.isEmpty {
        let end = session.end ?? asOf
        guard let dayRange = calendar.dateInterval(of: .day, for: day) else { return 0 }
        return max(0, min(end, dayRange.end, asOf).timeIntervalSince(max(session.start, dayRange.start)))
    }
    return session.intervals.reduce(0) { $0 + studySeconds(in: $1, during: day, calendar: calendar, asOf: asOf) }
}

func weekStart(for date: Date, calendar input: Calendar = .current) -> Date {
    var calendar = input
    calendar.firstWeekday = 2
    calendar.minimumDaysInFirstWeek = 4
    return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
}

func weeklyStatistics(sessions: [StudySession], goal: (Date) -> Int, now: Date = Date(), calendar input: Calendar = .current) -> WeeklyStatistics {
    var calendar = input
    calendar.firstWeekday = 2
    calendar.minimumDaysInFirstWeek = 4
    let today = calendar.startOfDay(for: now)
    let start = weekStart(for: today, calendar: calendar)
    let elapsed = max(1, min(7, (calendar.dateComponents([.day], from: start, to: today).day ?? 0) + 1))
    func total(from first: Date, days: Int, asOf: Date) -> TimeInterval {
        (0..<days).reduce(0) { sum, offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: first) else { return sum }
            return sum + sessions.reduce(0) { $0 + studySeconds(in: $1, during: date, calendar: calendar, asOf: asOf) }
        }
    }
    let current = total(from: start, days: elapsed, asOf: now)
    let previous = calendar.date(byAdding: .day, value: -7, to: start) ?? start
    let prior = total(from: previous, days: 7, asOf: start)
    let reached = (0..<elapsed).reduce(0) { count, offset in
        guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return count }
        let seconds = sessions.reduce(0) { $0 + studySeconds(in: $1, during: date, calendar: calendar, asOf: now) }
        return count + (goal(date) > 0 && seconds >= Double(goal(date)) * 60 ? 1 : 0)
    }
    return WeeklyStatistics(totalSeconds: current, averageSeconds: current / Double(elapsed), goalsReached: reached, elapsedDays: elapsed, previousWeekSeconds: prior)
}

// MARK: - Clock-based timer with wall-clock restoration

@MainActor
final class TimerEngine: ObservableObject {
    @Published private(set) var now = Date()
    @Published private(set) var isRunning: Bool
    @Published private(set) var mode: TimerMode
    @Published private(set) var remaining: TimeInterval
    @Published private(set) var elapsed: TimeInterval
    @Published private(set) var targetDate: Date
    @Published private(set) var selectedKind: SessionKind
    @Published private(set) var isComplete = false
    private var anchorDate: Date?
    private var cancellables = Set<AnyCancellable>()
    private let store: StudyStore
    private var sessionBaseDuration: TimeInterval
    private var sessionID: UUID?
    private var lastSessionSave = Date.distantPast
    private var completionHandled = false
    private var previousStudyMinutes = 0

    init(store: StudyStore) {
        self.store = store
        mode = store.data.activeMode
        remaining = store.data.remaining
        elapsed = store.data.elapsed
        targetDate = store.data.targetDate
        selectedKind = store.data.selectedKind
        sessionBaseDuration = max(1, store.data.timerBaseDuration)
        isRunning = store.data.timerRunning && store.data.timerStartedAt != nil
        anchorDate = isRunning ? store.data.timerStartedAt : nil
        sessionID = store.data.timerSessionID
        if mode == .until, targetDate <= Date(), isRunning { store.data.timerDeadline = targetDate }
        if isRunning && mode != .stopwatch && store.data.timerDeadline == nil {
            store.data.timerDeadline = Date().addingTimeInterval(remaining)
        }
        if !isRunning { anchorDate = nil }
        Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { [weak self] _ in self?.tick() }.store(in: &cancellables)
        tick()
    }

    var displayedRemaining: TimeInterval {
        guard isRunning else { return remaining }
        if mode == .until { return max(0, targetDate.timeIntervalSince(Date())) }
        if mode == .stopwatch { return 0 }
        if let deadline = store.data.timerDeadline { return max(0, deadline.timeIntervalSince(Date())) }
        return max(0, remaining - (anchorDate.map { Date().timeIntervalSince($0) } ?? 0))
    }
    var displayedElapsed: TimeInterval {
        guard isRunning else { return elapsed }
        if mode == .stopwatch { return elapsed + max(0, Date().timeIntervalSince(anchorDate ?? Date())) }
        if mode == .until { return max(0, Date().timeIntervalSince(anchorDate ?? Date())) }
        return sessionBaseDuration - displayedRemaining
    }
    var displayValue: TimeInterval { mode == .stopwatch ? displayedElapsed : displayedRemaining }
    var progress: Double {
        if mode == .stopwatch { return displayedElapsed.truncatingRemainder(dividingBy: 3600) / 3600 }
        let total = mode == .until ? max(1, targetDate.timeIntervalSince(anchorDate ?? targetDate)) : max(1, sessionBaseDuration)
        return min(1, max(0, 1 - displayedRemaining / total))
    }
    var stateLabel: String {
        if isRunning { return mode == .stopwatch ? "IN SESSION" : "FOCUSING" }
        if isComplete { return "COMPLETE" }
        if elapsed > 0 || (sessionID != nil && store.data.sessions.first(where: { $0.id == sessionID })?.isPaused == true) { return "PAUSED" }
        return "READY WHEN YOU ARE"
    }

    func select(_ newMode: TimerMode) {
        stopCurrentSession(at: Date())
        mode = newMode
        selectedKind = .focus
        elapsed = 0
        isComplete = false
        remaining = newMode == .pomodoro ? Double(store.data.settings.focusMinutes * 60) : (newMode == .countdown ? 25 * 60 : 0)
        if newMode == .until { targetDate = nextTarget(hour: Calendar.current.component(.hour, from: Date()), minute: Calendar.current.component(.minute, from: Date()), after: Date()) }
        sessionBaseDuration = newMode == .until ? max(1, targetDate.timeIntervalSinceNow) : remaining
        sessionID = nil
        persist(stoppedAt: Date())
    }

    func configureCountdown(minutes: Int) {
        stopCurrentSession(at: Date())
        mode = .countdown
        remaining = Double(min(720, max(1, minutes)) * 60)
        elapsed = 0
        sessionBaseDuration = remaining
        selectedKind = .focus
        isComplete = false
        sessionID = nil
        persist(stoppedAt: Date())
    }

    func configureTarget(_ date: Date) {
        stopCurrentSession(at: Date())
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        targetDate = nextTarget(hour: parts.hour ?? 17, minute: parts.minute ?? 0, after: Date())
        mode = .until
        selectedKind = .focus
        remaining = max(0, targetDate.timeIntervalSinceNow)
        sessionBaseDuration = max(1, remaining)
        elapsed = 0
        isComplete = false
        sessionID = nil
        persist(stoppedAt: Date())
    }

    private func nextTarget(hour: Int, minute: Int, after now: Date) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = .autoupdatingCurrent
        let components = DateComponents(hour: hour, minute: minute, second: 0)
        let today = calendar.nextDate(after: now.addingTimeInterval(-1), matching: components, matchingPolicy: .nextTime, direction: .forward) ?? now.addingTimeInterval(3600)
        return today > now ? today : (calendar.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(86_400))
    }

    func setPomodoroPhase(_ kind: SessionKind) {
        stopCurrentSession(at: Date())
        selectedKind = kind
        mode = .pomodoro
        let settings = store.data.settings
        remaining = Double((kind == .focus ? settings.focusMinutes : kind == .shortBreak ? settings.shortBreakMinutes : settings.longBreakMinutes) * 60)
        elapsed = 0
        sessionBaseDuration = remaining
        isComplete = false
        sessionID = nil
        persist(stoppedAt: Date())
    }

    func setPomodoroPhaseFromSettings() {
        guard mode == .pomodoro, !isRunning, elapsed == 0 else { return }
        let settings = store.data.settings
        remaining = Double((selectedKind == .focus ? settings.focusMinutes : selectedKind == .shortBreak ? settings.shortBreakMinutes : settings.longBreakMinutes) * 60)
        sessionBaseDuration = remaining
        persist(stoppedAt: Date())
    }

    func start() {
        guard !isRunning else { return }
        if isComplete || (mode != .stopwatch && displayedRemaining <= 0) {
            reset()
        }
        let date = Date()
        previousStudyMinutes = store.todayMinutes
        if let sessionID, store.data.sessions.contains(where: { $0.id == sessionID && $0.isPaused }) {
            store.resumeSession(id: sessionID, at: date)
        } else {
            sessionID = store.beginSession(kind: selectedKind, at: date)
        }
        isRunning = true
        isComplete = false
        completionHandled = false
        anchorDate = date
        store.data.timerRunning = true
        store.data.timerStartedAt = date
        store.data.timerSessionID = sessionID
        store.data.timerDeadline = deadline(from: date)
        now = date
        persist(stoppedAt: date)
        scheduleNotificationIfNeeded()
    }

    private func deadline(from start: Date) -> Date? {
        switch mode {
        case .stopwatch: nil
        case .until: targetDate
        case .pomodoro, .countdown: start.addingTimeInterval(remaining)
        }
    }

    func pause(save: Bool = true) {
        guard isRunning else { return }
        let date = Date()
        let left = displayedRemaining
        if mode == .stopwatch { elapsed = displayedElapsed }
        else if mode == .until { remaining = left; elapsed = max(0, sessionBaseDuration - left) }
        else { remaining = left; elapsed = sessionBaseDuration - left }
        if save, let sessionID { store.pauseSession(id: sessionID, at: date) }
        isRunning = false
        anchorDate = nil
        store.data.timerRunning = false
        store.data.timerStartedAt = nil
        store.data.timerDeadline = nil
        persist(stoppedAt: date)
        TimerNotifications.cancelTimer()
    }

    func toggle() { isRunning ? pause() : start() }

    func reset() {
        if isRunning { pause() }
        else { stopCurrentSession(at: Date()) }
        elapsed = 0
        isComplete = false
        remaining = mode == .pomodoro ? Double((selectedKind == .focus ? store.data.settings.focusMinutes : selectedKind == .shortBreak ? store.data.settings.shortBreakMinutes : store.data.settings.longBreakMinutes) * 60) : (mode == .countdown ? sessionBaseDuration : 0)
        if mode == .until { remaining = max(0, targetDate.timeIntervalSinceNow) }
        sessionBaseDuration = mode == .until ? max(1, remaining) : remaining
        sessionID = nil
        persist(stoppedAt: Date())
    }

    func quickStart(minutes: Int) { configureCountdown(minutes: minutes); start() }

    func resetUserData() {
        if isRunning { pause() }
        TimerNotifications.cancelTimer()
        store.resetUserData()
        mode = .pomodoro
        selectedKind = .focus
        elapsed = 0
        remaining = Double(store.data.settings.focusMinutes * 60)
        sessionBaseDuration = remaining
        sessionID = nil
        isRunning = false
        isComplete = false
        targetDate = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date()
        persist(stoppedAt: Date())
    }

    private func stopCurrentSession(at date: Date) {
        if isRunning, let sessionID { store.completeSession(id: sessionID, at: deadlineReached(at: date) ?? date) }
        else if let sessionID, store.data.sessions.first(where: { $0.id == sessionID })?.isPaused == true { store.completeSession(id: sessionID, at: date) }
        isRunning = false
        anchorDate = nil
        store.data.timerRunning = false
        store.data.timerStartedAt = nil
        store.data.timerDeadline = nil
        TimerNotifications.cancelTimer()
    }

    private func deadlineReached(at date: Date) -> Date? {
        guard mode != .stopwatch else { return nil }
        let deadline = mode == .until ? targetDate : store.data.timerDeadline
        return deadline.flatMap { $0 <= date ? $0 : nil }
    }

    private func tick() {
        now = Date()
        guard isRunning else { return }
        if mode != .stopwatch && displayedRemaining <= 0 {
            completeTimer(at: deadlineReached(at: now) ?? now)
            return
        }
        if now.timeIntervalSince(lastSessionSave) >= 5 {
            persist(stoppedAt: now)
            lastSessionSave = now
        }
        checkGoalReached()
    }

    private func completeTimer(at date: Date) {
        guard !completionHandled else { return }
        completionHandled = true
        let completedMode = mode
        let completedKind = selectedKind
        if let sessionID { store.completeSession(id: sessionID, at: date) }
        isRunning = false
        anchorDate = nil
        store.data.timerRunning = false
        store.data.timerStartedAt = nil
        store.data.timerDeadline = nil
        elapsed = sessionBaseDuration
        remaining = 0
        isComplete = true
        if store.data.settings.completionSound { TimerNotifications.playCompletionSound() }
        if completedKind == .focus { checkGoalReached() }
        if completedMode == .pomodoro {
            if completedKind == .focus {
                let interval = max(2, store.data.settings.sessionsBeforeLongBreak)
                setPomodoroPhase(store.data.completedFocusSessions % interval == 0 ? .longBreak : .shortBreak)
            } else {
                setPomodoroPhase(.focus)
            }
        } else {
            sessionID = nil
            persist(stoppedAt: date)
        }
        if store.data.settings.breakReminders { TimerNotifications.postCompletion(kind: completedKind, mode: completedMode) }
    }

    private func checkGoalReached() {
        guard store.data.settings.goalNotifications, selectedKind == .focus else { return }
        let today = Calendar.current.startOfDay(for: Date())
        let key = ISO8601DateFormatter().string(from: today)
        let target = store.goal(for: today)
        guard target > 0, store.todayMinutes >= target, !store.data.notifiedGoalDays.contains(key), previousStudyMinutes < target else { return }
        store.data.notifiedGoalDays.insert(key)
        TimerNotifications.postGoalReached()
    }

    private func scheduleNotificationIfNeeded() {
        guard store.data.settings.breakReminders, let deadline = store.data.timerDeadline else { return }
        TimerNotifications.scheduleCompletion(at: deadline, kind: selectedKind, mode: mode, sound: store.data.settings.completionSound)
    }

    private func persist(stoppedAt date: Date) {
        var snapshot = store.data
        snapshot.schemaVersion = 2
        snapshot.activeMode = mode
        snapshot.remaining = isRunning ? displayedRemaining : remaining
        snapshot.elapsed = isRunning ? displayedElapsed : elapsed
        snapshot.selectedKind = selectedKind
        snapshot.targetDate = targetDate
        snapshot.timerBaseDuration = max(1, sessionBaseDuration)
        snapshot.timerRunning = isRunning
        snapshot.timerStartedAt = isRunning ? anchorDate : nil
        snapshot.timerDeadline = isRunning ? deadline(from: anchorDate ?? date) : nil
        snapshot.timerSessionID = sessionID
        store.data = snapshot
    }
}

func durationText(_ seconds: TimeInterval, showHours: Bool = false) -> String {
    let total = max(0, Int(seconds.rounded(.down)))
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let secs = total % 60
    if hours > 0 || showHours { return String(format: "%02d:%02d:%02d", hours, minutes, secs) }
    return String(format: "%02d:%02d", total / 60, secs)
}

func compactDuration(_ minutes: Int) -> String {
    let hours = minutes / 60
    let remainder = minutes % 60
    if hours == 0 { return "\(remainder)m" }
    return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
}
