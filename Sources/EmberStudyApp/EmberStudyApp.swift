import SwiftUI
#if os(macOS)
import AppKit
#endif

extension Notification.Name {
    static let emberNavigateDashboard = Notification.Name("ember.navigate.dashboard")
    static let emberNavigateTimers = Notification.Name("ember.navigate.timers")
    static let emberNavigateStatistics = Notification.Name("ember.navigate.statistics")
    static let emberNavigateSettings = Notification.Name("ember.navigate.settings")
    static let emberSyncCloudChanges = Notification.Name("ember.cloud.request-sync")
}

@main
struct EmberStudyApp: App {
    @StateObject private var store: StudyStore
    @StateObject private var engine: TimerEngine

    init() {
        let studyStore = StudyStore()
        _store = StateObject(wrappedValue: studyStore)
        _engine = StateObject(wrappedValue: TimerEngine(store: studyStore))
    }

    var body: some Scene {
        WindowGroup {
            Group {
                #if os(iOS)
                iPhoneRootView(store: store, engine: engine)
                    .preferredColorScheme(store.data.settings.appearance.colorScheme)
                    .tint(store.data.settings.accent.color)
                #else
                MainWindow(store: store, engine: engine)
                    .preferredColorScheme(store.data.settings.appearance.colorScheme)
                    .tint(store.data.settings.accent.color)
                    .frame(minWidth: 900, minHeight: 640)
                    .background(Color.emberBackground)
                #endif
            }
            .onReceive(NotificationCenter.default.publisher(for: .emberCloudStateUpdated)) { _ in
                engine.refreshFromClock()
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ember.app.willDeactivate"))) { _ in
                engine.handleAppDeactivation()
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ember.app.didActivate"))) { _ in
                engine.refreshFromClock()
            }
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1120, height: 790)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .appInfo) { }
            SidebarCommands()
            CommandGroup(after: .appInfo) {
                Button("Dashboard") { NotificationCenter.default.post(name: .emberNavigateDashboard, object: nil) }.keyboardShortcut("1", modifiers: .command)
                Button("Timers") { NotificationCenter.default.post(name: .emberNavigateTimers, object: nil) }.keyboardShortcut("2", modifiers: .command)
                Button("Statistics") { NotificationCenter.default.post(name: .emberNavigateStatistics, object: nil) }.keyboardShortcut("3", modifiers: .command)
                Button("Settings") { NotificationCenter.default.post(name: .emberNavigateSettings, object: nil) }.keyboardShortcut(",", modifiers: .command)
            }
        }
        #endif
    }
}

private struct RailNavigationButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.emberSoftFill : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct MainWindow: View {
    @ObservedObject var store: StudyStore
    @ObservedObject var engine: TimerEngine
    @State private var selection: AppSection = .dashboard
    @Namespace private var railIndicatorNamespace
    @FocusState private var focusedRailItem: AppSection?
    @State private var hoveredRailItem: AppSection?
    @State private var idlePeekIndex: AppSection?
    @State private var idlePeekEnabled = true
    @State private var idlePeekTakenOver = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let railSections: [AppSection] = [.dashboard, .timers, .statistics, .settings]
    private var isDark: Bool {
        #if os(macOS)
        return store.data.settings.appearance == .dark || (store.data.settings.appearance == .system && NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua)
        #else
        return store.data.settings.appearance == .dark
        #endif
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            VStack(spacing: 0) {
                titleBar
                Rectangle().fill(Color.emberStroke).frame(height: 1)
                page
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.emberBackground)
        }
        .frame(minWidth: 900, minHeight: 640)
        .background(Color.emberBackground)
        .foregroundStyle(Color.emberText)
        .animation(.easeInOut(duration: 0.18), value: selection)
        #if os(macOS)
        .onAppear { startIdlePeekIfAvailable() }
        .onDisappear { stopIdlePeek() }
        .task(id: idlePeekEnabled) {
            guard idlePeekEnabled && !reduceMotion else { return }
            await runIdlePeek()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            stopIdlePeek()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            startIdlePeekIfAvailable()
        }
        #endif
        .onChange(of: selection) { _, _ in takeOverIdlePeek() }
        .onChange(of: focusedRailItem) { _, item in if item != nil { takeOverIdlePeek() } }
        .onChange(of: store.data.settings.focusMinutes) { _, _ in engine.setPomodoroPhaseFromSettings() }
        .onChange(of: store.data.settings.shortBreakMinutes) { _, _ in engine.setPomodoroPhaseFromSettings() }
        .onChange(of: store.data.settings.longBreakMinutes) { _, _ in engine.setPomodoroPhaseFromSettings() }
        .onReceive(NotificationCenter.default.publisher(for: .emberNavigateDashboard)) { _ in selection = .dashboard }
        .onReceive(NotificationCenter.default.publisher(for: .emberNavigateTimers)) { _ in selection = .timers }
        .onReceive(NotificationCenter.default.publisher(for: .emberNavigateStatistics)) { _ in selection = .statistics }
        .onReceive(NotificationCenter.default.publisher(for: .emberNavigateSettings)) { _ in selection = .settings }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ember.app.willDeactivate"))) { _ in
            engine.handleAppDeactivation()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ember.app.didActivate"))) { _ in
            engine.refreshFromClock()
        }
    }

    private var sidebar: some View {
        VStack {
            Spacer(minLength: 0)
            VStack(spacing: 4) {
                ForEach([AppSection.dashboard, .timers, .statistics]) { section in
                    railItem(section)
                }
                Rectangle().fill(Color.emberStroke).frame(width: 28, height: 1).padding(.vertical, 5)
                railItem(.settings)
            }
            .padding(6)
            .background(Color.emberSurface.opacity(0.96), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(Color.emberStroke, lineWidth: 1))
            .shadow(color: .black.opacity(isDark ? 0.22 : 0.07), radius: 16, x: 0, y: 7)
            .zIndex(2)
            Spacer(minLength: 0)
        }
        .frame(width: 72)
        .frame(maxHeight: .infinity)
        .padding(.vertical, 12)
        .zIndex(2)
    }

    private func railItem(_ section: AppSection) -> some View {
        let selected = selection == section
        let active = selected || (idlePeekEnabled && idlePeekIndex == section)
        let hovered = hoveredRailItem == section
        let peeked = idlePeekIndex == section && idlePeekEnabled
        let labelVisible = hovered || focusedRailItem == section || peeked
        return Button {
            takeOverIdlePeek()
            withAnimation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.78)) { selection = section }
        } label: {
            Image(systemName: section.symbol)
                .font(.system(size: 15, weight: active ? .semibold : .regular))
                .foregroundStyle(active ? Color.accentColor : Color.emberMuted)
                .frame(width: 44, height: 42)
                .background {
                    if active {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.accentColor.opacity(isDark ? 0.13 : 0.10))
                            .padding(.horizontal, 2)
                    }
                }
                .overlay(alignment: .leading) {
                    if active {
                        Capsule().fill(Color.accentColor)
                            .frame(width: 3, height: 21)
                            .matchedGeometryEffect(id: "rail-active-indicator", in: railIndicatorNamespace)
                            .accessibilityHidden(true)
                            .offset(x: -7)
                    }
                }
                .overlay(alignment: .trailing) {
                    if labelVisible {
                        Text(section.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(Color.emberTooltip, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.emberStroke, lineWidth: 1))
                            .fixedSize()
                            .shadow(color: .black.opacity(0.16), radius: 8, x: 0, y: 4)
                            .offset(x: 11)
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                            .accessibilityHidden(true)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(RailNavigationButtonStyle())
        .focused($focusedRailItem, equals: section)
        .onHover { hovering in
            if hovering {
                takeOverIdlePeek()
                hoveredRailItem = section
            } else if hoveredRailItem == section {
                hoveredRailItem = nil
            }
        }
        .help(section.rawValue)
        .accessibilityLabel(section.rawValue)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .zIndex(labelVisible ? 3 : 0)
    }

    private func startIdlePeekIfAvailable() {
        #if os(macOS)
        guard !reduceMotion, !idlePeekTakenOver, !NSApp.isHidden, idlePeekIndex == nil else { return }
        #else
        guard !reduceMotion, !idlePeekTakenOver, idlePeekIndex == nil else { return }
        #endif
        idlePeekEnabled = true
    }

    private func stopIdlePeek() {
        idlePeekEnabled = false
        idlePeekIndex = nil
    }

    private func takeOverIdlePeek() {
        idlePeekTakenOver = true
        stopIdlePeek()
    }

    private func runIdlePeek() async {
        try? await Task.sleep(for: .milliseconds(700))
        var index = 0
        while !Task.isCancelled && idlePeekEnabled {
            if hoveredRailItem != nil || focusedRailItem != nil {
                try? await Task.sleep(for: .milliseconds(500))
                continue
            }
            withAnimation(.easeOut(duration: 0.18)) { idlePeekIndex = railSections[index] }
            try? await Task.sleep(for: .milliseconds(950))
            guard !Task.isCancelled && idlePeekEnabled else { break }
            withAnimation(.easeOut(duration: 0.18)) { idlePeekIndex = nil }
            index = (index + 1) % railSections.count
            try? await Task.sleep(for: .milliseconds(550))
        }
        idlePeekIndex = nil
    }

    private var titleBar: some View {
        HStack(spacing: 10) {
            Text(selection.rawValue).font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.emberText)
            if selection == .dashboard {
                Circle().fill(Color.emberMuted.opacity(0.55)).frame(width: 3, height: 3)
                Text(Date.now.formatted(.dateTime.month(.abbreviated).day())).font(.system(size: 10)).foregroundStyle(Color.emberMuted)
            }
            Spacer()
            if selection != .settings {
                Button { selection = .settings } label: {
                    Image(systemName: "gearshape").font(.system(size: 12, weight: .medium)).foregroundStyle(Color.emberSecondary)
                        .frame(width: 28, height: 28).background(Color.emberSoftFill, in: RoundedRectangle(cornerRadius: 7))
                }.buttonStyle(.plain).help("Settings")
            }
        }
        .padding(.leading, 24).padding(.trailing, 20).frame(height: 50)
        .background(Color.emberBackground.opacity(0.98))
    }

    @ViewBuilder private var page: some View {
        switch selection {
        case .dashboard: DashboardView(store: store, engine: engine)
        case .timers: TimerScreen(engine: engine, store: store)
        case .statistics: StatisticsView(store: store)
        case .settings: SettingsView(store: store, engine: engine)
        }
    }
}
