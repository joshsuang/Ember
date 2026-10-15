import SwiftUI
import AppKit

extension Notification.Name {
    static let emberNavigateDashboard = Notification.Name("ember.navigate.dashboard")
    static let emberNavigateTimers = Notification.Name("ember.navigate.timers")
    static let emberNavigateStatistics = Notification.Name("ember.navigate.statistics")
    static let emberNavigateSettings = Notification.Name("ember.navigate.settings")
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
            MainWindow(store: store, engine: engine)
                .preferredColorScheme(store.data.settings.appearance.colorScheme)
                .tint(store.data.settings.accent.color)
                .frame(minWidth: 900, minHeight: 640)
                .background(Color.emberBackground)
        }
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
    @State private var railExpanded = false
    @State private var railHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let railWidth: CGFloat = 58
    private var railIsExpanded: Bool { railExpanded || railHovered }
    private var isDark: Bool { store.data.settings.appearance == .dark || (store.data.settings.appearance == .system && NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua) }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(Color.emberStroke).frame(width: 1)
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
        .onChange(of: store.data.settings.focusMinutes) { _, _ in engine.setPomodoroPhaseFromSettings() }
        .onChange(of: store.data.settings.shortBreakMinutes) { _, _ in engine.setPomodoroPhaseFromSettings() }
        .onChange(of: store.data.settings.longBreakMinutes) { _, _ in engine.setPomodoroPhaseFromSettings() }
        .onReceive(NotificationCenter.default.publisher(for: .emberNavigateDashboard)) { _ in selection = .dashboard }
        .onReceive(NotificationCenter.default.publisher(for: .emberNavigateTimers)) { _ in selection = .timers }
        .onReceive(NotificationCenter.default.publisher(for: .emberNavigateStatistics)) { _ in selection = .statistics }
        .onReceive(NotificationCenter.default.publisher(for: .emberNavigateSettings)) { _ in selection = .settings }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            Button { railExpanded.toggle() } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.accentColor).frame(width: 32, height: 32)
                    Image(systemName: "sparkle").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                }
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(railExpanded ? "Keep navigation compact" : "Pin navigation labels open")
            .accessibilityLabel(railExpanded ? "Collapse navigation rail" : "Expand navigation rail")
            .padding(.top, 15)
            .padding(.bottom, 20)

            VStack(spacing: 4) {
                ForEach(AppSection.allCases) { section in
                    railItem(section)
                }
            }
            Spacer(minLength: 10)
            if engine.isRunning {
                Button { selection = .timers } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "timer").font(.system(size: 15, weight: .medium)).frame(width: 40, height: 40)
                        Circle().fill(Color.accentColor).frame(width: 6, height: 6).offset(x: -5, y: 5)
                    }
                    .foregroundStyle(selection == .timers ? Color.accentColor : Color.emberMuted)
                    .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .help("Focus timer · \(durationText(engine.displayValue)) remaining")
                .accessibilityLabel("Active focus timer, \(durationText(engine.displayValue)) remaining")
                .padding(.bottom, 8)
            }
            Rectangle().fill(Color.emberStroke).frame(height: 1).padding(.horizontal, 11).padding(.bottom, 8)
            railItem(.settings)
                .padding(.bottom, 13)
        }
        .frame(width: railWidth)
        .frame(maxHeight: .infinity)
        .background(Color.emberRail)
        .overlay(alignment: .trailing) { Rectangle().fill(Color.emberStroke).frame(width: 1) }
        .overlay(alignment: .topLeading) {
            if railIsExpanded {
                Text("ember")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(0.4)
                    .foregroundStyle(Color.emberMuted)
                    .padding(.leading, 10)
                    .padding(.top, 8)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .onHover { hovering in
            withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.84)) { railHovered = hovering }
        }
        .frame(width: railIsExpanded ? 174 : railWidth)
        .zIndex(2)
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.84), value: railIsExpanded)
    }

    private func railItem(_ section: AppSection) -> some View {
        let active = selection == section
        return Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.78)) { selection = section }
        } label: {
            HStack(spacing: 11) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: section.symbol)
                        .font(.system(size: 15, weight: active ? .semibold : .regular))
                        .frame(width: 40, height: 36)
                    if section == .timers && engine.isRunning {
                        Circle().fill(Color.accentColor).frame(width: 6, height: 6).offset(x: -4, y: 4)
                    }
                }
                if railIsExpanded {
                    Text(section.rawValue)
                        .font(.system(size: 11, weight: active ? .semibold : .medium))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }
            .foregroundStyle(active ? Color.accentColor : Color.emberMuted)
            .background {
                if active {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.accentColor.opacity(isDark ? 0.12 : 0.10))
                        .padding(.horizontal, 5)
                }
            }
            .overlay(alignment: .leading) {
                if active {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color.accentColor)
                        .frame(width: 3, height: 20)
                        .matchedGeometryEffect(id: "rail-active-indicator", in: railIndicatorNamespace)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: railIsExpanded ? 154 : 52, height: 36)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(RailNavigationButtonStyle())
        .frame(maxWidth: .infinity)
        .help(railIsExpanded ? "" : section.rawValue)
        .accessibilityLabel(section.rawValue)
        .accessibilityAddTraits(active ? .isSelected : [])
        .padding(.vertical, 2)
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
