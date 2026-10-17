import SwiftUI

#if os(iOS)
struct iPhoneRootView: View {
    @ObservedObject var store: StudyStore
    @ObservedObject var engine: TimerEngine
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection: PhoneSection = .today

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { todayView }
                .tabItem { Label("Today", systemImage: "sun.max") }
                .tag(PhoneSection.today)
            NavigationStack { timerView }
                .tabItem { Label("Timer", systemImage: "timer") }
                .tag(PhoneSection.timer)
            NavigationStack { weekView }
                .tabItem { Label("Week", systemImage: "chart.bar.xaxis") }
                .tag(PhoneSection.week)
            NavigationStack { SettingsView(store: store, engine: engine) }
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
                .tag(PhoneSection.settings)
        }
        .background(Color.emberBackground.ignoresSafeArea())
        .onReceive(NotificationCenter.default.publisher(for: .emberCloudStateUpdated)) { _ in
            engine.refreshFromClock()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                engine.refreshFromClock()
                NotificationCenter.default.post(name: .emberSyncCloudChanges, object: nil)
            case .inactive, .background:
                engine.handleAppDeactivation()
            @unknown default:
                break
            }
        }
    }

    private var todayView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Good to see you")
                            .font(.system(size: 27, weight: .semibold, design: .rounded))
                            .tracking(-0.5).foregroundStyle(Color.emberText)
                        Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                            .font(.system(size: 13, weight: .medium)).foregroundStyle(Color.emberMuted)
                    }
                    Spacer()
                    syncBadge
                }
                TodayProgressCard(store: store)
                TimerCard(engine: engine, store: store, compact: true)
                TodayTimelineCard(store: store, sessions: store.sessions(on: Date()))
            }
            .padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 28)
        }
        .background(Color.emberBackground)
        .navigationTitle("Ember")
        .toolbarBackground(Color.emberBackground, for: .navigationBar)
    }

    private var timerView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionTitle(title: "Timers", subtitle: "A little structure, your way.")
                TimerModePicker(engine: engine)
                TimerCard(engine: engine, store: store)
                if engine.isRunning {
                    Label("Timer keeps its exact end time when Ember is in the background.", systemImage: "clock.arrow.circlepath")
                        .font(.system(size: 12)).foregroundStyle(Color.emberMuted)
                }
            }
            .padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 28)
        }
        .background(Color.emberBackground)
        .navigationTitle("Focus")
        .toolbarBackground(Color.emberBackground, for: .navigationBar)
    }

    private var weekView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitle(title: "Your week", subtitle: "Real study time, no estimates.")
                HStack(spacing: 10) {
                    mobileStat("This week", value: compactDuration(store.weekTotal), icon: "clock")
                    mobileStat("Daily average", value: compactDuration(store.weekAverage), icon: "chart.bar")
                }
                HStack(spacing: 10) {
                    mobileStat("Goals reached", value: "\(store.goalsReachedThisWeek) / \(store.elapsedDaysThisWeek)", icon: "checkmark.circle")
                    mobileStat("Compared", value: store.previousWeekTotal == 0 ? "—" : "\(store.weeklyChange >= 0 ? "+" : "−")\(Int(abs(store.weeklyChange) * 100))%", icon: "arrow.up.right")
                }
                WeeklySummaryCard(store: store)
                EmberCard {
                    VStack(alignment: .leading, spacing: 14) {
                        CardHeading(title: "Daily goals", subtitle: "Study time compared to your target")
                        ForEach(Array(zip(store.weekDates, store.weekStudyMinutes).enumerated()), id: \.offset) { _, item in
                            HStack(spacing: 9) {
                                Text(item.0.formatted(.dateTime.weekday(.abbreviated)))
                                    .font(.system(size: 11, weight: .medium)).foregroundStyle(Color.emberSecondary)
                                    .frame(width: 38, alignment: .leading)
                                ProgressTrack(value: Double(item.1) / Double(max(store.goal(for: item.0), 1)), height: 7)
                                Text("\(item.1)m / \(store.goal(for: item.0))m")
                                    .font(.system(size: 10, weight: .medium, design: .rounded).monospacedDigit())
                                    .foregroundStyle(Color.emberMuted).frame(width: 76, alignment: .trailing)
                            }
                        }
                    }
                }
                Text("Only completed study intervals count. Breaks and overlapping time aren’t double-counted.")
                    .font(.system(size: 11)).foregroundStyle(Color.emberMuted)
            }
            .padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 28)
        }
        .background(Color.emberBackground)
        .navigationTitle("Statistics")
        .toolbarBackground(Color.emberBackground, for: .navigationBar)
    }

    private var syncBadge: some View {
        Button { store.syncNow() } label: {
            HStack(spacing: 5) {
                Image(systemName: syncSymbol)
                Text(store.cloudSyncStatus.title)
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Color.emberSecondary)
            .padding(.horizontal, 9).padding(.vertical, 7)
            .background(Color.emberSurface, in: Capsule())
            .overlay(Capsule().stroke(Color.emberStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Tap to try syncing with iCloud now")
    }

    private var syncSymbol: String {
        switch store.cloudSyncStatus {
        case .waiting: "icloud"
        case .syncing: "arrow.triangle.2.circlepath.icloud"
        case .synced: "checkmark.icloud"
        case .unavailable: "exclamationmark.icloud"
        }
    }

    private func mobileStat(_ title: String, value: String, icon: String) -> some View {
        EmberCard(padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.accentColor)
                Text(value).font(.system(size: 20, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Color.emberText).lineLimit(1).minimumScaleFactor(0.7)
                Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(Color.emberMuted)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private enum PhoneSection: Hashable {
    case today, timer, week, settings
}

private struct TimerModePicker: View {
    @ObservedObject var engine: TimerEngine

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TimerMode.allCases) { mode in
                    Button { engine.select(mode) } label: {
                        Label(mode.rawValue, systemImage: mode.symbol)
                            .font(.system(size: 12, weight: engine.mode == mode ? .semibold : .medium))
                            .foregroundStyle(engine.mode == mode ? Color.accentColor : Color.emberSecondary)
                            .padding(.horizontal, 12).padding(.vertical, 9)
                            .background(engine.mode == mode ? Color.accentColor.opacity(0.12) : Color.emberSurface, in: Capsule())
                            .overlay(Capsule().stroke(engine.mode == mode ? Color.accentColor.opacity(0.25) : Color.emberStroke, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
#endif
