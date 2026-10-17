import Foundation
import CloudKit
#if os(macOS)
import Security
#endif

enum CloudSyncStatus: Equatable {
    case waiting
    case syncing
    case synced(Date)
    case unavailable(String)

    var title: String {
        switch self {
        case .waiting: "Waiting for iCloud"
        case .syncing: "Syncing with iCloud…"
        case .synced: "Synced with iCloud"
        case .unavailable: "Sync unavailable"
        }
    }
}

func mergeStudyData(_ local: PersistedStudyData, _ remote: PersistedStudyData) -> PersistedStudyData {
    if local.resetAt != remote.resetAt {
        let newerReset = local.resetAt > remote.resetAt ? local : remote
        let older = local.resetAt > remote.resetAt ? remote : local
        var reset = newerReset
        reset.settings = mergeSettings(local, remote)
        if local.timerUpdatedAt != remote.timerUpdatedAt {
            let newestTimer = local.timerUpdatedAt > remote.timerUpdatedAt ? local : remote
            reset.activeMode = newestTimer.activeMode
            reset.remaining = newestTimer.remaining
            reset.elapsed = newestTimer.elapsed
            reset.stopwatchStartedAt = newestTimer.stopwatchStartedAt
            reset.selectedKind = newestTimer.selectedKind
            reset.timerBaseDuration = newestTimer.timerBaseDuration
            reset.targetDate = newestTimer.targetDate
            reset.timerRunning = newestTimer.timerRunning
            reset.timerStartedAt = newestTimer.timerStartedAt
            reset.timerDeadline = newestTimer.timerDeadline
            reset.timerSessionID = newestTimer.timerSessionID
            reset.timerUpdatedAt = newestTimer.timerUpdatedAt
        }
        reset.deletedSessionIDs.formUnion(older.deletedSessionIDs)
        reset.deletedSessionIDs.formUnion(older.sessions.filter { $0.start <= newerReset.resetAt }.map(\.id))
        var sessionsByID = Dictionary(uniqueKeysWithValues: reset.sessions.map { ($0.id, $0) })
        for session in older.sessions where session.start > newerReset.resetAt && !reset.deletedSessionIDs.contains(session.id) {
            sessionsByID[session.id] = sessionsByID[session.id].map { mergeStudySession($0, session) } ?? session
        }
        reset.sessions = sessionsByID.values.filter { $0.start > newerReset.resetAt && !reset.deletedSessionIDs.contains($0.id) }
            .sorted { $0.start == $1.start ? $0.id.uuidString < $1.id.uuidString : $0.start < $1.start }
        reset.completedFocusSessionIDs.formUnion(older.completedFocusSessionIDs.filter { id in
            older.sessions.contains { $0.id == id && $0.start > newerReset.resetAt }
        })
        reset.completedFocusSessions = reset.completedFocusSessionIDs.count
        reset.updatedAt = max(local.updatedAt, remote.updatedAt)
        return reset
    }

    var merged = local
    merged.settings = mergeSettings(local, remote)
    if remote.timerUpdatedAt > local.timerUpdatedAt {
        merged.activeMode = remote.activeMode
        merged.remaining = remote.remaining
        merged.elapsed = remote.elapsed
        merged.stopwatchStartedAt = remote.stopwatchStartedAt
        merged.selectedKind = remote.selectedKind
        merged.timerBaseDuration = remote.timerBaseDuration
        merged.targetDate = remote.targetDate
        merged.timerRunning = remote.timerRunning
        merged.timerStartedAt = remote.timerStartedAt
        merged.timerDeadline = remote.timerDeadline
        merged.timerSessionID = remote.timerSessionID
        merged.timerUpdatedAt = remote.timerUpdatedAt
    }

    merged.deletedSessionIDs.formUnion(remote.deletedSessionIDs)
    var sessionsByID = Dictionary(uniqueKeysWithValues: local.sessions.map { ($0.id, $0) })
    for session in remote.sessions {
        guard !merged.deletedSessionIDs.contains(session.id) else { continue }
        if let existing = sessionsByID[session.id] {
            sessionsByID[session.id] = mergeStudySession(existing, session)
        } else {
            sessionsByID[session.id] = session
        }
    }
    merged.sessions = sessionsByID.values
        .filter { !$0.id.uuidString.isEmpty && !merged.deletedSessionIDs.contains($0.id) }
        .sorted { $0.start == $1.start ? $0.id.uuidString < $1.id.uuidString : $0.start < $1.start }
    merged.completedFocusSessionIDs.formUnion(remote.completedFocusSessionIDs)
    merged.completedFocusSessions = merged.completedFocusSessionIDs.count
    merged.notifiedGoalDays.formUnion(remote.notifiedGoalDays)
    merged.updatedAt = max(local.updatedAt, remote.updatedAt)
    return merged
}

private func mergeSettings(_ local: PersistedStudyData, _ remote: PersistedStudyData) -> StudySettings {
    remote.settingsUpdatedAt > local.settingsUpdatedAt ? remote.settings : local.settings
}

private func mergeStudySession(_ lhs: StudySession, _ rhs: StudySession) -> StudySession {
    var result = lhs.modifiedAt >= rhs.modifiedAt ? lhs : rhs
    let newest = lhs.modifiedAt >= rhs.modifiedAt ? lhs : rhs
    let intervalsByID = Dictionary((lhs.intervals + rhs.intervals).map { ($0.id, $0) }, uniquingKeysWith: { first, second in
        let start = min(first.start, second.start)
        let preferred = newest.intervals.first(where: { $0.id == first.id }) ?? first
        return StudyInterval(id: first.id, start: start, end: preferred.end)
    })
    result.intervals = intervalsByID.values.sorted { $0.start < $1.start }
    result.start = min(lhs.start, rhs.start)
    result.modifiedAt = max(lhs.modifiedAt, rhs.modifiedAt)
    result.duration = max(lhs.duration, rhs.duration, result.intervals.reduce(0) { $0 + $1.seconds() })

    if lhs.status == .completed || rhs.status == .completed {
        result.status = .completed
        result.end = max(lhs.end ?? .distantPast, rhs.end ?? .distantPast)
        result.intervals = result.intervals.map { interval in
            guard interval.end == nil else { return interval }
            return StudyInterval(id: interval.id, start: interval.start, end: max(result.end ?? interval.start, interval.start))
        }
    } else if result.status == .running {
        result.end = nil
    } else {
        result.status = .paused
        result.end = result.end ?? max(lhs.end ?? .distantPast, rhs.end ?? .distantPast)
    }
    return result
}

@MainActor
final class CloudSyncCoordinator {
    nonisolated private static let recordType = "EmberStudyData"
    nonisolated private static let recordID = CKRecord.ID(recordName: "private-study-data-v3")
    nonisolated private static let serializedStateKey = "ember.cloudkit.sync-state.v1"

    private weak var store: StudyStore?
    private var container: CKContainer?
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var engine: CKSyncEngine?
    private var latestSnapshot: PersistedStudyData
    private var retryTask: Task<Void, Never>?
    private var observer: NSObjectProtocol?
    private var lastSyncAt: Date?
    private var isSyncRequestRunning = false
    private var anotherSyncRequested = false

    init(store: StudyStore, defaults: UserDefaults = .standard) {
        self.store = store
        self.defaults = defaults
        latestSnapshot = store.data
        encoder.outputFormatting = [.sortedKeys]
    }

    func start() {
        guard engine == nil, Bundle.main.bundleURL.pathExtension == "app" else { return }
        #if os(macOS)
        // CKContainer(identifier:) traps if the running process has no matching iCloud
        // container entitlement. Unsigned/ad-hoc local builds cannot request restricted
        // CloudKit entitlements, so leave local study tracking available and report why sync
        // is unavailable; a properly Apple-signed app still uses the same CloudKit path below.
        guard Self.hasCloudKitEntitlement else {
            store?.setCloudSyncStatus(.unavailable("This build is not signed with Ember’s iCloud container entitlement."))
            return
        }
        #endif
        let cloudContainer = CKContainer(identifier: "iCloud.app.ember.study")
        container = cloudContainer
        let state = defaults.data(forKey: Self.serializedStateKey).flatMap { try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: $0) }
        engine = CKSyncEngine(CKSyncEngine.Configuration(database: cloudContainer.privateCloudDatabase, stateSerialization: state, delegate: self))
        observer = NotificationCenter.default.addObserver(forName: Notification.Name("ember.cloud.request-sync"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.syncNow() }
        }
        store?.setCloudSyncStatus(.syncing)
        Task { @MainActor [weak self] in await self?.requestInitialReconciliation() }
    }

    #if os(macOS)
    private static var hasCloudKitEntitlement: Bool {
        guard let task = SecTaskCreateFromSelf(nil),
              let containers = SecTaskCopyValueForEntitlement(
                task,
                "com.apple.developer.icloud-container-identifiers" as CFString,
                nil
              ) as? [String] else {
            return false
        }
        return containers.contains("iCloud.app.ember.study")
    }
    #endif

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    func schedule(_ data: PersistedStudyData) {
        latestSnapshot = data
        guard let engine else { return }
        engine.state.add(pendingRecordZoneChanges: [.saveRecord(Self.recordID)])
        store?.setCloudSyncStatus(.syncing)
    }

    func syncNow() {
        start()
        guard let engine else { return }
        engine.state.add(pendingRecordZoneChanges: [.saveRecord(Self.recordID)])
        store?.setCloudSyncStatus(.syncing)
        guard !isSyncRequestRunning else {
            anotherSyncRequested = true
            return
        }
        isSyncRequestRunning = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            var syncError: Error?
            do {
                try await engine.fetchChanges(CKSyncEngine.FetchChangesOptions())
                try await engine.sendChanges(CKSyncEngine.SendChangesOptions())
            } catch {
                syncError = error
            }
            self.isSyncRequestRunning = false
            if let syncError {
                self.store?.setCloudSyncStatus(.unavailable(syncError.localizedDescription))
                self.scheduleRetry()
            } else if self.anotherSyncRequested {
                self.anotherSyncRequested = false
                self.syncNow()
            }
        }
    }

    private func requestInitialReconciliation() async {
        guard let engine else { return }
        do {
            guard let container else { return }
            let status = try await container.accountStatus()
            guard status == .available else {
                store?.setCloudSyncStatus(.unavailable(status == .noAccount ? "Sign in to iCloud to sync." : "iCloud is not available on this account."))
                return
            }
            try await engine.fetchChanges(CKSyncEngine.FetchChangesOptions())
            engine.state.add(pendingRecordZoneChanges: [.saveRecord(Self.recordID)])
            try await engine.sendChanges(CKSyncEngine.SendChangesOptions())
        } catch {
            store?.setCloudSyncStatus(.unavailable(error.localizedDescription))
            scheduleRetry()
        }
    }

    private func recordForSave(using engine: CKSyncEngine) async throws -> CKRecord {
        let record: CKRecord
        do { record = try await engine.database.record(for: Self.recordID) }
        catch let error as CKError where error.code == .unknownItem { record = CKRecord(recordType: Self.recordType, recordID: Self.recordID) }
        if let payload = record["payload"] as? Data,
           let remote = try? decoder.decode(PersistedStudyData.self, from: payload) {
            latestSnapshot = mergeStudyData(latestSnapshot, remote)
            store?.updateCloudState(latestSnapshot)
        }
        let payload = try encoder.encode(latestSnapshot)
        record["payload"] = payload as CKRecordValue
        record["schemaVersion"] = Int64(3) as CKRecordValue
        record["modifiedAt"] = Date() as CKRecordValue
        return record
    }

    private func applyRemote(_ record: CKRecord) {
        guard let payload = record["payload"] as? Data, let remote = try? decoder.decode(PersistedStudyData.self, from: payload) else { return }
        latestSnapshot = mergeStudyData(latestSnapshot, remote)
        store?.updateCloudState(latestSnapshot)
    }

    private func scheduleRetry() {
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled else { return }
            self?.syncNow()
        }
    }
}

@MainActor
extension CloudSyncCoordinator: CKSyncEngineDelegate {
    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch event {
        case .stateUpdate(let update):
            if let serialized = try? JSONEncoder().encode(update.stateSerialization) {
                defaults.set(serialized, forKey: Self.serializedStateKey)
            }
        case .fetchedRecordZoneChanges(let changes):
            for modification in changes.modifications where modification.record.recordID == Self.recordID {
                applyRemote(modification.record)
            }
        case .sentRecordZoneChanges(let changes):
            for savedRecord in changes.savedRecords where savedRecord.recordID == Self.recordID {
                applyRemote(savedRecord)
            }
            if let error = changes.failedRecordSaves.first?.error {
                if let serverRecord = error.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord {
                    applyRemote(serverRecord)
                    syncEngine.state.add(pendingRecordZoneChanges: [.saveRecord(Self.recordID)])
                    store?.setCloudSyncStatus(.syncing)
                } else {
                    store?.setCloudSyncStatus(.unavailable(error.localizedDescription))
                    scheduleRetry()
                }
            }
        case .accountChange(let change):
            switch change.changeType {
            case .signOut, .switchAccounts:
                store?.setCloudSyncStatus(.unavailable("Sign in with the same iCloud account on both devices."))
            case .signIn:
                store?.setCloudSyncStatus(.syncing)
            @unknown default:
                store?.setCloudSyncStatus(.unavailable("iCloud account changed."))
            }
        case .didFetchChanges:
            let syncedAt = Date()
            lastSyncAt = syncedAt
            if !syncEngine.state.pendingRecordZoneChanges.isEmpty {
                store?.setCloudSyncStatus(.syncing)
            } else {
                store?.setCloudSyncStatus(.synced(syncedAt))
            }
        case .didSendChanges:
            let syncedAt = Date()
            lastSyncAt = syncedAt
            if syncEngine.state.pendingRecordZoneChanges.isEmpty {
                store?.setCloudSyncStatus(.synced(syncedAt))
            } else {
                store?.setCloudSyncStatus(.syncing)
            }
        default:
            break
        }
    }

    func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let pending = syncEngine.state.pendingRecordZoneChanges.filter { context.options.scope.contains($0) }
        guard !pending.isEmpty else { return nil }
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pending) { [weak self] recordID in
            guard recordID == Self.recordID, let self else { return nil }
            return try? await self.recordForSave(using: syncEngine)
        }
    }
}
