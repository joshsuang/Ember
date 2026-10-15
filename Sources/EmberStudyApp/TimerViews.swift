import SwiftUI

struct TimerCard: View {
    @ObservedObject var engine: TimerEngine
    @ObservedObject var store: StudyStore
    var compact = false
    @State private var showCustomDuration = false
    @State private var customMinutes = "40"
    var body: some View {
        EmberCard(padding: compact ? 15 : 18) {
            VStack(spacing: compact ? 12 : 15) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Focus timer").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.emberText)
                        Text(engine.stateLabel.capitalized).font(.system(size: 9, weight: .semibold)).tracking(0.7).foregroundStyle(engine.isRunning ? Color.accentColor : Color.emberMuted)
                    }
                    Spacer()
                    Menu {
                        ForEach(TimerMode.allCases) { mode in
                            Button { engine.select(mode) } label: { Label(mode.rawValue, systemImage: mode.symbol) }
                        }
                    } label: {
                        HStack(spacing: 5) { Image(systemName: engine.mode.symbol); Text(engine.mode.rawValue); Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold)) }
                            .font(.system(size: 10, weight: .medium)).foregroundStyle(Color.emberSecondary).padding(.horizontal, 9).padding(.vertical, 6).background(Color.emberSoftFill, in: Capsule())
                    }.menuStyle(.borderlessButton)
                }
                HStack(alignment: .center, spacing: 18) {
                    TimerDial(progress: engine.progress, running: engine.isRunning, size: compact ? 88 : 105) {
                        Text(durationText(engine.displayValue, showHours: engine.mode == .stopwatch || engine.displayValue >= 3600))
                            .font(.system(size: compact ? 19 : 23, weight: .medium, design: .rounded).monospacedDigit()).tracking(-1).foregroundStyle(Color.emberText).minimumScaleFactor(0.7).lineLimit(1)
                    }
                    VStack(alignment: .leading, spacing: 11) {
                        Text(engine.mode == .pomodoro ? engine.selectedKind.rawValue : modeDescription(engine.mode))
                            .font(.system(size: 11, weight: .medium)).foregroundStyle(Color.emberSecondary)
                        HStack(spacing: 8) {
                            Button { engine.toggle() } label: {
                                Label(engine.isRunning ? "Pause" : (engine.displayValue == 0 && engine.mode != .stopwatch ? "Start again" : "Start"), systemImage: engine.isRunning ? "pause.fill" : "play.fill")
                            }.buttonStyle(EmberButtonStyle(prominent: true, compact: true))
                            Button { engine.reset() } label: { Image(systemName: "arrow.counterclockwise").font(.system(size: 11, weight: .semibold)).frame(width: 29, height: 27) }
                                .buttonStyle(EmberButtonStyle(compact: true)).help("Reset timer")
                        }
                        if engine.isRunning { Text("Time is saved automatically").font(.system(size: 9)).foregroundStyle(Color.emberMuted) }
                    }
                    Spacer(minLength: 0)
                }
                if engine.mode == .pomodoro {
                    HStack(spacing: 5) {
                        ForEach(SessionKind.allCases, id: \.self) { kind in
                            Button { engine.setPomodoroPhase(kind) } label: {
                                Text(kind == .focus ? "Focus" : kind == .shortBreak ? "Short break" : "Long break")
                                    .font(.system(size: 9, weight: engine.selectedKind == kind ? .semibold : .medium))
                                    .foregroundStyle(engine.selectedKind == kind ? Color.accentColor : Color.emberMuted)
                                    .padding(.horizontal, 8).padding(.vertical, 5)
                                    .background(engine.selectedKind == kind ? Color.accentColor.opacity(0.12) : Color.clear, in: Capsule())
                            }.buttonStyle(.plain)
                        }
                        Spacer()
                        Text("\(store.data.completedFocusSessions) sessions").font(.system(size: 9, weight: .medium)).foregroundStyle(Color.emberMuted)
                    }
                }
                if engine.mode == .countdown || engine.mode == .stopwatch {
                    HStack(spacing: 6) {
                        Text("QUICK START").font(.system(size: 8, weight: .semibold)).tracking(0.7).foregroundStyle(Color.emberMuted)
                        ForEach(store.data.settings.quickDurations, id: \.self) { minutes in
                            Button("\(minutes)m") { engine.quickStart(minutes: minutes) }.buttonStyle(EmberButtonStyle(compact: true))
                        }
                        if engine.mode == .countdown {
                            Button { showCustomDuration = true } label: { Image(systemName: "slider.horizontal.3").font(.system(size: 9)) }
                                .buttonStyle(EmberButtonStyle(compact: true)).help("Set a custom countdown")
                        }
                        Spacer(minLength: 0)
                    }
                }
                if engine.mode == .until {
                    HStack(spacing: 8) {
                        Text("UNTIL").font(.system(size: 8, weight: .semibold)).tracking(0.7).foregroundStyle(Color.emberMuted)
                        DatePicker("Target time", selection: Binding(get: { engine.targetDate }, set: { engine.configureTarget($0) }), displayedComponents: .hourAndMinute)
                            .labelsHidden().datePickerStyle(.field).controlSize(.small).frame(width: 100)
                        Spacer()
                    }
                }
            }
        }
        .alert("Custom countdown", isPresented: $showCustomDuration) {
            TextField("Minutes", text: $customMinutes)
            Button("Start") {
                if let minutes = Int(customMinutes), (1...720).contains(minutes) { engine.quickStart(minutes: minutes) }
            }
            Button("Cancel", role: .cancel) { }
        } message: { Text("Choose a study block from 1 to 720 minutes.") }
    }
    private func modeDescription(_ mode: TimerMode) -> String {
        switch mode {
        case .pomodoro: engine.selectedKind.rawValue
        case .countdown: "A focused block, at your pace"
        case .stopwatch: "Count every minute of momentum"
        case .until: "Time left in your study window"
        }
    }
}

struct TimerDial<Label: View>: View {
    var progress: Double
    var running: Bool
    var size: CGFloat
    @ViewBuilder var label: Label
    var body: some View {
        ZStack {
            Circle().stroke(Color.emberSoftFill, lineWidth: 5)
            Circle().trim(from: 0, to: max(0.008, progress)).stroke(Color.accentColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90)).animation(.easeInOut(duration: 0.5), value: progress)
            label.padding(7)
        }
        .frame(width: size, height: size)
        .shadow(color: running ? Color.accentColor.opacity(0.12) : .clear, radius: 14)
    }
}

struct TimerScreen: View {
    @ObservedObject var engine: TimerEngine
    @ObservedObject var store: StudyStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 19) {
                SectionTitle(title: "Timers", subtitle: "Find a rhythm that feels right.")
                HStack(spacing: 8) {
                    ForEach(TimerMode.allCases) { mode in
                        Button { engine.select(mode) } label: {
                            HStack(spacing: 6) { Image(systemName: mode.symbol); Text(mode.rawValue) }
                                .font(.system(size: 10, weight: engine.mode == mode ? .semibold : .medium))
                                .foregroundStyle(engine.mode == mode ? Color.accentColor : Color.emberSecondary)
                                .padding(.horizontal, 11).padding(.vertical, 8)
                                .background(engine.mode == mode ? Color.accentColor.opacity(0.1) : Color.emberSurface, in: RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(engine.mode == mode ? Color.accentColor.opacity(0.22) : Color.emberStroke, lineWidth: 1))
                        }.buttonStyle(.plain)
                    }
                }
                TimerCard(engine: engine, store: store)
                SectionTitle(title: "Make it yours", subtitle: "Your timer preferences follow you across the app.")
                EmberCard {
                    VStack(spacing: 0) {
                        SettingValueRow(title: "Focus length", subtitle: "A single Pomodoro focus session", value: "\(store.data.settings.focusMinutes) min")
                        Divider().overlay(Color.emberStroke)
                        SettingValueRow(title: "Short break", subtitle: "A little room to reset", value: "\(store.data.settings.shortBreakMinutes) min")
                        Divider().overlay(Color.emberStroke)
                        SettingValueRow(title: "Long break", subtitle: "After \(store.data.settings.sessionsBeforeLongBreak) focus sessions", value: "\(store.data.settings.longBreakMinutes) min")
                    }
                }
            }
            .padding(.horizontal, 25).padding(.vertical, 23).frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
