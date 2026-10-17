import Foundation

@main
@MainActor
enum StudyLogicTests {
    private static var assertions = 0

    static func main() throws {
        try testStudyIntervalsSplitAtMidnightAndExcludeBreaks()
        try testPauseResumeAndOverlappingSessionsCountOnce()
        try testWeeklyStatisticsUseMondayWeekExcludeBreaksAndRespectGoals()
        try testOverlappingStudySessionsAreUnioned()
        try testCloudMergeDeduplicatesIntervalsAndKeepsNewerState()
        try testCloudMergePreservesRunningSessionAgainstStalePause()
        try testCloudResetKeepsNewerSessionsAndTombstones()
        try testSettingsAndSessionsRoundTripWithoutSeedHistory()
        try testInvalidSettingsAreClamped()
        try testCountdownPauseAndResumeRetainSingleSession()
        try testExpiredCountdownCompletesExactlyOnce()
        try testStopwatchIsPausedAndTimeIsAccountedOnRelaunch()
        print("Passed \(assertions) Ember study logic checks.")
    }

    private static var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        value.firstWeekday = 2
        value.minimumDaysInFirstWeek = 4
        return value
    }

    private static func testStudyIntervalsSplitAtMidnightAndExcludeBreaks() throws {
        let start = try date(2026, 4, 7, 23, 50)
        let end = try date(2026, 4, 8, 0, 20)
        let focus = StudySession(start: start, end: end, duration: 1800, kind: .focus)
        let rest = StudySession(start: start, end: end, duration: 1800, kind: .shortBreak)
        expect(measuredStudySeconds(in: focus, during: start, calendar: calendar, asOf: end) == 600, "Focus intervals split at the day boundary")
        expect(measuredStudySeconds(in: focus, during: end, calendar: calendar, asOf: end) == 1200, "Next-day focus duration is included")
        expect(measuredStudySeconds(in: rest, during: start, calendar: calendar, asOf: end) == 0, "Breaks do not count as study")
    }

    private static func testPauseResumeAndOverlappingSessionsCountOnce() throws {
        let store = makeStore()
        let start = try date(2026, 4, 7, 10, 0)
        let id = store.beginSession(kind: .focus, at: start)
        store.pauseSession(id: id, at: start.addingTimeInterval(300))
        store.resumeSession(id: id, at: start.addingTimeInterval(900))
        expect(store.data.sessions[0].duration(asOf: start.addingTimeInterval(1000)) == 400, "Paused time is excluded while the resumed interval accrues")
        _ = store.beginSession(kind: .focus, at: start.addingTimeInterval(1200))
        expect(store.data.sessions.filter(\.isRunning).count == 1, "Only one session remains running")
        expect(store.data.sessions[0].status == .completed, "Superseded running session is closed")
        expect(store.data.sessions[0].duration == 600, "Closed session preserves both active intervals")
    }

    private static func testWeeklyStatisticsUseMondayWeekExcludeBreaksAndRespectGoals() throws {
        let monday = try date(2026, 4, 6, 0, 0)
        let now = try date(2026, 4, 8, 12, 0)
        let sessions = [
            StudySession(start: try date(2026, 4, 6, 9, 0), end: try date(2026, 4, 6, 10, 0), duration: 3600, kind: .focus),
            StudySession(start: try date(2026, 4, 7, 9, 0), end: try date(2026, 4, 7, 9, 30), duration: 1800, kind: .focus),
            StudySession(start: try date(2026, 4, 8, 9, 0), end: now, duration: 3 * 3600, kind: .shortBreak)
        ]
        let stats = weeklyStatistics(sessions: sessions, goal: { _ in 60 }, now: now, calendar: calendar)
        expect(weekStart(for: now, calendar: calendar) == monday, "Week begins Monday")
        expect(stats.totalSeconds == 5400, "Weekly totals include only focus time")
        expect(stats.averageSeconds == 1800, "Weekly average uses elapsed calendar days")
        expect(stats.goalsReached == 1, "Weekly goal count compares displayed whole minutes")
        expect(stats.elapsedDays == 3, "Elapsed day count includes today")
    }

    private static func testOverlappingStudySessionsAreUnioned() throws {
        let start = try date(2026, 4, 7, 9, 0)
        let first = StudySession(start: start, end: start.addingTimeInterval(3600), duration: 3600, kind: .focus)
        let second = StudySession(start: start.addingTimeInterval(1800), end: start.addingTimeInterval(5400), duration: 3600, kind: .focus)
        expect(unionStudySeconds(sessions: [first, second], during: start, calendar: calendar, asOf: start.addingTimeInterval(6000)) == 5400, "Overlapping sessions are counted as a time union")
    }

    private static func testCloudMergeDeduplicatesIntervalsAndKeepsNewerState() throws {
        let start = try date(2026, 4, 7, 9, 0)
        let sharedSessionID = UUID()
        let sharedIntervalID = UUID()
        let localSession = StudySession(id: sharedSessionID, start: start, end: start.addingTimeInterval(60), duration: 60, kind: .focus, intervals: [StudyInterval(id: sharedIntervalID, start: start, end: start.addingTimeInterval(60))], modifiedAt: start.addingTimeInterval(60))
        let remoteSession = StudySession(id: sharedSessionID, start: start, end: start.addingTimeInterval(90), duration: 90, kind: .focus, intervals: [StudyInterval(id: sharedIntervalID, start: start, end: start.addingTimeInterval(90))], modifiedAt: start.addingTimeInterval(90))
        let localOnly = StudySession(start: start.addingTimeInterval(30), end: start.addingTimeInterval(120), duration: 90, kind: .focus)
        let remoteOnly = StudySession(start: start.addingTimeInterval(120), end: start.addingTimeInterval(180), duration: 60, kind: .focus)
        var local = PersistedStudyData()
        local.settingsUpdatedAt = start
        local.settings.focusMinutes = 25
        local.timerUpdatedAt = start
        local.timerDeadline = start.addingTimeInterval(300)
        local.sessions = [localSession, localOnly]
        var remote = PersistedStudyData()
        remote.settingsUpdatedAt = start.addingTimeInterval(1)
        remote.settings.focusMinutes = 50
        remote.timerUpdatedAt = start.addingTimeInterval(2)
        remote.activeMode = .countdown
        remote.timerDeadline = start.addingTimeInterval(600)
        remote.sessions = [remoteSession, remoteOnly]

        let merged = mergeStudyData(local, remote)
        expect(merged.sessions.count == 3, "Cloud merge deduplicates one session ID but keeps sessions from both devices")
        expect(merged.settings.focusMinutes == 50, "Newer settings win a cross-device edit")
        expect(merged.activeMode == .countdown && merged.timerDeadline == start.addingTimeInterval(600), "Newer timer state wins a cross-device edit")
        expect(unionStudySeconds(sessions: merged.sessions, during: start, calendar: calendar, asOf: start.addingTimeInterval(300)) == 180, "Merged session intervals count overlapping time once")
    }

    private static func testCloudMergePreservesRunningSessionAgainstStalePause() throws {
        let start = try date(2026, 4, 7, 9, 0)
        let id = UUID()
        let intervalID = UUID()
        let active = StudySession(id: id, start: start, end: nil, duration: 0, kind: .focus, status: .running, intervals: [StudyInterval(id: intervalID, start: start, end: nil)], modifiedAt: start.addingTimeInterval(60))
        let stalePaused = StudySession(id: id, start: start, end: start.addingTimeInterval(30), duration: 30, kind: .focus, status: .paused, intervals: [StudyInterval(id: intervalID, start: start, end: start.addingTimeInterval(30))], modifiedAt: start.addingTimeInterval(30))
        var local = PersistedStudyData()
        local.sessions = [active]
        var remote = PersistedStudyData()
        remote.sessions = [stalePaused]

        let merged = mergeStudyData(local, remote)
        expect(merged.sessions.first?.status == .running, "Older pause state does not close a newer running interval")
        expect(merged.sessions.first?.intervals.first?.end == nil, "Newer running interval remains open")
        expect(unionStudySeconds(sessions: merged.sessions, during: start, calendar: calendar, asOf: start.addingTimeInterval(120)) == 120, "Synced running study time is accounted to the current wall clock")
    }

    private static func testCloudResetKeepsNewerSessionsAndTombstones() throws {
        let resetAt = try date(2026, 4, 7, 10, 0)
        let earlierSession = StudySession(start: resetAt.addingTimeInterval(-60), end: resetAt.addingTimeInterval(-30), duration: 30, kind: .focus)
        let laterSession = StudySession(start: resetAt.addingTimeInterval(30), end: resetAt.addingTimeInterval(90), duration: 60, kind: .focus)
        let tombstoned = StudySession(start: resetAt.addingTimeInterval(15), end: resetAt.addingTimeInterval(45), duration: 30, kind: .focus)
        var local = PersistedStudyData()
        local.resetAt = resetAt
        local.deletedSessionIDs = [tombstoned.id]
        local.sessions = [laterSession]
        var remote = PersistedStudyData()
        remote.sessions = [earlierSession, laterSession, tombstoned]
        remote.completedFocusSessionIDs = [UUID()]

        let merged = mergeStudyData(local, remote)
        expect(merged.sessions.contains(where: { $0.id == laterSession.id }), "Reset merge retains study sessions created after the reset")
        expect(!merged.sessions.contains(where: { $0.id == earlierSession.id }), "Reset merge excludes pre-reset sessions")
        expect(!merged.sessions.contains(where: { $0.id == tombstoned.id }), "Reset merge respects deletion tombstones from either device")
    }

    private static func testSettingsAndSessionsRoundTripWithoutSeedHistory() throws {
        let directory = testDirectory()
        let store = StudyStore(storageDirectory: directory, defaults: isolatedDefaults())
        expect(store.data.sessions.isEmpty, "A fresh store has no fabricated session history")
        store.data.settings.weekdayGoals[2] = 92
        let start = try date(2026, 4, 7, 10, 0)
        let id = store.beginSession(kind: .focus, at: start)
        store.completeSession(id: id, at: start.addingTimeInterval(600))
        let restored = StudyStore(storageDirectory: directory, defaults: isolatedDefaults())
        expect(restored.data.settings.weekdayGoals[2] == 92, "Settings persist")
        expect(restored.data.sessions.count == 1, "Sessions persist")
        expect(restored.data.sessions[0].duration == 600, "Completed duration persists")
        expect(restored.data.sessions[0].status == .completed, "Completed status persists")
    }

    private static func testInvalidSettingsAreClamped() throws {
        let json = #"{"settings":{"weekdayGoals":{"2":9999},"focusMinutes":999,"quickDurations":[0,25,25,800]},"sessions":[]}"#.data(using: .utf8)!
        let model = try JSONDecoder().decode(PersistedStudyData.self, from: json)
        expect(model.settings.weekdayGoals[2] == 1440, "Daily goals are clamped")
        expect(model.settings.focusMinutes == 180, "Focus duration is clamped")
        expect(model.settings.quickDurations == [25], "Quick durations are filtered and deduplicated")
        expect(!model.timerRunning, "Missing timer state defaults to stopped")
    }

    private static func testCountdownPauseAndResumeRetainSingleSession() throws {
        let store = makeStore()
        let timer = TimerEngine(store: store)
        timer.configureCountdown(minutes: 1)
        timer.start()
        let id = try require(store.data.timerSessionID, "Countdown starts a session")
        timer.pause()
        expect(store.data.sessions.first(where: { $0.id == id })?.status == .paused, "Pausing closes active interval")
        timer.start()
        expect(store.data.timerSessionID == id, "Resume retains session identity")
        timer.pause()
        expect(store.data.sessions.filter { $0.id == id }.count == 1, "Resume does not duplicate the session")
        expect(!store.data.timerRunning, "Paused timer is not persisted as running")
    }

    private static func testExpiredCountdownCompletesExactlyOnce() throws {
        let store = makeStore()
        store.data.settings.completionSound = false
        store.data.settings.breakReminders = false
        let timer = TimerEngine(store: store)
        timer.configureCountdown(minutes: 1)
        timer.start()
        let id = try require(store.data.timerSessionID, "Countdown starts a session")
        let deadline = try require(store.data.timerDeadline, "Countdown persists its deadline")
        timer.refreshFromClock(at: deadline.addingTimeInterval(1))
        expect(timer.isComplete && !timer.isRunning, "Expired countdown completes")
        expect(store.data.sessions.first(where: { $0.id == id })?.status == .completed, "Completion closes its session")
        expect(store.data.completedFocusSessions == 1, "Focus completion count increments once")
        timer.refreshFromClock(at: deadline.addingTimeInterval(2))
        expect(store.data.completedFocusSessions == 1, "Repeated clock refresh is idempotent")
    }

    private static func testStopwatchIsPausedAndTimeIsAccountedOnRelaunch() throws {
        let directory = testDirectory()
        let defaults = isolatedDefaults()
        let store = StudyStore(storageDirectory: directory, defaults: defaults)
        let timer = TimerEngine(store: store)
        timer.select(.stopwatch)
        timer.start()
        let id = try require(store.data.timerSessionID, "Stopwatch starts a session")
        let started = try require(store.data.stopwatchStartedAt, "Stopwatch persists its wall-clock anchor")
        var persisted = store.data
        persisted.stopwatchStartedAt = started.addingTimeInterval(-90)
        store.data = persisted
        let relaunchedStore = StudyStore(storageDirectory: directory, defaults: defaults)
        let relaunchedTimer = TimerEngine(store: relaunchedStore)
        expect(!relaunchedTimer.isRunning, "Stopwatch is paused after relaunch")
        expect(relaunchedTimer.elapsed >= 90, "Stopwatch elapsed time survives relaunch")
        expect(relaunchedStore.data.sessions.first(where: { $0.id == id })?.status == .paused, "Recovered stopwatch session is paused")
    }

    private static func makeStore() -> StudyStore {
        StudyStore(storageDirectory: testDirectory(), defaults: isolatedDefaults())
    }

    private static func testDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("EmberTests-\(UUID().uuidString)", isDirectory: true)
    }

    private static func isolatedDefaults() -> UserDefaults {
        UserDefaults(suiteName: "EmberTests.\(UUID().uuidString)")!
    }

    private static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) throws -> Date {
        guard let result = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)) else {
            throw TestFailure(description: "Could not construct test date")
        }
        return result
    }

    private static func require<T>(_ value: T?, _ message: String) throws -> T {
        guard let value else { throw TestFailure(description: message) }
        return value
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        assertions += 1
        guard condition() else { fatalError("FAILED: \(message)") }
    }

    private struct TestFailure: Error, CustomStringConvertible {
        let description: String
        init(description: String) { self.description = description }
    }
}
